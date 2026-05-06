import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  List<String> stops = [];
  List<dynamic> passengerCount = [];
  int currentStopIndex = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStatusData();
  }

  Future<void> fetchStatusData() async {
    try {
      // Fetch both documents in parallel
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('bus_stops').doc('list').get(),
        FirebaseFirestore.instance.collection('bus_status').doc('current').get(),
      ]);

      final stopDoc = results[0];
      final statusDoc = results[1];

      stops = List<String>.from(stopDoc['stops']);
      passengerCount = statusDoc['passengerCount'];
      currentStopIndex = statusDoc['currentStop'];
    } catch (e) {
      print("Error fetching data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load bus status")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text("🚌 Bus Status")),
      body: isLoading
          ? const Center(
              child: Text(
                "Loading status...\nPlease check your internet connection.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "🟢 Current Stop: ${stops[currentStopIndex]}",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "👥 Total Tickets Issued: ${passengerCount.fold(0, (a, b) => a + b as int )}",
                    style: const TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                  const Divider(height: 30),
                  const Text("🧾 Tickets per Stop:",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: stops.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(stops[index]),
                        trailing:
                            Text("${passengerCount[index]} tickets"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
