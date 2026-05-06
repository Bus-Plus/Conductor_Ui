import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'issue_ticket_page.dart';

class ConductorHomePage extends StatefulWidget {
  final String busNumber;
  final String routeId;

  const ConductorHomePage({
    super.key,
    required this.busNumber,
    required this.routeId,
  });

  @override
  State<ConductorHomePage> createState() => _ConductorHomePageState();
}

class _ConductorHomePageState extends State<ConductorHomePage> {
  List<String> stops = [];
  int currentStopIndex = 0;
  bool isLoading = true;
  bool isOnline = true;

  String get currentStop => stops.isNotEmpty ? stops[currentStopIndex] : "Loading...";

  @override
  void initState() {
    super.initState();
    fetchStops();
    monitorConnection();
  }

  void monitorConnection() {
    FirebaseFirestore.instance
        .collection('bus_status')
        .doc(widget.routeId)
        .collection('busses')
        .doc(widget.busNumber)
        .snapshots()
        .listen((_) {
      setState(() {
        isOnline = true;
      });
    }, onError: (error) {
      setState(() {
        isOnline = false;
      });
    });
  }

  Future<void> fetchStops() async {
    final stopDoc = await FirebaseFirestore.instance
        .collection('bus_stops')
        .doc(widget.routeId)
        .get();

    if (stopDoc.exists) {
      List<dynamic> data = stopDoc.data()?['stops'] ?? [];
      stops = data.map((e) => e.toString()).toList();
    }

    final busStatusDoc = await FirebaseFirestore.instance
        .collection('bus_status')
        .doc(widget.routeId)
        .collection('busses')
        .doc(widget.busNumber)
        .get();

    if (busStatusDoc.exists) {
      currentStopIndex = busStatusDoc.data()?['currentStop'] ?? 0;
    }

    setState(() {
      isLoading = false;
    });
  }

  void _nextStop() async {
    if (currentStopIndex < stops.length - 1) {
      setState(() {
        currentStopIndex++;
      });

      await FirebaseFirestore.instance
          .collection('bus_status')
          .doc(widget.routeId)
          .collection('busses')
          .doc(widget.busNumber)
          .update({'currentStop': currentStopIndex});
    }
  }

  void _resetTrip() async {
    setState(() {
      currentStopIndex = 0;
    });

    await FirebaseFirestore.instance
        .collection('bus_status')
        .doc(widget.routeId)
        .collection('busses')
        .doc(widget.busNumber)
        .set({
      'currentStop': 0,
      'stops': List.filled(stops.length, 0),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🧹 Trip Reset Successfully")),
    );
  }

  Future<void> _deleteTransportDocument() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('bus_status')
          .doc(widget.routeId)
          .collection('busses')
          .doc(widget.busNumber);

      await docRef.delete();
    } catch (e) {
      print('Error deleting transport document: $e');
    }
  }

  void _issueTicket() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueTicketPage(
          busNumber: widget.busNumber,
          routeId: widget.routeId,
          stops: stops,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isLastStop = currentStopIndex >= stops.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text(
          'BusTrack+',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: isOnline ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Route / Bus info card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_bus,
                          color: Color(0xFF1565C0), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route: ${widget.routeId}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bus No: ${widget.busNumber}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Current stop card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              color: const Color(0xFF1565C0),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20, horizontal: 16),
                child: Column(
                  children: [
                    const Text(
                      'CURRENT STOP',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentStop,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Stop ${currentStopIndex + 1} of ${stops.length}',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stops.isEmpty
                            ? 0
                            : (currentStopIndex + 1) / stops.length,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Issue Ticket
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: currentStopIndex == 0 ? null : _issueTicket,
                icon: const Icon(Icons.confirmation_number_outlined,
                    size: 20),
                label: const Text('Issue Ticket',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentStopIndex == 0
                      ? Colors.grey.shade300
                      : const Color(0xFF1565C0),
                  foregroundColor: currentStopIndex == 0
                      ? Colors.grey.shade600
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: currentStopIndex == 0 ? 0 : 2,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Next Stop
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLastStop ? null : _nextStop,
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                label: const Text('Next Stop',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStop
                      ? Colors.grey.shade300
                      : const Color(0xFF388E3C),
                  foregroundColor: isLastStop
                      ? Colors.grey.shade600
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: isLastStop ? 0 : 2,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Reset Trip
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _resetTrip,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Reset Trip',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Logout
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      title: const Text('Logout Confirmation'),
                      content: const Text('Do you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Yes',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _deleteTransportDocument();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Logout',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Connection status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline
                      ? 'Connected to Firebase'
                      : 'Not connected to Firebase',
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
