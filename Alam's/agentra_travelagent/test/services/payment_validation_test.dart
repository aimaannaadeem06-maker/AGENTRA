import 'package:flutter_test/flutter_test.dart';
import 'package:agentra_travel_agent/services/payment_service.dart';

void main() {
  group('PaymentService Validation', () {
    group('validatePaymentDetails', () {
      test('returns valid result for correct mobile number and CNIC', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: '123456',
        );

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns invalid result for mobile number with wrong length', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '0300123456', // 10 digits
          cnicLastSix: '123456',
        );

        expect(result.isValid, false);
        expect(result.errors['mobileNumber'], 'Mobile number must be exactly 11 digits');
      });

      test('returns invalid result for mobile number not starting with 03', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '04001234567',
          cnicLastSix: '123456',
        );

        expect(result.isValid, false);
        expect(result.errors['mobileNumber'], 'Mobile number must start with 03');
      });

      test('returns invalid result for mobile number with non-numeric characters', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '0300123456a',
          cnicLastSix: '123456',
        );

        expect(result.isValid, false);
        expect(result.errors['mobileNumber'], 'Mobile number must contain only numeric characters');
      });

      test('returns invalid result for empty mobile number', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '',
          cnicLastSix: '123456',
        );

        expect(result.isValid, false);
        expect(result.errors['mobileNumber'], 'Mobile number is required');
      });

      test('returns invalid result for CNIC with wrong length', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: '12345', // 5 digits
        );

        expect(result.isValid, false);
        expect(result.errors['cnicLastSix'], 'CNIC must be exactly 6 digits');
      });

      test('returns invalid result for CNIC with non-numeric characters', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: '12345a',
        );

        expect(result.isValid, false);
        expect(result.errors['cnicLastSix'], 'CNIC must contain only numeric characters');
      });

      test('returns invalid result for empty CNIC', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: '',
        );

        expect(result.isValid, false);
        expect(result.errors['cnicLastSix'], 'CNIC last 6 digits are required');
      });

      test('returns multiple errors when both fields are invalid', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '123',
          cnicLastSix: '12',
        );

        expect(result.isValid, false);
        expect(result.errors.length, 2);
        expect(result.errors['mobileNumber'], isNotNull);
        expect(result.errors['cnicLastSix'], isNotNull);
      });

      test('validates mobile number with leading zeros correctly', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: '000000',
        );

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('rejects mobile number with spaces', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '0300 123 4567',
          cnicLastSix: '123456',
        );

        expect(result.isValid, false);
        expect(result.errors['mobileNumber'], isNotNull);
      });

      test('rejects CNIC with spaces', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: '123 456',
        );

        expect(result.isValid, false);
        expect(result.errors['cnicLastSix'], isNotNull);
      });

      test('rejects mobile number with special characters', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '0300-123-4567',
          cnicLastSix: '123456',
        );

        expect(result.isValid, false);
        expect(result.errors['mobileNumber'], 'Mobile number must contain only numeric characters');
      });

      test('rejects CNIC with special characters', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: '123-456',
        );

        expect(result.isValid, false);
        expect(result.errors['cnicLastSix'], 'CNIC must contain only numeric characters');
      });

      test('validates different valid mobile number prefixes starting with 03', () {
        final validPrefixes = ['0300', '0301', '0302', '0303', '0304', '0305', '0321', '0333', '0345'];
        
        for (final prefix in validPrefixes) {
          final mobileNumber = prefix + '1234567'.substring(0, 11 - prefix.length);
          final result = PaymentService.validatePaymentDetails(
            mobileNumber: mobileNumber,
            cnicLastSix: '123456',
          );

          expect(result.isValid, true, reason: 'Mobile number $mobileNumber should be valid');
          expect(result.errors, isEmpty);
        }
      });

      test('rejects mobile numbers that are too long', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '030012345678', // 12 digits
          cnicLastSix: '123456',
        );

        expect(result.isValid, false);
        expect(result.errors['mobileNumber'], 'Mobile number must be exactly 11 digits');
      });

      test('rejects CNIC that is too long', () {
        final result = PaymentService.validatePaymentDetails(
          mobileNumber: '03001234567',
          cnicLastSix: '1234567', // 7 digits
        );

        expect(result.isValid, false);
        expect(result.errors['cnicLastSix'], 'CNIC must be exactly 6 digits');
      });
    });
  });
}
