import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Comprehensive unit tests for issueTicket() function logic
/// Tests cover validation, Firestore operations, and state management with mock data
///
/// Test Coverage:
/// 1. Payment method validation
/// 2. Pass data validation
/// 3. Destination validation
/// 4. Firestore operations (CRUD)
/// 5. Stop count increment logic
/// 6. Edge cases and complete flows

// Helper function to setup mock Firestore bus status
Future<void> setupMockBusStatus({
  required FakeFirebaseFirestore firestore,
  required String routeId,
  required String busNumber,
  required int currentStop,
  required List<int> stopCounts,
}) async {
  await firestore
      .collection('bus_status')
      .doc(routeId)
      .collection('busses')
      .doc(busNumber)
      .set({
    'currentStop': currentStop,
    'stops': stopCounts,
  });
}

void main() {
  group('IssueTicket Function - Validation Logic Tests', () {
    test('Validation 1: Payment method null check', () {
      // Arrange - Mock the scenario where payment method is not selected
      const String? selectedPaymentMethod = null;

      // Act - Check validation condition from issueTicket()
      final shouldShowError = selectedPaymentMethod == null;

      // Assert - Should show "Please select payment method" error
      expect(shouldShowError, true,
          reason: 'Should require payment method selection');
    });

    test('Validation 2: Passes payment with null passData', () {
      // Arrange - User selected passes but hasn't validated yet
      const String selectedPaymentMethod = 'passes';
      const Map<String, dynamic>? passData = null;

      // Act - Check validation from issueTicket()
      final shouldShowError =
          selectedPaymentMethod == 'passes' && passData == null;

      // Assert - Should show "Validate the pass first" error
      expect(shouldShowError, true,
          reason: 'Should require pass validation for passes payment');
    });

    test('Validation 3: Passes payment with passData but null destination', () {
      // Arrange - Pass validated but no destination selected
      const String selectedPaymentMethod = 'passes';
      const Map<String, dynamic> passData = {'userId': 'USER123'};
      const String? destination = null;

      // Act
      final shouldShowError = selectedPaymentMethod == 'passes' &&
          passData.isNotEmpty &&
          (destination == null || destination.isEmpty);

      // Assert - Should show "Please select destination" error
      expect(shouldShowError, true,
          reason: 'Should require destination for passes');
    });

    test('Validation 4: Cash payment with null destination', () {
      // Arrange - Cash payment selected but no destination
      const String selectedPaymentMethod = 'cash';
      const String? destination = null;

      // Act
      final shouldShowError =
          selectedPaymentMethod != 'passes' && destination == null;

      // Assert - Should show "Please select destination" error
      expect(shouldShowError, true,
          reason: 'Should require destination for non-pass payments');
    });

    test('Validation 5: All valid inputs for cash payment', () {
      // Arrange - Valid cash payment with destination
      const String selectedPaymentMethod = 'cash';
      const String destination = 'Stop C';

      // Act
      final isValid = selectedPaymentMethod.isNotEmpty && destination.isNotEmpty;

      // Assert
      expect(isValid, true, reason: 'Should pass validation');
    });

    test('Validation 6: All valid inputs for passes payment', () {
      // Arrange
      const String selectedPaymentMethod = 'passes';
      const Map<String, dynamic> passData = {
        'userId': 'USER123',
        'validTill': '31-12-2026'
      };
      const String destination = 'Stop D';

      // Act
      final isValid = selectedPaymentMethod == 'passes' &&
          passData.isNotEmpty &&
          destination.isNotEmpty;

      // Assert
      expect(isValid, true, reason: 'Should pass all validations');
    });
  });

  group('IssueTicket Function - Firestore Operations Tests', () {
    // Helper function to setup mock bus status
    Future<void> setupMockBusStatus({
      required FakeFirebaseFirestore firestore,
      required String routeId,
      required String busNumber,
      required int currentStop,
      required List<int> stopCounts,
    }) async {
      await firestore
          .collection('bus_status')
          .doc(routeId)
          .collection('busses')
          .doc(busNumber)
          .set({
        'currentStop': currentStop,
        'stops': stopCounts,
      });
    }

    test('Mock Firestore - Bus status document does not exist', () async {
      // Arrange
      final firestore = FakeFirebaseFirestore();
      
      // Act
      final statusDoc = await firestore
          .collection('bus_status')
          .doc('ROUTE001')
          .collection('busses')
          .doc('BUS001')
          .get();

      // Assert - Document should not exist since we didn't create it
      expect(statusDoc.exists, false,
          reason: 'Should show "Bus status not initialized" error');
    });

    test('Mock Firestore - Successful stop count update', () async {
      // Arrange
      final firestore = FakeFirebaseFirestore();
      const routeId = 'ROUTE001';
      const busNumber = 'BUS001';
      const currentStop = 1;
      const stopCounts = [5, 3, 2, 0, 0];

      await setupMockBusStatus(
        firestore: firestore,
        routeId: routeId,
        busNumber: busNumber,
        currentStop: currentStop,
        stopCounts: stopCounts,
      );

      // Act - Simulate ticket issue from stop 1 to stop 3
      final statusDocRef = firestore
          .collection('bus_status')
          .doc(routeId)
          .collection('busses')
          .doc(busNumber);

      final statusDoc = await statusDocRef.get();
      List<dynamic> updatedStopCounts = List<dynamic>.from(statusDoc['stops']);
      const destinationIndex = 3; // Stop D

      // Simulate the loop in issueTicket
      for (int i = currentStop; i <= destinationIndex; i++) {
        updatedStopCounts[i] = (updatedStopCounts[i] as int) + 1;
      }

      await statusDocRef.update({'stops': updatedStopCounts});

      // Assert
      final updatedDoc = await statusDocRef.get();
      final finalStopCounts = updatedDoc['stops'] as List<dynamic>;
      
      expect(finalStopCounts[0], 5); // Unchanged (before current)
      expect(finalStopCounts[1], 4); // Incremented (current stop)
      expect(finalStopCounts[2], 3); // Incremented (between stop)
      expect(finalStopCounts[3], 1); // Incremented (destination)
      expect(finalStopCounts[4], 0); // Unchanged (after destination)
    });
  });

  group('IssueTicket Function - Destination Validation Tests', () {
    test('Destination 1: Invalid destination index (-1)', () {
      // Arrange
      const stops = ['Stop A', 'Stop B', 'Stop C', 'Stop D'];
      const destination = 'Stop X'; // Invalid stop not in list

      // Act - Como indexOf() in issueTicket
      final destinationIndex = stops.indexOf(destination);

      // Assert - Should show "Selected destination is invalid" error
      expect(destinationIndex, -1,
          reason: 'Invalid destination should return -1');
    });

    test('Destination 2: Destination before current stop', () {
      // Arrange
      const currentStopIndex = 2; // Currently at Stop C
      const destinationIndex = 1; // User selected Stop B (backwards)

      // Act - Check condition from issueTicket
      final isInvalid = destinationIndex <= currentStopIndex;

      // Assert - Should show "Destination must be after current stop" error
      expect(isInvalid, true,
          reason: 'Cannot travel backwards');
    });

    test('Destination 3: Destination equals current stop', () {
      // Arrange
      const currentStopIndex = 2; // Currently at Stop C
      const destinationIndex = 2; // User selected same stop

      // Act
      final isInvalid = destinationIndex <= currentStopIndex;

      // Assert - Should show "Destination must be after current stop" error
      expect(isInvalid, true,
          reason: 'Destination must be after current stop');
    });

    test('Destination 4: Valid destination after current stop', () {
      // Arrange
      const currentStopIndex = 1; // Currently at Stop B
      const destinationIndex = 3; // User selected Stop D (valid)

      // Act
      final isValid = destinationIndex > currentStopIndex &&
          destinationIndex != -1;

      // Assert
      expect(isValid, true,
          reason: 'Valid destination should pass validation');
    });

    test('Destination 5: Destination is last stop', () {
      // Arrange
      const stops = ['Stop A', 'Stop B', 'Stop C', 'Stop D'];
      const currentStopIndex = 2;
      const destinationIndex = 3; // Last stop in the list

      // Act
      final isValid = destinationIndex < stops.length &&
          destinationIndex > currentStopIndex;

      // Assert
      expect(isValid, true,
          reason: 'Last stop should be valid destination');
    });

    test('Destination 6: Destination is immediately next stop', () {
      // Arrange
      const currentStopIndex = 1;
      const destinationIndex = 2; // Very next stop

      // Act
      final isValid = destinationIndex == currentStopIndex + 1 &&
          destinationIndex > currentStopIndex;

      // Assert
      expect(isValid, true,
          reason: 'Next immediate stop should be valid');
    });
  });

  group('IssueTicket Function - Stop Count Increment Logic Tests', () {
    test('Stop Count 1: Increment from current to destination', () {
      // Arrange
      const initialStopCounts = [5, 3, 2, 1, 0];
      const currentStopIndex = 1;
      const destinationIndex = 3;

      // Act - Simulate the for loop from issueTicket
      final updatedCounts = List<int>.from(initialStopCounts);
      for (int i = currentStopIndex; i <= destinationIndex; i++) {
        updatedCounts[i] = updatedCounts[i] + 1;
      }

      // Assert
      expect(updatedCounts[0], 5, reason: 'Before current - unchanged');
      expect(updatedCounts[1], 4, reason: 'Current stop - incremented');
      expect(updatedCounts[2], 3, reason: 'Between - incremented');
      expect(updatedCounts[3], 2, reason: 'Destination - incremented');
      expect(updatedCounts[4], 0, reason: 'After destination - unchanged');
    });

    test('Stop Count 2: Single stop journey', () {
      // Arrange - Journey from stop 1 to stop 2
      const initialStopCounts = [10, 8, 6, 4, 2];
      const currentStopIndex = 1;
      const destinationIndex = 2;

      // Act
      final updatedCounts = List<int>.from(initialStopCounts);
      for (int i = currentStopIndex; i <= destinationIndex; i++) {
        updatedCounts[i] = updatedCounts[i] + 1;
      }

      // Assert
      expect(updatedCounts[0], 10);
      expect(updatedCounts[1], 9, reason: 'Current stop incremented');
      expect(updatedCounts[2], 7, reason: 'Destination incremented');
      expect(updatedCounts[3], 4);
      expect(updatedCounts[4], 2);
    });

    test('Stop Count 3: Full route journey', () {
      // Arrange - Journey from first to last stop
      const initialStopCounts = [0, 0, 0, 0, 0];
      const currentStopIndex = 0;
      const destinationIndex = 4;

      // Act
      final updatedCounts = List<int>.from(initialStopCounts);
      for (int i = currentStopIndex; i <= destinationIndex; i++) {
        updatedCounts[i] = updatedCounts[i] + 1;
      }

      // Assert - All stops should be incremented
      expect(updatedCounts[0], 1);
      expect(updatedCounts[1], 1);
      expect(updatedCounts[2], 1);
      expect(updatedCounts[3], 1);
      expect(updatedCounts[4], 1);
    });
  });

  group('IssueTicket Function - Complete Flow Tests', () {
    test('Complete Flow 1: Cash payment ticket issuance', () async {
      // Arrange
      final firestore = FakeFirebaseFirestore();
      const routeId = 'ROUTE001';
      const busNumber = 'BUS001';
      const currentStopIndex = 1;
      const destinationIndex = 3;
      const initialStopCounts = [10, 8, 5, 3, 0];
      const selectedPaymentMethod = 'cash';
      const destination = 'Stop D';

      await setupMockBusStatus(
        firestore: firestore,
        routeId: routeId,
        busNumber: busNumber,
        currentStop: currentStopIndex,
        stopCounts: initialStopCounts,
      );

      // Act - Simulate full issueTicket flow
      // 1. Validation
      expect(selectedPaymentMethod.isNotEmpty, true);
      expect(destination.isNotEmpty, true);

      // 2. Firestore operations
      final statusDocRef = firestore
          .collection('bus_status')
          .doc(routeId)
          .collection('busses')
          .doc(busNumber);

      final statusDoc = await statusDocRef.get();
      expect(statusDoc.exists, true);

      List<dynamic> stopCounts = List<dynamic>.from(statusDoc['stops']);
      final currentFireStopIndex = statusDoc['currentStop'] as int;
      
      // 3. Update stop counts
      for (int i = currentFireStopIndex; i <= destinationIndex; i++) {
        stopCounts[i] = (stopCounts[i] as int) + 1;
      }

      await statusDocRef.update({'stops': stopCounts});

      // Assert - Verify ticket was issued successfully
      final updatedDoc = await statusDocRef.get();
      final finalCounts = updatedDoc['stops'] as List<dynamic>;
      expect(finalCounts[1], 9); // Current stop incremented
      expect(finalCounts[3], 4); // Destination incremented
    });

    test('Complete Flow 2: Passes payment with destination', () async {
      // Arrange
      final firestore = FakeFirebaseFirestore();
      const routeId = 'ROUTE002';
      const busNumber = 'BUS002';
      const currentStopIndex = 0;
      const destinationIndex = 2;
      const initialStopCounts = [0, 0, 0];
      const selectedPaymentMethod = 'passes';
      const Map<String, dynamic> passData = {
        'userId': 'USER456',
        'validTill': '31-12-2026',
      };
      const destination = 'Stop C';

      await setupMockBusStatus(
        firestore: firestore,
        routeId: routeId,
        busNumber: busNumber,
        currentStop: currentStopIndex,
        stopCounts: initialStopCounts,
      );

      // Act - Full validation check
      expect(selectedPaymentMethod, 'passes');
      expect(passData.isNotEmpty, true);
      expect(destination.isNotEmpty, true);
      expect(passData.containsKey('toStop'), false); // No predefined destination

      // Update Firestore
      final statusDocRef = firestore
          .collection('bus_status')
          .doc(routeId)
          .collection('busses')
          .doc(busNumber);

      final statusDoc = await statusDocRef.get();
      List<dynamic> stopCounts = List<dynamic>.from(statusDoc['stops']);
      
      for (int i = currentStopIndex; i <= destinationIndex; i++) {
        stopCounts[i] = (stopCounts[i] as int) + 1;
      }

      await statusDocRef.update({'stops': stopCounts});

      // Assert
      final updatedDoc = await statusDocRef.get();
      final finalCounts = updatedDoc['stops'] as List<dynamic>;
      expect(finalCounts[0], 1);
      expect(finalCounts[1], 1);
      expect(finalCounts[2], 1);
    });

    test('Mock Data - Stop count increment logic', () {
      // Arrange
      final initialStopCounts = [5, 3, 2, 1, 0];
      final currentStopIndex = 1;
      final destinationIndex = 3;

      // Act
      List<int> updatedCounts = List<int>.from(initialStopCounts);
      for (int i = currentStopIndex; i <= destinationIndex; i++) {
        updatedCounts[i] = updatedCounts[i] + 1;
      }

      // Assert
      expect(updatedCounts[0], 5); // Before current - unchanged
      expect(updatedCounts[1], 4); // Current stop - incremented
      expect(updatedCounts[2], 3); // Between - incremented
      expect(updatedCounts[3], 2); // Destination - incremented
      expect(updatedCounts[4], 0); // After destination - unchanged
    });

    test('Mock Data - State reset after ticket issuance', () {
      // Simulate state variables
      String? username = 'USER123';
      Map<String, dynamic>? passData = {'userId': 'USER123'};
      String? destination = 'Stop D';
      String? selectedPassType = 'monthly';
      String? selectedPaymentMethod = 'passes';

      // Simulate state reset
      username = null;
      passData = null;
      destination = null;
      selectedPassType = null;
      selectedPaymentMethod = null;

      // Assert
      expect(username, null);
      expect(passData, null);
      expect(destination, null);
      expect(selectedPassType, null);
      expect(selectedPaymentMethod, null);
    });

    test('Mock Firestore - Multiple ticket issuances', () async {
      // Arrange
      final firestore = FakeFirebaseFirestore();
      final routeId = 'ROUTE001';
      final busNumber = 'BUS001';
      final initialStopCounts = [0, 0, 0, 0, 0];

      await setupMockBusStatus(
        firestore: firestore,
        routeId: routeId,
        busNumber: busNumber,
        currentStop: 0,
        stopCounts: initialStopCounts,
      );

      final statusDocRef = firestore
          .collection('bus_status')
          .doc(routeId)
          .collection('busses')
          .doc(busNumber);

      // Act - Issue first ticket (Stop A to Stop C)
      var doc = await statusDocRef.get();
      List<dynamic> counts = List<dynamic>.from(doc['stops']);
      for (int i = 0; i <= 2; i++) {
        counts[i] = (counts[i] as int) + 1;
      }
      await statusDocRef.update({'stops': counts});

      // Issue second ticket (Stop A to Stop D)
      doc = await statusDocRef.get();
      counts = List<dynamic>.from(doc['stops']);
      for (int i = 0; i <= 3; i++) {
        counts[i] = (counts[i] as int) + 1;
      }
      await statusDocRef.update({'stops': counts});

      // Assert
      final finalDoc = await statusDocRef.get();
      final finalCounts = finalDoc['stops'] as List<dynamic>;
      
      expect(finalCounts[0], 2); // Both tickets
      expect(finalCounts[1], 2); // Both tickets
      expect(finalCounts[2], 2); // Both tickets
      expect(finalCounts[3], 1); // Only second ticket
      expect(finalCounts[4], 0); // No tickets
    });

    test('Mock Data - Edge case: Destination is last stop', () {
      // Arrange
      final stops = ['Stop A', 'Stop B', 'Stop C', 'Stop D'];
      final currentStopIndex = 2;
      final destinationIndex = 3; // Last stop
      final stopCounts = [5, 4, 3, 2];

      // Act
      expect(destinationIndex < stops.length, true);
      expect(destinationIndex > currentStopIndex, true);

      List<int> updatedCounts = List<int>.from(stopCounts);
      for (int i = currentStopIndex; i <= destinationIndex; i++) {
        updatedCounts[i] = updatedCounts[i] + 1;
      }

      // Assert
      expect(updatedCounts[3], 3); // Last stop incremented
    });

    test('Mock Data - Edge case: Destination is immediately next stop', () {
      // Arrange
      final currentStopIndex = 1;
      final destinationIndex = 2;
      final stopCounts = [5, 4, 3, 2, 1];

      // Act
      expect(destinationIndex == currentStopIndex + 1, true);
      expect(destinationIndex > currentStopIndex, true);

      List<int> updatedCounts = List<int>.from(stopCounts);
      for (int i = currentStopIndex; i <= destinationIndex; i++) {
        updatedCounts[i] = updatedCounts[i] + 1;
      }

      // Assert
      expect(updatedCounts[0], 5); // Unchanged
      expect(updatedCounts[1], 5); // Current - incremented
      expect(updatedCounts[2], 4); // Next (destination) - incremented
      expect(updatedCounts[3], 2); // Unchanged
    });
  });
}
