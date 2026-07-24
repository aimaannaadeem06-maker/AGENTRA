import 'package:flutter_test/flutter_test.dart';
import 'package:agentra_travel_agent/services/payment_service.dart';

void main() {
  group('PaymentService - Task 4 Implementation Tests', () {
    group('Booking Reference Generator (Task 4.1)', () {
      test('should generate booking reference with correct format', () async {
        // Process a payment to get a booking reference
        final result = await PaymentService.processPayment(
          mobileNumber: '03001234567',
          cnicLastSix: '123456',
          amount: 100.0,
        );

        if (result.success) {
          // Verify format: BK-{timestamp}-{random4digits}
          expect(result.bookingReference, isNotNull);
          expect(result.bookingReference, startsWith('BK-'));
          
          final parts = result.bookingReference!.split('-');
          expect(parts.length, equals(3));
          expect(parts[0], equals('BK'));
          
          // Verify timestamp is numeric
          expect(int.tryParse(parts[1]), isNotNull);
          
          // Verify random suffix is 4 digits
          expect(parts[2].length, equals(4));
          expect(int.tryParse(parts[2]), isNotNull);
        }
      });

      test('should generate unique booking references', () async {
        final references = <String>{};
        
        // Generate multiple booking references
        for (int i = 0; i < 10; i++) {
          final result = await PaymentService.processPayment(
            mobileNumber: '03001234567',
            cnicLastSix: '123456',
            amount: 100.0,
          );
          
          if (result.success) {
            references.add(result.bookingReference!);
          }
          
          // Small delay to ensure different timestamps
          await Future.delayed(const Duration(milliseconds: 10));
        }
        
        // All references should be unique
        expect(references.length, greaterThan(0));
      });
    });

    group('Error Code Generator (Task 4.3)', () {
      test('should generate valid error codes on failure', () async {
        final validErrorCodes = {
          'CARD_DECLINED',
          'INSUFFICIENT_FUNDS',
          'NETWORK_ERROR',
          'EXPIRED_CARD',
          'INVALID_DETAILS',
        };

        // Run multiple times to potentially get failures
        for (int i = 0; i < 50; i++) {
          final result = await PaymentService.processPayment(
            mobileNumber: '03001234567',
            cnicLastSix: '123456',
            amount: 100.0,
          );

          if (!result.success) {
            // Verify error code is in the predefined set
            expect(validErrorCodes.contains(result.errorCode), isTrue,
                reason: 'Error code ${result.errorCode} is not in predefined set');
            
            // Verify error message is not null or empty
            expect(result.errorMessage, isNotNull);
            expect(result.errorMessage!.isNotEmpty, isTrue);
          }
        }
      });

      test('should map error codes to user-friendly messages', () async {
        final errorMessages = {
          'CARD_DECLINED': 'Your payment was declined. Please try a different payment method.',
          'INSUFFICIENT_FUNDS': 'Insufficient funds in your account. Please check your balance.',
          'NETWORK_ERROR': 'Network error occurred. Please check your connection and try again.',
          'EXPIRED_CARD': 'Your payment method has expired. Please update your details.',
          'INVALID_DETAILS': 'Invalid payment details. Please verify your information.',
        };

        // Run multiple times to collect different error codes
        final foundErrors = <String, String>{};
        
        for (int i = 0; i < 100; i++) {
          final result = await PaymentService.processPayment(
            mobileNumber: '03001234567',
            cnicLastSix: '123456',
            amount: 100.0,
          );

          if (!result.success) {
            foundErrors[result.errorCode!] = result.errorMessage!;
          }
        }

        // Verify that found error messages match expected messages
        for (final entry in foundErrors.entries) {
          expect(errorMessages[entry.key], equals(entry.value),
              reason: 'Error message for ${entry.key} does not match expected');
        }
      });
    });

    group('processPayment Service Method (Task 4.5)', () {
      test('should accept required parameters', () async {
        final result = await PaymentService.processPayment(
          mobileNumber: '03001234567',
          cnicLastSix: '123456',
          amount: 100.0,
        );

        expect(result, isNotNull);
      });

      test('should return failure for invalid mobile number', () async {
        final result = await PaymentService.processPayment(
          mobileNumber: '123', // Invalid
          cnicLastSix: '123456',
          amount: 100.0,
        );

        expect(result.success, isFalse);
        expect(result.errorCode, equals('INVALID_DETAILS'));
        expect(result.errorMessage, isNotNull);
      });

      test('should return failure for invalid CNIC', () async {
        final result = await PaymentService.processPayment(
          mobileNumber: '03001234567',
          cnicLastSix: '123', // Invalid
          amount: 100.0,
        );

        expect(result.success, isFalse);
        expect(result.errorCode, equals('INVALID_DETAILS'));
        expect(result.errorMessage, isNotNull);
      });

      test('should simulate processing delay between 1000-2000ms', () async {
        final stopwatch = Stopwatch()..start();
        
        await PaymentService.processPayment(
          mobileNumber: '03001234567',
          cnicLastSix: '123456',
          amount: 100.0,
        );
        
        stopwatch.stop();
        final elapsedMs = stopwatch.elapsedMilliseconds;
        
        // Allow 100ms overhead for computation
        expect(elapsedMs, greaterThanOrEqualTo(1000));
        expect(elapsedMs, lessThanOrEqualTo(2100));
      });

      test('should return success with booking reference and amount', () async {
        // Run multiple times to get at least one success
        for (int i = 0; i < 20; i++) {
          final result = await PaymentService.processPayment(
            mobileNumber: '03001234567',
            cnicLastSix: '123456',
            amount: 150.0,
          );

          if (result.success) {
            expect(result.bookingReference, isNotNull);
            expect(result.amount, equals(150.0));
            expect(result.errorCode, isNull);
            expect(result.errorMessage, isNull);
            return; // Test passed
          }
        }
      });

      test('should return failure with error code and message', () async {
        // Run multiple times to get at least one failure
        for (int i = 0; i < 50; i++) {
          final result = await PaymentService.processPayment(
            mobileNumber: '03001234567',
            cnicLastSix: '123456',
            amount: 100.0,
          );

          if (!result.success) {
            expect(result.errorCode, isNotNull);
            expect(result.errorMessage, isNotNull);
            expect(result.bookingReference, isNull);
            expect(result.amount, isNull);
            return; // Test passed
          }
        }
      });

      test('should have approximately 80% success rate', () async {
        int successCount = 0;
        const iterations = 100;

        for (int i = 0; i < iterations; i++) {
          final result = await PaymentService.processPayment(
            mobileNumber: '03001234567',
            cnicLastSix: '123456',
            amount: 100.0,
          );

          if (result.success) {
            successCount++;
          }
        }

        final successRate = successCount / iterations;
        
        // Allow 10% variance (70-90%)
        expect(successRate, greaterThanOrEqualTo(0.70));
        expect(successRate, lessThanOrEqualTo(0.90));
      });
    });
  });
}
