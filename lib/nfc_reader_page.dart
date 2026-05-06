import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:usb_serial/usb_serial.dart';

class NFCReaderPage extends StatefulWidget {
  const NFCReaderPage({Key? key}) : super(key: key);

  @override
  State<NFCReaderPage> createState() => _NFCReaderPageState();
}

class _NFCReaderPageState extends State<NFCReaderPage> {
  UsbPort? port;
  StreamSubscription<Uint8List>? _usbSub;
  bool isScanningUsb = false;
  bool isScanningNfc = false;
  String message = 'Ready to scan';

// ------------------ USB OTG (Arduino) ------------------
Future<void> startCardScan() async {
  setState(() => isScanningUsb = true);

  try {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      setState(() {
        message = "No Arduino detected!";
        isScanningUsb = false;
      });
      return;
    }

    UsbDevice device = devices.firstWhere(
      (d) => d.productName?.contains("Arduino") ?? false,
      orElse: () => devices[0],
    );

    // Create port
    port = await device.create();
    if (port == null) {
      setState(() {
        message = "Cannot create USB port";
        isScanningUsb = false;
      });
      return;
    }

    // Open port (triggers permission dialog)
    bool opened = await port!.open();
    if (!opened) {
      setState(() {
        message = "USB Permission denied or cannot open port";
        isScanningUsb = false;
      });
      return;
    }

    // Configure port settings
    await port!.setDTR(true);
    await port!.setRTS(true);
    await port!.setPortParameters(
      9600,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    setState(() {
      message = "Place your card near the scanner...";
    });

    _usbSub = port!.inputStream!.listen((data) {
      final response = String.fromCharCodes(data).trim();
      debugPrint("Arduino: $response");

      if (response == "NOCARD" || response == "NO_CARD") {
        setState(() => message = "No card detected");
      } else if (response == "READFAIL" || response == "READ_FAIL") {
        setState(() => message = "Failed to read card");
      } else if (response.isNotEmpty) {
        setState(() {
          message = "Card Data: $response";
          isScanningUsb = false;
        });
        _usbSub?.cancel();
        port?.close();
      }
    });

    // Send READ command
    await port!.write(Uint8List.fromList('READ\n'.codeUnits));
  } catch (e) {
    setState(() {
      message = "USB scan failed: $e";
      isScanningUsb = false;
    });
  }
}

  Future<void> startNativeNfcScan() async {
    setState(() => isScanningNfc = true);

    try {
      NFCTag tag = await FlutterNfcKit.poll();

      if (tag.ndefAvailable == true) {
        var ndefRecords = await FlutterNfcKit.readNDEFRecords();

        if (ndefRecords.isNotEmpty) {
          var record = ndefRecords.first;
          String payloadString = '';

          if (record.payload != null && record.payload!.length > 1) {
            // Skip the first byte (encoding/type)
            payloadString = String.fromCharCodes(record.payload!.sublist(1));
          }

          setState(() {
            message = 'Tag Data: $payloadString';
          });
        } else {
          setState(() => message = 'No data found on tag');
        }
      } else {
        setState(() => message = 'NDEF not available on this tag');
      }

      await FlutterNfcKit.finish();
    } catch (e) {
      setState(() => message = 'NFC scan failed: $e');
    } finally {
      setState(() => isScanningNfc = false);
    }
  }

  @override
  void dispose() {
    _usbSub?.cancel();
    port?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC Reader')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: isScanningUsb ? null : startCardScan,
              icon: const Icon(Icons.usb),
              label: const Text('Scan via OTG (Arduino RC522)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isScanningNfc ? null : startNativeNfcScan,
              icon: const Icon(Icons.nfc),
              label: const Text('Scan via Native NFC'),
            ),
            const SizedBox(height: 20),
            Text(message, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
