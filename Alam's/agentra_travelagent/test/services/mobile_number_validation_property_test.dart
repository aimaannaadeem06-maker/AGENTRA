import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentra_travel_agent/services/payment_service.dart';

void main() {
  group('Property Test: Mobile Number Validation Consistency', () {
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

    test('Property 1: Mobile Number Validation Consistency - validates Requirements 2.1', () {
      // **Validates: Requirements 2.1**
      // Property: For ANY string input, the mobile number validation returns consistent results:
      // valid if and only if the string is exactly 11 digits starting with "03"
      
      int testsPassed = 0;
      
      for (int i = 0; i < iterations; i++) {
        // Generate random test cases with varying characteristics
        String testString;
        bool expectedValid;
        
        // Generate different types of test strings
        final testType = random.nextInt(10);
        
        if (testType == 0) {
          // Valid case: 11 digits starting with 03
          testString = '03${generateRandomString(9, onlyDigits: true)}';
          expectedValid = true;
        } else if (testType == 1) {
          // Invalid: wrong length (too short)
          final length = random.nextInt(10); // 0-9 digits
          testString = generateRandomString(length, onlyDigits: true);
          expectedValid = false;
        } else if (testType == 2) {
          // Invalid: wrong length (too long)
          final length = 12 + random.nextInt(10); // 12-21 digits
          testString = generateRandomString(length, onlyDigits: true);
          expectedValid = false;
        } else if (testType == 3) {
          // Invalid: 11 digits but doesn't start with 03
          final firstDigit = random.nextInt(10).toString();
          final secondDigit = random.nextInt(10).toString();
          final prefix = firstDigit + secondDigit;
          testString = prefix + generateRandomString(9, onlyDigits: true);
          expectedValid = prefix == '03';
        } else if (testType == 4) {
          // Invalid: 11 characters with non-numeric characters
          testString = generateRandomString(11, onlyDigits: false);
          expectedValid = testString.length == 11 && 
                         testString.startsWith('03') && 
                         isNumeric(testString);
        } else if (testType == 5) {
          // Invalid: empty string
          testString = '';
          expectedValid = false;
        } else if (testType == 6) {
          // Invalid: starts with 03 but wrong length
          final extraDigits = random.nextInt(5) + 1; // 1-5 extra or missing digits
          final shouldBeLonger = random.nextBool();
          if (shouldBeLonger) {
            testString = '03${generateRandomString(9 + extraDigits, onlyDigits: true)}';
          } else {
            final length = max(0, 9 - extraDigits);
            testString = '03${generateRandomString(length, onlyDigits: true)}';
          }
          expectedValid = false;
        } else if (testType == 7) {
          // Invalid: 11 digits starting with 0 but not 03
          final secondDigit = random.nextInt(10);
          if (secondDigit == 3) {
            testString = '03${generateRandomString(9, onlyDigits: true)}';
            expectedValid = true;
          } else {
            testString = '0$secondDigit${generateRandomString(9, onlyDigits: true)}';
            expectedValid = false;
          }
        } else if (testType == 8) {
          // Invalid: special characters or spaces
          testString = '0300 123 456'; // 11 chars with spaces
          expectedValid = false;
        } else {
          // Random alphanumeric string
          final length = random.nextInt(20);
          testString = generateRandomString(length, onlyDigits: false);
          expectedValid = testString.length == 11 && 
                         testString.startsWith('03') && 
                         isNumeric(testString);
        }
        
        // Test the property: validation result should match expected validity
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: testString,
          cnicLastSix: '123456', // Valid CNIC to isolate mobile number validation
        );
        
        // The mobile number validation should be consistent with the expected result
        final actualValid = !result.errors.containsKey('mobileNumber');
        
        // Property assertion: validation is consistent with the specification
        expect(
          actualValid,
          expectedValid,
          reason: 'Mobile number validation inconsistent for input: "$testString"\n'
                  'Expected valid: $expectedValid, Got valid: $actualValid\n'
                  'Length: ${testString.length}, Starts with 03: ${testString.startsWith('03')}, '
                  'Is numeric: ${isNumeric(testString)}',
        );
        
        testsPassed++;
      }
      
      // Verify all iterations passed
      expect(testsPassed, iterations, 
        reason: 'All $iterations property test iterations should pass');
    });

    test('Property 1: Edge cases - empty and single character strings', () {
      // Test edge cases explicitly
      final edgeCases = [
        ('', false),
        ('0', false),
        ('03', false),
        ('030', false),
        ('0301234567', true), // exactly 11 digits starting with 03
        ('03012345678', false), // 12 digits
        ('3001234567', false), // missing leading 0
        ('03a12345678', false), // contains letter
        ('03 12345678', false), // contains space
        ('03-12345678', false), // contains dash
      ];
      
      for (final (input, expectedValid) in edgeCases) {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: input,
          cnicLastSix: '123456',
        );
        
        final actualValid = !result.errors.containsKey('mobileNumber');
        
        expect(
          actualValid,
          expectedValid,
          reason: 'Edge case failed for input: "$input"',
        );
      }
    });

    test('Property 1: All valid mobile numbers should pass validation', () {
      // Generate valid mobile numbers and verify they all pass
      for (int i = 0; i < 50; i++) {
        final validMobile = '03${generateRandomString(9, onlyDigits: true)}';
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: validMobile,
          cnicLastSix: '123456',
        );
        
        expect(
          result.errors.containsKey('mobileNumber'),
          false,
          reason: 'Valid mobile number should not have validation error: $validMobile',
        );
      }
    });

    test('Property 1: All invalid lengths should fail validation', () {
      // Test all lengths from 0 to 20 except 11
      for (int length = 0; length <= 20; length++) {
        if (length == 11) continue; // Skip valid length
        
        String testString;
        if (length >= 2) {
          testString = '03${generateRandomString(max(0, length - 2), onlyDigits: true)}';
        } else {
          testString = generateRandomString(length, onlyDigits: true);
        }
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: testString,
          cnicLastSix: '123456',
        );
        
        expect(
          result.errors.containsKey('mobileNumber'),
          true,
          reason: 'Mobile number with length $length should fail validation: "$testString"',
        );
      }
    });

    test('Property 1: All strings not starting with 03 should fail validation', () {
      // Generate 11-digit strings that don't start with 03
      final invalidPrefixes = ['00', '01', '02', '04', '05', '06', '07', '08', '09', 
                               '10', '11', '20', '30', '40', '99'];
      
      for (final prefix in invalidPrefixes) {
        final testString = prefix + generateRandomString(9, onlyDigits: true);
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: testString,
          cnicLastSix: '123456',
        );
        
        expect(
          result.errors.containsKey('mobileNumber'),
          true,
          reason: 'Mobile number with prefix "$prefix" should fail validation: "$testString"',
        );
      }
    });

    test('Property 1: All strings with non-numeric characters should fail validation', () {
      // Generate strings with various non-numeric characters
      final nonNumericChars = ['a', 'Z', ' ', '-', '_', '.', '!', '@', '#'];
      
      for (final char in nonNumericChars) {
        // Insert non-numeric character at random position in otherwise valid number
        final position = random.nextInt(11);
        final beforeChar = '03${generateRandomString(9, onlyDigits: true)}'.substring(0, position);
        final afterChar = '03${generateRandomString(9, onlyDigits: true)}'.substring(position + 1);
        final testString = beforeChar + char + afterChar;
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: testString,
          cnicLastSix: '123456',
        );
        
        expect(
          result.errors.containsKey('mobileNumber'),
          true,
          reason: 'Mobile number with non-numeric character "$char" should fail: "$testString"',
        );
      }
    });
  });
}
