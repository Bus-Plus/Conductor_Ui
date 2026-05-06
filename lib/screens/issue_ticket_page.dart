import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../validate.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:usb_serial/usb_serial.dart';




class IssueTicketPage extends StatefulWidget {
  final String busNumber;
  final String routeId;
  final List<String> stops; // Full list of stops on the route

  const IssueTicketPage({
    super.key,
    required this.busNumber,
    required this.routeId,
    required this.stops,
  });

  @override
  State<IssueTicketPage> createState() => _IssueTicketPageState();
}

class _IssueTicketPageState extends State<IssueTicketPage> {
  String? destination;
  String? selectedPaymentMethod;
  String? selectedPassType;
  List<String> passTypes = [];
  String? username;
  Map<String, dynamic>? passData;
  int currentStopIndex = 0; // Track this locally to display current stop

  @override
  void initState() {
    super.initState();
    fetchPassTypes();
    fetchCurrentStop();
  }

Future<void> scanViaNFC() async {
  try {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      showMessage("⚠️ No Arduino detected!");
      return;
    }

    UsbDevice device = devices.firstWhere(
      (d) => d.productName?.contains("Arduino") ?? false,
      orElse: () => devices[0],
    );

    UsbPort? port = await device.create();
    if (port == null) {
      showMessage("❌ Cannot create USB port");
      return;
    }

    bool opened = await port.open();
    if (!opened) {
      showMessage("❌ USB Permission denied or cannot open port");
      port.close();
      return;
    }

    await port.setDTR(true);
    await port.setRTS(true);
    await port.setPortParameters(
      9600,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    showMessage("📡 Tap the card near scanner...");

    await port.write(Uint8List.fromList("READ\n".codeUnits));

    String buffer = '';
    bool dataReceived = false;

    StreamSubscription? sub = port.inputStream?.listen((Uint8List data) {
      String chunk = String.fromCharCodes(data).trim();
      if (chunk.isNotEmpty) {
        debugPrint("Arduino chunk -> $chunk");
        buffer += chunk;
        dataReceived = true;
      }
    });

    // Wait up to 5 seconds to collect all chunks
    await Future.delayed(const Duration(seconds: 5));


    sub?.cancel();
    await port.close();

    if (!dataReceived || buffer.isEmpty) {
      showMessage("⏱️ Timeout: No card data received");
      return;
    }

    buffer = buffer.trim();

    if (buffer == "NO_CARD" || buffer == "NOCARD") {
      showMessage("⚠️ No card detected");
    } else if (buffer == "READ_FAIL" || buffer == "READFAIL") {
      showMessage("❌ Failed to read card");
    } else {
      setState(() => username = buffer);
      showMessage("✅ Card scanned: $buffer");
      await validatePass();
    }

  } catch (e) {
    showMessage("❌ Error reading card: $e");
  }
}


  Future<void> fetchPassTypes() async {
    final doc = await FirebaseFirestore.instance
        .collection('payment_methods')
        .doc('passes')
        .get();

    if (doc.exists) {
      List<dynamic> types = doc['type'];
      setState(() {
        passTypes = types.map((e) => e.toString()).toList();
      });
    }
  }

  Future<void> fetchCurrentStop() async {
    final statusDoc = await FirebaseFirestore.instance
        .collection('bus_status')
        .doc(widget.routeId)
        .collection('busses')
        .doc(widget.busNumber)
        .get();

    if (statusDoc.exists) {
      setState(() {
        currentStopIndex = statusDoc['currentStop'] ?? 0;
      });
    }
  }

