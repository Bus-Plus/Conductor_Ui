# Unit Test Documentation for issueTicket() Function

## Test File Location
`/test/issue_ticket_test.dart`

## Test Summary
- **Total Tests**: 24
- **Status**: ✅ All Passing
- **Coverage**: Validation, Firestore operations, edge cases, and complete flows

## Test Categories

### 1. Validation Logic Tests (6 tests)
Tests all validation scenarios in the `issueTicket()` function:

- ✅ **Validation 1**: Payment method is null - Should show error
- ✅ **Validation 2**: Passes payment with null passData - Should require pass validation
- ✅ **Validation 3**: Passes payment with passData but null destination - Should require destination
- ✅ **Validation 4**: Cash payment with null destination - Should require destination
- ✅ **Validation 5**: All valid inputs for cash payment - Should pass
- ✅ **Validation 6**: All valid inputs for passes payment - Should pass

### 2. Firestore Operations Tests (3 tests)
Tests Firebase Firestore integration with fake data:

- ✅ **Bus status document does not exist** - Should show error
- ✅ **Successful stop count update** - Should increment counts from current to destination
- ✅ **Helper function test** - Validates mock data setup

### 3. Destination Validation Tests (6 tests)
Tests destination selection logic:

- ✅ **Invalid destination index (-1)** - Not in stops list
- ✅ **Destination before current stop** - Cannot travel backwards
- ✅ **Destination equals current stop** - Must be after current
- ✅ **Valid destination after current stop** - Should pass
- ✅ **Destination is last stop** - Edge case validation
- ✅ **Destination is immediately next stop** - Edge case validation

### 4. Stop Count Increment Logic Tests (3 tests)
Tests the core business logic for incrementing passenger counts:

- ✅ **Increment from current to destination** - Standard journey
- ✅ **Single stop journey** - Shortest possible trip
- ✅ **Full route journey** - Longest possible trip

### 5. Complete Flow Tests (6 tests)
End-to-end tests simulating full ticket issuance:

- ✅ **Cash payment ticket issuance** - Complete flow with validation
- ✅ **Passes payment with destination** - Pass validation + ticket issue
- ✅ **Multiple ticket issuances** - Sequential ticket processing
- ✅ **Edge case: Destination is last stop**
- ✅ **Edge case: Destination is immediately next stop**
- ✅ **State reset after ticket issuance** - Cleanup verification

## Mock Data Examples

### Bus Status Mock Data
```dart
{
  'currentStop': 1,
  'stops': [10, 8, 5, 3, 0]
}
```

### Pass Data Mock
```dart
{
  'userId': 'USER123',
  'validTill': '31-12-2026',
  'toStop': 'Stop D'  // Optional
}
```

### Test Stops
```dart
['Stop A', 'Stop B', 'Stop C', 'Stop D', 'Stop E']
```

## Key Test Scenarios Covered

### 1. Payment Method Validation
- Null payment method
- Valid payment methods (cash, credit/debit card, smartcard, passes, GPay)
- Pass-specific validations

### 2. Pass Validation
- Null passData when passes selected
- Pass with predefined destination (toStop)
- Pass without predefined destination

### 3. Destination Validation
- Null destination
- Invalid destination (not in stops list)
- Destination before or at current stop
- Valid destinations (after current stop)

### 4. Firestore Operations
- Document existence check
- Read operations
- Update operations
- Multiple sequential updates

### 5. Stop Count Logic
- Correct increment range (currentStop to destination inclusive)
- Stops before current remain unchanged
- Stops after destination remain unchanged
- Edge cases (first stop, last stop, adjacent stops)

## Running the Tests

```bash
# Run all tests in the file
flutter test test/issue_ticket_test.dart

# Run with verbose output
flutter test test/issue_ticket_test.dart --verbose

# Run specific test group
flutter test test/issue_ticket_test.dart --plain-name "Validation Logic"
```

## Dependencies Used

- `flutter_test`: Flutter testing framework
- `fake_cloud_firestore: ^3.1.0`: Mock Firestore for testing
- `mockito: ^5.4.4`: Mocking framework (available for future use)
- `build_runner: ^2.4.8`: Code generation (for mockito)

## Test Assertions

Each test uses clear assertions with reason strings:
```dart
expect(isValid, true, reason: 'Should pass all validations');
expect(destinationIndex, -1, reason: 'Invalid destination should return -1');
```

## Coverage Metrics

### Function Logic Coverage
- ✅ Payment method validation
- ✅ Pass data validation
- ✅ Destination validation
- ✅ Firestore read operations
- ✅ Firestore write operations
- ✅ Stop count increment algorithm
- ✅ State reset after success
- ✅ Navigation after success (tested via flow)

### Edge Cases Covered
- ✅ Null/empty values
- ✅ Invalid destinations
- ✅ Backward travel prevention
- ✅ First stop as destination
- ✅ Last stop as destination
- ✅ Adjacent stops
- ✅ Full route traversal
- ✅ Multiple sequential tickets
- ✅ Non-existent Firestore documents

## Future Enhancements

1. **Widget Tests**: Test UI interactions (currently focuses on business logic)
2. **Integration Tests**: Test with actual Firebase emulator
3. **Error Handling**: Test network failures and exceptions
4. **Performance Tests**: Test with large stop lists
5. **Concurrent Operations**: Test simultaneous ticket issuances

## Notes

- Tests use `const` values where possible for better performance
- Mock Firestore data is isolated per test (no shared state)
- Helper function `setupMockBusStatus()` reduces code duplication
- All tests are independent and can run in any order
- Clear test naming convention: Category + Number + Description
