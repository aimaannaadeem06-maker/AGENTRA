import 'package:flutter_test/flutter_test.dart';
import 'package:agentra_travel_agent/services/payment_service.dart';

void main() {
  group('ValidationResult', () {
    test('valid() creates a valid result with empty errors', () {
      final result = ValidationResult.valid();
      
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('invalid() creates an invalid result with provided errors', () {
      final errors = {
        'mobileNumber': 'Invalid mobile number format',
        'cnicLastSix': 'CNIC must be 6 digits',
      };
      
      final result = ValidationResult.invalid(errors);
      
      expect(result.isValid, false);
      expect(result.errors, equals(errors));
      expect(result.errors['mobileNumber'], 'Invalid mobile number format');
      expect(result.errors['cnicLastSix'], 'CNIC must be 6 digits');
    });

    test('invalid() with empty errors map', () {
      final result = ValidationResult.invalid({});
      
      expect(result.isValid, false);
      expect(result.errors, isEmpty);
    });

    test('invalid() with single error', () {
      final errors = {'mobileNumber': 'Mobile number is required'};
      final result = ValidationResult.invalid(errors);
      
      expect(result.isValid, false);
      expect(result.errors.length, 1);
      expect(result.errors['mobileNumber'], 'Mobile number is required');
    });
  });
}
