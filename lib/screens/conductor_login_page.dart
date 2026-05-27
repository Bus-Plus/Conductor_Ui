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

  List<String> routeIds = [];
  String? selectedRouteId;
  bool isAuthenticated = false;
  bool isProcessing = false;
  bool isFetchingRouteIds = false;

  final TextEditingController userIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? _accessToken;
  String? _userId;

  @override
  void initState() {
    super.initState();
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

    if (selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a route')),
      );
      return;
    }

    if (_userId == null || _userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing bus number username from login.')),
      );
      return;
    }

    try {
      await _authService.initializeConductorBus(
        routeId: selectedRouteId!,
        accessToken: _accessToken!,
        username: _userId!,
      );

      await initializeBusStatus(
        selectedRoute: selectedRouteId!,
        transportNumber: _userId!,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorHomePage(
            busNumber: _userId!,
            routeId: selectedRouteId!,
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

      await _loadRouteIds();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful. Select route to initialize.')),
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

  Future<void> _loadRouteIds() async {
    setState(() {
      isFetchingRouteIds = true;
      routeIds = [];
      selectedRouteId = null;
    });

    try {
      final ids = await _authService.fetchAvailableRouteIds();
      if (!mounted) return;
      setState(() {
        routeIds = ids;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load route ids: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isFetchingRouteIds = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
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
                                    labelText: 'Select Route',
                                    prefixIcon: const Icon(Icons.route,
                                        color: Color(0xFF1565C0)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                  ),
                                  value: selectedRouteId,
                                  items: routeIds.map((routeId) {
                                    return DropdownMenuItem(
                                      value: routeId,
                                      child: Text(routeId),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedRouteId = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (isFetchingRouteIds)
                                  const Text(
                                    'Loading route ids...',
                                    style: TextStyle(color: Colors.grey),
                                  )
                                else if (routeIds.isEmpty)
                                  const Text(
                                    'No route ids available. Try logging in again.',
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
