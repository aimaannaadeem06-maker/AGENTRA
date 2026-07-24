import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentra_travel_agent/services/payment_service.dart';

void main() {
  group('Property Test: CNIC Validation Consistency', () {
    // Property test configuration
    const int iterations = 100;
    final random = Random();

    /// Helper function to check if a string is numeric
    bool isNumeric(String s) {
      return RegExp(r'^\d+$').hasMatch(s);
    }

    /// Helper function to generate random strings of varying lengths and characters
    String generateRandomString(int length, {bool onlyDigits = false}) {
      const digits = '0123456789';
      const alphanumeric = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !@#\$%^&*()-_=+[]{}|;:,.<>?/';
      
      final chars = onlyDigits ? digits : alphanumeric;
      return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
    }

    test('Property 2: CNIC Validation Consistency - validates Requirements 2.4', () {
      // **Validates: Requirements 2.4**
      // Property: For ANY string input, the CNIC validation returns consistent results:
      // valid if and only if the string is exactly 6 numeric digits
      
      int testsPassed = 0;
      
      for (int i = 0; i < iterations; i++) {
        // Generate random test cases with varying characteristics
        String testString;
        bool expectedValid;
        
        // Generate different types of test strings
        final testType = random.nextInt(10);
        
        if (testType == 0) {
          // Valid case: exactly 6 digits
          testString = generateRandomString(6, onlyDigits: true);
          expectedValid = true;
        } else if (testType == 1) {
          // Invalid: too short (0-5 digits)
          final length = random.nextInt(6); // 0-5 digits
          testString = generateRandomString(length, onlyDigits: true);
          expectedValid = false;
        } else if (testType == 2) {
          // Invalid: too long (7+ digits)
          final length = 7 + random.nextInt(10); // 7-16 digits
          testString = generateRandomString(length, onlyDigits: true);
          expectedValid = false;
        } else if (testType == 3) {
          // Invalid: 6 characters with non-numeric characters
          testString = generateRandomString(6, onlyDigits: false);
          expectedValid = testString.length == 6 && isNumeric(testString);
        } else if (testType == 4) {
          // Invalid: empty string
          testString = '';
          expectedValid = false;
        } else if (testType == 5) {
          // Invalid: 6 characters with spaces
          testString = '123 456';
          expectedValid = false;
        } else if (testType == 6) {
          // Invalid: 6 characters with special characters
          final specialChars = ['-', '_', '.', '/', '\\', '@', '#'];
          final char = specialChars[random.nextInt(specialChars.length)];
          final position = random.nextInt(6);
          final beforeChar = generateRandomString(position, onlyDigits: true);
          final afterChar = generateRandomString(5 - position, onlyDigits: true);
          testString = beforeChar + char + afterChar;
          expectedValid = false;
        } else if (testType == 7) {
          // Invalid: 6 characters with letters
          final position = random.nextInt(6);
          final beforeChar = generateRandomString(position, onlyDigits: true);
          final afterChar = generateRandomString(5 - position, onlyDigits: true);
          final letter = String.fromCharCode(97 + random.nextInt(26)); // a-z
          testString = beforeChar + letter + afterChar;
          expectedValid = false;
        } else if (testType == 8) {
          // Random length numeric string
          final length = random.nextInt(15);
          testString = generateRandomString(length, onlyDigits: true);
          expectedValid = length == 6;
        } else {
          // Random alphanumeric string
          final length = random.nextInt(15);
          testString = generateRandomString(length, onlyDigits: false);
          expectedValid = testString.length == 6 && isNumeric(testString);
        }
        
        // Test the property: validation result should match expected validity
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567', // Valid mobile number to isolate CNIC validation
          cnicLastSix: testString,
        );
        
        // The CNIC validation should be consistent with the expected result
        final actualValid = !result.errors.containsKey('cnicLastSix');
        
        // Property assertion: validation is consistent with the specification
        expect(
          actualValid,
          expectedValid,
          reason: 'CNIC validation inconsistent for input: "$testString"\n'
                  'Expected valid: $expectedValid, Got valid: $actualValid\n'
                  'Length: ${testString.length}, Is numeric: ${isNumeric(testString)}',
        );
        
        testsPassed++;
      }
      
      // Verify all iterations passed
      expect(testsPassed, iterations, 
        reason: 'All $iterations property test iterations should pass');
    });

    test('Property 2: Edge cases - empty and single character strings', () {
      // Test edge cases explicitly
      final edgeCases = [
        ('', false),
        ('1', false),
        ('12', false),
        ('123', false),
        ('1234', false),
        ('12345', false),
        ('123456', true), // exactly 6 digits
        ('1234567', false), // 7 digits
        ('000000', true), // all zeros
        ('999999', true), // all nines
        ('12345a', false), // contains letter
        ('123 456', false), // contains space
        ('123-456', false), // contains dash
        ('12.456', false), // contains dot
      ];
      
      for (final (input, expectedValid) in edgeCases) {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: input,
        );
        
        final actualValid = !result.errors.containsKey('cnicLastSix');
        
        expect(
          actualValid,
          expectedValid,
          reason: 'Edge case failed for input: "$input"',
        );
      }
    });

    test('Property 2: All valid CNIC strings should pass validation', () {
      // Generate valid CNIC strings (6 digits) and verify they all pass
      for (int i = 0; i < 50; i++) {
        final validCnic = generateRandomString(6, onlyDigits: true);
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: validCnic,
        );
        
        expect(
          result.errors.containsKey('cnicLastSix'),
          false,
          reason: 'Valid CNIC should not have validation error: $validCnic',
        );
      }
    });

    test('Property 2: All invalid lengths should fail validation', () {
      // Test all lengths from 0 to 15 except 6
      for (int length = 0; length <= 15; length++) {
        if (length == 6) continue; // Skip valid length
        
        final testString = generateRandomString(length, onlyDigits: true);
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: testString,
        );
        
        expect(
          result.errors.containsKey('cnicLastSix'),
          true,
          reason: 'CNIC with length $length should fail validation: "$testString"',
        );
      }
    });

    test('Property 2: All strings with non-numeric characters should fail validation', () {
      // Generate strings with various non-numeric characters
      final nonNumericChars = ['a', 'Z', ' ', '-', '_', '.', '!', '@', '#', 'x', 'y'];
      
      for (final char in nonNumericChars) {
        // Insert non-numeric character at random position in otherwise valid CNIC
        final position = random.nextInt(6);
        final beforeChar = generateRandomString(position, onlyDigits: true);
        final afterChar = generateRandomString(5 - position, onlyDigits: true);
        final testString = beforeChar + char + afterChar;
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: testString,
        );
        
        expect(
          result.errors.containsKey('cnicLastSix'),
          true,
          reason: 'CNIC with non-numeric character "$char" should fail: "$testString"',
        );
      }
    });

    test('Property 2: Boundary testing - lengths around 6', () {
      // Test lengths immediately around the valid length
      final boundaryLengths = [4, 5, 6, 7, 8];
      
      for (final length in boundaryLengths) {
        final testString = generateRandomString(length, onlyDigits: true);
        final expectedValid = length == 6;
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: testString,
        );
        
        final actualValid = !result.errors.containsKey('cnicLastSix');
        
        expect(
          actualValid,
          expectedValid,
          reason: 'Boundary test failed for length $length: "$testString"',
        );
      }
    });

    test('Property 2: All numeric patterns should be valid if length is 6', () {
      // Test various numeric patterns
      final numericPatterns = [
        '000000', // all zeros
        '111111', // all ones
        '999999', // all nines
        '123456', // sequential
        '654321', // reverse sequential
        '101010', // alternating
        '000001', // leading zeros
        '100000', // trailing zeros
      ];
      
      for (final pattern in numericPatterns) {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: pattern,
        );
        
        expect(
          result.errors.containsKey('cnicLastSix'),
          false,
          reason: 'Numeric pattern should be valid: "$pattern"',
        );
      }
    });

    test('Property 2: Mixed alphanumeric strings of length 6 should fail', () {
      // Generate 6-character strings with mixed alphanumeric content
      for (int i = 0; i < 20; i++) {
        final numDigits = random.nextInt(5) + 1; // 1-5 digits
        final numLetters = 6 - numDigits; // remaining are letters
        
        // Generate digits and letters
        final digits = generateRandomString(numDigits, onlyDigits: true);
        final letters = List.generate(
          numLetters, 
          (_) => String.fromCharCode(97 + random.nextInt(26))
        ).join();
        
        // Shuffle them together
        final chars = (digits + letters).split('')..shuffle(random);
        final testString = chars.join();
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: testString,
        );
        
        expect(
          result.errors.containsKey('cnicLastSix'),
          true,
          reason: 'Mixed alphanumeric CNIC should fail: "$testString"',
        );
      }
    });
  });
}