  Future<bool> isUserIdExistsInPassType(String userId, String passType) async {
    print(userId);
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('passes')
          .doc(passType)
          .collection(passType)
          .doc(userId)
          .get();

      if (!docSnapshot.exists) return false;

      passData = docSnapshot.data();
      return true;
    } catch (e) {
      showMessage('Error validating pass: $e');
      return false;
    }
  }

  Future<void> validatePass() async {
    if (selectedPassType == null) {
      showMessage('Please select a pass type.');
      return;
    }
    if (username == null || username!.isEmpty) {
      showMessage('Please scan or enter a valid User ID.');
      return;
    }

    bool exists = await isUserIdExistsInPassType(username!, selectedPassType!);

    if (!exists) {
      showMessage('Invalid pass or User ID does not exist.');
      setState(() {
        passData = null;
        username = null;
      });
      return;
    }

    final validTillStr = passData!['validTill'] ?? '';
    DateTime validTill;
    try {
      validTill = DateFormat('dd-MM-yyyy').parse(validTillStr);
    } catch (_) {
      showMessage('Invalid pass expiry date format.');
      return;
    }

    if (validTill.isBefore(DateTime.now())) {
      showMessage('Pass has expired.');
      setState(() {
        passData = null;
        username = null;
      });
      return;
    }

    // Check toStop validity
    if (passData!.containsKey('toStop') &&
        passData!['toStop'] != null &&
        passData!['toStop'].toString().isNotEmpty) {
      final toStop = passData!['toStop'].toString();
      List<String> destinationStops = widget.stops.sublist(currentStopIndex + 1);

      if (!destinationStops.contains(toStop)) {
        showMessage('Invalid pass: Destination stop not valid for this route.');
        setState(() {
          passData = null;
          username = null;
        });
        return;
      }

      destination = toStop;
      // Directly issue ticket
      await issueTicket();
    } else {
      // No toStop, show destination selector
      setState(() {});
    }
  }

  Future<void> openValidatePageAndScan() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ValidatePage()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        username = scannedCode;
      });
      await validatePass();
    }
  }

  Future<void> issueTicket() async {
    if (selectedPaymentMethod == null) {
      showMessage('Please select payment method.');
      return;
    }

    if (selectedPaymentMethod == 'passes') {
      if (passData == null) {
        showMessage('Validate the pass first.');
        return;
      }
      if (destination == null || destination!.isEmpty) {
        showMessage('Please select destination.');
        return;
      }
    } else {
      if (destination == null) {
        showMessage('Please select destination.');
        return;
      }
    }

    final statusDocRef = FirebaseFirestore.instance
        .collection('bus_status')
        .doc(widget.routeId)
        .collection('busses')
        .doc(widget.busNumber);

    final statusDoc = await statusDocRef.get();

    if (!statusDoc.exists) {
      showMessage('Bus status not initialized.');
      return;
    }

    List<dynamic> stopCounts = List<dynamic>.from(statusDoc['stops']);
    int currentFireStopIndex = statusDoc['currentStop'];
    int destinationIndex = widget.stops.indexOf(destination!);

    if (destinationIndex == -1) {
      showMessage('Selected destination is invalid.');
      return;
    }
    if (destinationIndex <= currentFireStopIndex) {
      showMessage('Destination must be after current stop.');
      return;
    }

    for (int i = currentFireStopIndex ; i <= destinationIndex; i++) {
      stopCounts[i] = (stopCounts[i] as int) + 1;
    }

    await statusDocRef.update({'stops': stopCounts});

    showMessage('✅ Ticket Issued');

    setState(() {
      username = null;
      passData = null;
      destination = null;
      selectedPassType = null;
      selectedPaymentMethod = null;
    });

    // Navigate back to the home page AFTER successful ticket issue
    if (mounted) {
      Navigator.pop(context); // or navigate explicitly to Home
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinationStops = currentStopIndex + 1 < widget.stops.length
        ? widget.stops.sublist(currentStopIndex + 1)
        : <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text(
          'Issue Ticket',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Payment method card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payment,
                            color: Color(0xFF1565C0), size: 18),
                        SizedBox(width: 8),
                        Text('Payment',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1565C0))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Select Payment Method',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                      ),
                      items: [
                        'cash',
                        'credit/debit card',
                        'smartcard',
                        'passes',
                        'GPay'
                      ]
                          .map((method) => DropdownMenuItem(
                                value: method,
                                child: Text(method.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedPaymentMethod = val;
                          selectedPassType = null;
                          passData = null;
                          username = null;
                          destination = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (selectedPaymentMethod == 'passes') ...[
              // Pass validation card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.card_membership,
                              color: Color(0xFF1565C0), size: 18),
                          SizedBox(width: 8),
                          Text('Pass Validation',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1565C0))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedPassType,
                        decoration: InputDecoration(
                          labelText: 'Select Pass Type',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                        items: passTypes
                            .map((type) => DropdownMenuItem(
                                value: type, child: Text(type)))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedPassType = val;
                            passData = null;
                            username = null;
                            destination = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: selectedPassType != null
                                  ? openValidatePageAndScan
                                  : null,
                              icon: const Icon(Icons.qr_code_scanner,
                                  size: 18),
                              label: const Text('Scan QR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedPassType != null
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey.shade300,
                                foregroundColor: selectedPassType != null
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: selectedPassType != null
                                  ? scanViaNFC
                                  : null,
                              icon: const Icon(Icons.nfc, size: 18),
                              label: const Text('Tap Card'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedPassType != null
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey.shade300,
                                foregroundColor: selectedPassType != null
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (username != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'User ID: $username',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (passData != null &&
                          !(passData!.containsKey('toStop') &&
                              passData!['toStop'] != null &&
                              passData!['toStop']
                                  .toString()
                                  .isNotEmpty)) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: destination,
                          decoration: InputDecoration(
                            labelText: 'Select Destination',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                          items: destinationStops
                              .map((stop) => DropdownMenuItem(
                                  value: stop, child: Text(stop)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => destination = val),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (selectedPaymentMethod != null) ...[
              // Destination card for non-pass payments
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Color(0xFF1565C0), size: 18),
                          SizedBox(width: 8),
                          Text('Destination',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1565C0))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: destination,
                        decoration: InputDecoration(
                          labelText: 'Select Destination',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                        items: destinationStops
                            .map((stop) => DropdownMenuItem(
                                value: stop, child: Text(stop)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => destination = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: issueTicket,
                icon: const Icon(Icons.confirmation_number_outlined,
                    size: 22),
                label: const Text(
                  'Issue Ticket',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
