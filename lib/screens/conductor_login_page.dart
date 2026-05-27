import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'conductor_home_page.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';


class ConductorLoginPage extends StatefulWidget {
  const ConductorLoginPage({super.key});

  @override
  State<ConductorLoginPage> createState() => _ConductorLoginPageState();
}

class _ConductorLoginPageState extends State<ConductorLoginPage> {
  final AuthService _authService = AuthService();

  List<String> busRoutes = [];
  String? selectedRoute;
  List<String> busNumbers = [];
  String? selectedBusNumber;
  bool isAuthenticated = false;
  bool isLoading = true;
  bool isProcessing = false;
  bool isLoadingBusNumbers = false;

  final TextEditingController userIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? _accessToken;
  String? _userId;

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
    debugPrint('Error fetching routes: $e');
    if (!mounted) return;
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
    if (!isAuthenticated) {
      await _authenticate();
      return;
    }

    if (selectedRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a bus route')),
      );
      return;
    }

    if (selectedBusNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a bus number')),
      );
      return;
    }

    try {
      await _authService.initializeConductorBus(
        routeId: selectedRoute!,
        busNumber: selectedBusNumber!,
        accessToken: _accessToken!,
        username: _userId ?? userIdController.text.trim(),
      );

      await initializeBusStatus(
        selectedRoute: selectedRoute!,
        transportNumber: selectedBusNumber!,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorHomePage(
            busNumber: selectedBusNumber!,
            routeId: selectedRoute!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Initialization failed: $e')),
      );
    }
  }

  Future<void> _authenticate() async {
    final userId = userIdController.text.trim();
    final password = passwordController.text;

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password is required')),
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final loginResult = await _authService.login(
        userId: userId,
        password: password,
      );

      await _authService.validateConductor(
        accessToken: loginResult['access_token'] as String,
      );

      if (!mounted) return;
      setState(() {
        _accessToken = loginResult['access_token'] as String;
        _userId = loginResult['user_id'] as String;
        isAuthenticated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful. Select route and bus.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _loadBusNumbersForRoute(String routeId) async {
    setState(() {
      isLoadingBusNumbers = true;
      busNumbers = [];
      selectedBusNumber = null;
    });

    try {
      final numbers = await _authService.fetchAvailableBusNumbers();
      if (!mounted) return;
      setState(() {
        busNumbers = numbers;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load bus numbers: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingBusNumbers = false;
        });
      }
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
                              Text(
                                isAuthenticated
                                    ? 'Select your route and bus number to initialize your shift.'
                                    : 'Enter your 4-digit user ID and password to sign in.',
                                style:
                                    const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 24),
                              if (!isAuthenticated) ...[
                                TextFormField(
                                  controller: userIdController,
                                  decoration: InputDecoration(
                                    labelText: 'User ID (4 digits)',
                                    prefixIcon: const Icon(Icons.person,
                                        color: Color(0xFF1565C0)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: passwordController,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock,
                                        color: Color(0xFF1565C0)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                  ),
                                  obscureText: true,
                                ),
                              ] else ...[
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
                                    if (value == null) return;
                                    setState(() {
                                      selectedRoute = value;
                                      selectedBusNumber = null;
                                      busNumbers = [];
                                    });
                                    _loadBusNumbersForRoute(value);
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Select Bus Number',
                                    prefixIcon: const Icon(Icons.directions_bus,
                                        color: Color(0xFF1565C0)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                  ),
                                  value: selectedBusNumber,
                                  items: busNumbers.map((bus) {
                                    return DropdownMenuItem(
                                      value: bus,
                                      child: Text(bus),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedBusNumber = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (isLoadingBusNumbers)
                                  const Text(
                                    'Loading bus numbers for the selected route...',
                                    style: TextStyle(color: Colors.grey),
                                  )
                                else if (selectedRoute != null && busNumbers.isEmpty)
                                  const Text(
                                    'No bus numbers available for the selected route.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                              ],
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: isProcessing ? null : handleLogin,
                                  icon: Icon(isAuthenticated ? Icons.check : Icons.login),
                                  label: Text(
                                    isAuthenticated ? 'Initialize Bus' : 'Login',
                                    style: const TextStyle(
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
    userIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
