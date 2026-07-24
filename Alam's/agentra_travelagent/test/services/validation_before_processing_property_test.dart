import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentra_travel_agent/services/payment_service.dart';

void main() {
  group('Property Test: Validation Before Processing', () {
    // Property test configuration
    const int iterations = 100;
    final random = Random();

    /// Helper function to generate random strings of varying lengths and characters
    String generateRandomString(int length, {bool onlyDigits = false}) {
      const digits = '0123456789';
      const alphanumeric = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !@#\$%^&*()-_=+[]{}|;:,.<>?/';
      
      final chars = onlyDigits ? digits : alphanumeric;
      return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
    }

    /// Helper function to generate invalid mobile numbers
    String generateInvalidMobileNumber() {
      final invalidType = random.nextInt(6);
      
      switch (invalidType) {
        case 0:
          // Wrong length (too short)
          final length = random.nextInt(10); // 0-9 digits
          return generateRandomString(length, onlyDigits: true);
        case 1:
          // Wrong length (too long)
          final length = 12 + random.nextInt(10); // 12-21 digits
          return generateRandomString(length, onlyDigits: true);
        case 2:
          // 11 digits but doesn't start with 03
          final firstDigit = random.nextInt(10);
          final secondDigit = random.nextInt(10);
          // Ensure it doesn't accidentally create '03'
          if (firstDigit == 0 && secondDigit == 3) {
            return '04${generateRandomString(9, onlyDigits: true)}';
          }
          return '$firstDigit$secondDigit${generateRandomString(9, onlyDigits: true)}';
        case 3:
          // Contains non-numeric characters
          final position = random.nextInt(11);
          final nonNumericChars = ['a', 'Z', ' ', '-', '_', '.', '!', '@'];
          final char = nonNumericChars[random.nextInt(nonNumericChars.length)];
          final beforeChar = '03${generateRandomString(9, onlyDigits: true)}'.substring(0, position);
          final afterChar = '03${generateRandomString(9, onlyDigits: true)}'.substring(position + 1);
          return beforeChar + char + afterChar;
        case 4:
          // Empty string
          return '';
        default:
          // Starts with 03 but wrong length
          final extraDigits = random.nextInt(5) + 1;
          final shouldBeLonger = random.nextBool();
          if (shouldBeLonger) {
            return '03${generateRandomString(9 + extraDigits, onlyDigits: true)}';
          } else {
            final length = max(0, 9 - extraDigits);
            return '03${generateRandomString(length, onlyDigits: true)}';
          }
      }
    }

    /// Helper function to generate invalid CNIC last 6 digits
    String generateInvalidCNIC() {
      final invalidType = random.nextInt(4);
      
      switch (invalidType) {
        case 0:
          // Wrong length (too short)
          final length = random.nextInt(5); // 0-4 digits
          return generateRandomString(length, onlyDigits: true);
        case 1:
          // Wrong length (too long)
          final length = 7 + random.nextInt(5); // 7-11 digits
          return generateRandomString(length, onlyDigits: true);
        case 2:
          // Contains non-numeric characters
          final position = random.nextInt(6);
          final nonNumericChars = ['a', 'Z', ' ', '-', '_', '.'];
          final char = nonNumericChars[random.nextInt(nonNumericChars.length)];
          final beforeChar = generateRandomString(6, onlyDigits: true).substring(0, position);
          final afterChar = generateRandomString(6, onlyDigits: true).substring(position + 1);
          return beforeChar + char + afterChar;
        default:
          // Empty string
          return '';
      }
    }

    test('Property 7: Validation Before Processing - validates Requirements 2.6, 2.7', () {
      // **Validates: Requirements 2.6, 2.7**
      // Property: For ANY invalid payment details (mobile number or CNIC that doesn't meet validation rules),
      // the validatePaymentDetails() method must return a ValidationResult with isValid=false
      
      int testsPassed = 0;
      
      for (int i = 0; i < iterations; i++) {
        // Generate test cases with at least one invalid field
        final testType = random.nextInt(3);
        
        String mobileNumber;
        String cnicLastSix;
        
        if (testType == 0) {
          // Invalid mobile number, valid CNIC
          mobileNumber = generateInvalidMobileNumber();
          cnicLastSix = generateRandomString(6, onlyDigits: true);
        } else if (testType == 1) {
          // Valid mobile number, invalid CNIC
          mobileNumber = '03${generateRandomString(9, onlyDigits: true)}';
          cnicLastSix = generateInvalidCNIC();
        } else {
          // Both invalid
          mobileNumber = generateInvalidMobileNumber();
          cnicLastSix = generateInvalidCNIC();
        }
        
        // Test the property: validation should return isValid=false for invalid inputs
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: mobileNumber,
          cnicLastSix: cnicLastSix,
        );
        
        // Property assertion: validation must return isValid=false for invalid inputs
        expect(
          result.isValid,
          false,
          reason: 'Validation should return isValid=false for invalid payment details\n'
                  'Mobile number: "$mobileNumber" (length: ${mobileNumber.length})\n'
                  'CNIC: "$cnicLastSix" (length: ${cnicLastSix.length})\n'
                  'Errors: ${result.errors}',
        );
        
        // Additional assertion: errors map should not be empty
        expect(
          result.errors.isNotEmpty,
          true,
          reason: 'Validation errors map should not be empty for invalid inputs\n'
                  'Mobile number: "$mobileNumber"\n'
                  'CNIC: "$cnicLastSix"',
        );
        
        testsPassed++;
      }
      
      // Verify all iterations passed
      expect(testsPassed, iterations, 
        reason: 'All $iterations property test iterations should pass');
    });

    test('Property 7: Invalid mobile numbers should always fail validation', () {
      // Generate various types of invalid mobile numbers
      for (int i = 0; i < 50; i++) {
        final invalidMobile = generateInvalidMobileNumber();
        final validCNIC = generateRandomString(6, onlyDigits: true);
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: invalidMobile,
          cnicLastSix: validCNIC,
        );
        
        expect(
          result.isValid,
          false,
          reason: 'Invalid mobile number should fail validation: "$invalidMobile"',
        );
        
        expect(
          result.errors.containsKey('mobileNumber'),
          true,
          reason: 'Errors should contain mobileNumber key for invalid mobile: "$invalidMobile"',
        );
      }
    });

    test('Property 7: Invalid CNIC should always fail validation', () {
      // Generate various types of invalid CNIC
      for (int i = 0; i < 50; i++) {
        final validMobile = '03${generateRandomString(9, onlyDigits: true)}';
        final invalidCNIC = generateInvalidCNIC();
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: validMobile,
          cnicLastSix: invalidCNIC,
        );
        
        expect(
          result.isValid,
          false,
          reason: 'Invalid CNIC should fail validation: "$invalidCNIC"',
        );
        
        expect(
          result.errors.containsKey('cnicLastSix'),
          true,
          reason: 'Errors should contain cnicLastSix key for invalid CNIC: "$invalidCNIC"',
        );
      }
    });

    test('Property 7: Both invalid fields should fail validation with both errors', () {
      // Generate cases where both fields are invalid
      for (int i = 0; i < 50; i++) {
        final invalidMobile = generateInvalidMobileNumber();
        final invalidCNIC = generateInvalidCNIC();
        
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: invalidMobile,
          cnicLastSix: invalidCNIC,
        );
        
        expect(
          result.isValid,
          false,
          reason: 'Both invalid fields should fail validation\n'
                  'Mobile: "$invalidMobile", CNIC: "$invalidCNIC"',
        );
        
        expect(
          result.errors.containsKey('mobileNumber'),
          true,
          reason: 'Errors should contain mobileNumber key: "$invalidMobile"',
        );
        
        expect(
          result.errors.containsKey('cnicLastSix'),
          true,
          reason: 'Errors should contain cnicLastSix key: "$invalidCNIC"',
        );
        
        expect(
          result.errors.length,
          2,
          reason: 'Errors should contain exactly 2 entries for both invalid fields',
        );
      }
    });

    test('Property 7: Edge cases - empty strings should fail validation', () {
      // Test empty strings explicitly
      final result1 = PaymentService.validatePaymentDetails(
        mobileNumber: '',
        cnicLastSix: '123456',
      );
      
      expect(result1.isValid, false, reason: 'Empty mobile number should fail');
      expect(result1.errors.containsKey('mobileNumber'), true);
      
      final result2 = PaymentService.validatePaymentDetails(
        mobileNumber: '03001234567',
        cnicLastSix: '',
      );
      
      expect(result2.isValid, false, reason: 'Empty CNIC should fail');
      expect(result2.errors.containsKey('cnicLastSix'), true);
      
      final result3 = PaymentService.validatePaymentDetails(
        mobileNumber: '',
        cnicLastSix: '',
      );
      
      expect(result3.isValid, false, reason: 'Both empty should fail');
      expect(result3.errors.length, 2, reason: 'Should have 2 errors');
    });

    test('Property 7: Edge cases - specific invalid formats', () {
      // Test specific known invalid formats
      final invalidCases = [
        // (mobileNumber, cnicLastSix, description)
        ('3001234567', '123456', 'Mobile missing leading 0'),
        ('030012345678', '123456', 'Mobile too long'),
        ('0300123456', '123456', 'Mobile too short'),
        ('03a01234567', '123456', 'Mobile with letter'),
        ('03 01234567', '123456', 'Mobile with space'),
        ('03001234567', '12345', 'CNIC too short'),
        ('03001234567', '1234567', 'CNIC too long'),
        ('03001234567', '12345a', 'CNIC with letter'),
        ('03001234567', '123 456', 'CNIC with space'),
        ('04001234567', '123456', 'Mobile starts with 04'),
        ('00001234567', '123456', 'Mobile starts with 00'),
      ];
      
      for (final (mobile, cnic, description) in invalidCases) {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: mobile,
          cnicLastSix: cnic,
        );
        
        expect(
          result.isValid,
          false,
          reason: 'Should fail validation: $description (mobile: "$mobile", cnic: "$cnic")',
        );
      }
    });

    test('Property 7: Validation should not accept whitespace-padded inputs', () {
      // Test inputs with leading/trailing whitespace
      final testCases = [
        (' 03001234567', '123456'),
        ('03001234567 ', '123456'),
        (' 03001234567 ', '123456'),
        ('03001234567', ' 123456'),
        ('03001234567', '123456 '),
        ('03001234567', ' 123456 '),
      ];
      
      for (final (mobile, cnic) in testCases) {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: mobile,
          cnicLastSix: cnic,
        );
        
        expect(
          result.isValid,
          false,
          reason: 'Whitespace-padded inputs should fail validation\n'
                  'Mobile: "$mobile", CNIC: "$cnic"',
        );
      }
    });
  });
}
