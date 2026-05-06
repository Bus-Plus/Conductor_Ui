import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'conductor_home_page.dart';
import 'package:flutter/services.dart';


class ConductorLoginPage extends StatefulWidget {
  const ConductorLoginPage({super.key});

  @override
  State<ConductorLoginPage> createState() => _ConductorLoginPageState();
}

class _ConductorLoginPageState extends State<ConductorLoginPage> {
  List<String> busRoutes = [];
  String? selectedRoute;
  bool isLoading = true;
  final TextEditingController transportNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchBusRoutes();
  }

  Future<void> fetchBusRoutes() async {
  try {
    // Get all documents in the 'bus_status' collection
    final snapshot = await FirebaseFirestore.instance.collection('bus_status').get();

    setState(() {
      // Extract all document IDs as route IDs
      busRoutes = snapshot.docs.map((doc) => doc.id).toList();
      isLoading = false;
    });
  } catch (e) {
    print('Error fetching routes: $e');
    setState(() {
      isLoading = false;
    });
  }
}


Future<void> initializeBusStatus({
  required String selectedRoute,
  required String transportNumber,
}) async {
  final routeDocRef = FirebaseFirestore.instance.collection('bus_status').doc(selectedRoute);

  // Check if route document exists, if not create it (empty or with default fields as needed)
  final routeDocSnapshot = await routeDocRef.get();
  if (!routeDocSnapshot.exists) {
    await routeDocRef.set({
      'createdAt': FieldValue.serverTimestamp(), // optional metadata
    });
  }

  // Fetch stops count for the route
  final stopsDoc = await FirebaseFirestore.instance
      .collection('bus_stops')
      .doc(selectedRoute)
      .get();
  final List stops = stopsDoc.data()?['stops'] ?? [];
  int stopCount = stops.length;

  // Create bus status document under busses subcollection
  final transportDocRef = routeDocRef
      .collection('busses')
      .doc(transportNumber);

  final docSnapshot = await transportDocRef.get();
  if (!docSnapshot.exists) {
    await transportDocRef.set({
      'currentStop': 0,
      'stops': List.filled(stopCount, 0),
    });
  }
}


  void handleLogin() async {
    final transportNumber = transportNumberController.text.trim();
    if (selectedRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a bus route')),
      );
      return;
    }
    if (transportNumber.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter last 4 digits of transport number')),
      );
      return;
    }
    try {
      await initializeBusStatus(
        selectedRoute: selectedRoute!,
        transportNumber: transportNumber,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorHomePage(
            busNumber: transportNumber, // Adapt ConductorHomePage to support (route, transport number) if needed
            routeId: selectedRoute!,    // You may want to pass both
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Initialization failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Hero header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.directions_bus_rounded,
                              size: 72, color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'BusTrack+',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Conductor Portal',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    // Form card
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Select your route and enter your transport number to begin.',
                                style:
                                    TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 24),
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Select Bus Route',
                                  prefixIcon: const Icon(Icons.route,
                                      color: Color(0xFF1565C0)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                ),
                                value: selectedRoute,
                                items: busRoutes.map((route) {
                                  return DropdownMenuItem(
                                    value: route,
                                    child: Text(route),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedRoute = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: transportNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Last 4 Digits of Transport No.',
                                  prefixIcon: const Icon(Icons.dialpad,
                                      color: Color(0xFF1565C0)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                ),
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Enter transport number digits';
                                  }
                                  if (!RegExp(r'^\d{4}$').hasMatch(val)) {
                                    return 'Must be exactly 4 digits';
                                  }
                                  return null;
                                },
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: handleLogin,
                                  icon: const Icon(Icons.login),
                                  label: const Text(
                                    'Login',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    transportNumberController.dispose();
    super.dispose();
  }
}
