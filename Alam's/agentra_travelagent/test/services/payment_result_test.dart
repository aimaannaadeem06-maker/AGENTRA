import 'package:flutter_test/flutter_test.dart';
import 'package:agentra_travel_agent/services/payment_service.dart';
import 'dart:math';

void main() {
  group('PaymentResult', () {
    group('Property 3: Payment Result Completeness', () {
      // **Validates: Requirements 1.5, 1.6**
      // Property: For any PaymentResult instance, completeness invariants must hold:
      // - If success == true, then bookingReference and amount must be non-null
      // - If success == false, then errorCode and errorMessage must be non-null
      
      test('success results always have bookingReference and amount', () {
        final random = Random();
        const iterations = 100;
        
        for (int i = 0; i < iterations; i++) {
          // Generate random valid success data
          final bookingRef = _generateBookingReference(random);
          final amount = _generateRandomAmount(random);
          
          // Create success result
          final result = PaymentResult.success(
            bookingReference: bookingRef,
            amount: amount,
          );
          
          // Verify completeness invariants for success
          expect(result.success, true, 
            reason: 'Success result must have success=true');
          expect(result.bookingReference, isNotNull, 
            reason: 'Success result must have non-null bookingReference');
          expect(result.bookingReference, equals(bookingRef),
            reason: 'Success result must preserve bookingReference');
          expect(result.amount, isNotNull, 
            reason: 'Success result must have non-null amount');
          expect(result.amount, equals(amount),
            reason: 'Success result must preserve amount');
          expect(result.errorCode, isNull, 
            reason: 'Success result must have null errorCode');
          expect(result.errorMessage, isNull, 
            reason: 'Success result must have null errorMessage');
        }
      });

      test('failure results always have errorCode and errorMessage', () {
        final random = Random();
        const iterations = 100;
        
        for (int i = 0; i < iterations; i++) {
          // Generate random valid failure data
          final errorCode = _generateRandomErrorCode(random);
          final errorMessage = _generateRandomErrorMessage(random);
          
          // Create failure result
          final result = PaymentResult.failure(
            errorCode: errorCode,
            errorMessage: errorMessage,
          );
          
          // Verify completeness invariants for failure
          expect(result.success, false, 
            reason: 'Failure result must have success=false');
          expect(result.errorCode, isNotNull, 
            reason: 'Failure result must have non-null errorCode');
          expect(result.errorCode, equals(errorCode),
            reason: 'Failure result must preserve errorCode');
          expect(result.errorMessage, isNotNull, 
            reason: 'Failure result must have non-null errorMessage');
          expect(result.errorMessage, equals(errorMessage),
            reason: 'Failure result must preserve errorMessage');
          expect(result.bookingReference, isNull, 
            reason: 'Failure result must have null bookingReference');
          expect(result.amount, isNull, 
            reason: 'Failure result must have null amount');
        }
      });

      test('mixed success and failure results maintain completeness', () {
        final random = Random();
        const iterations = 100;
        
        for (int i = 0; i < iterations; i++) {
          // Randomly choose success or failure
          final isSuccess = random.nextBool();
          
          if (isSuccess) {
            final bookingRef = _generateBookingReference(random);
            final amount = _generateRandomAmount(random);
            
            final result = PaymentResult.success(
              bookingReference: bookingRef,
              amount: amount,
            );
            
            // Verify success completeness
            expect(result.success, true);
            expect(result.bookingReference, isNotNull);
            expect(result.amount, isNotNull);
            expect(result.errorCode, isNull);
            expect(result.errorMessage, isNull);
          } else {
            final errorCode = _generateRandomErrorCode(random);
            final errorMessage = _generateRandomErrorMessage(random);
            
            final result = PaymentResult.failure(
              errorCode: errorCode,
              errorMessage: errorMessage,
            );
            
            // Verify failure completeness
            expect(result.success, false);
            expect(result.errorCode, isNotNull);
            expect(result.errorMessage, isNotNull);
            expect(result.bookingReference, isNull);
            expect(result.amount, isNull);
          }
        }
      });

      test('edge case: empty strings are still non-null', () {
        // Test that empty strings satisfy non-null requirement
        final successResult = PaymentResult.success(
          bookingReference: '',
          amount: 0.0,
        );
        
        expect(successResult.bookingReference, isNotNull);
        expect(successResult.amount, isNotNull);
        
        final failureResult = PaymentResult.failure(
          errorCode: '',
          errorMessage: '',
        );
        
        expect(failureResult.errorCode, isNotNull);
        expect(failureResult.errorMessage, isNotNull);
      });

      test('edge case: extreme amount values', () {
        final random = Random();
        const iterations = 50;
        
        for (int i = 0; i < iterations; i++) {
          // Test with extreme values
          final amount = _generateExtremeAmount(random);
          final bookingRef = _generateBookingReference(random);
          
          final result = PaymentResult.success(
            bookingReference: bookingRef,
            amount: amount,
          );
          
          expect(result.success, true);
          expect(result.bookingReference, isNotNull);
          expect(result.amount, isNotNull);
          expect(result.amount, equals(amount));
        }
      });

      test('edge case: very long strings', () {
        final random = Random();
        const iterations = 50;
        
        for (int i = 0; i < iterations; i++) {
          // Test with very long strings
          final longBookingRef = _generateLongString(random, 1000);
          final amount = _generateRandomAmount(random);
          
          final result = PaymentResult.success(
            bookingReference: longBookingRef,
            amount: amount,
          );
          
          expect(result.success, true);
          expect(result.bookingReference, isNotNull);
          expect(result.bookingReference, equals(longBookingRef));
          expect(result.amount, isNotNull);
        }
      });
    });

    group('Unit tests for specific examples', () {
      test('creates successful payment result with valid data', () {
        final result = PaymentResult.success(
          bookingReference: 'BK-1234567890-5678',
          amount: 1500.00,
        );

        expect(result.success, true);
        expect(result.bookingReference, 'BK-1234567890-5678');
        expect(result.amount, 1500.00);
        expect(result.errorCode, isNull);
        expect(result.errorMessage, isNull);
      });

      test('creates failed payment result with valid data', () {
        final result = PaymentResult.failure(
          errorCode: 'CARD_DECLINED',
          errorMessage: 'Your payment was declined. Please try a different payment method.',
        );

        expect(result.success, false);
        expect(result.errorCode, 'CARD_DECLINED');
        expect(result.errorMessage, 'Your payment was declined. Please try a different payment method.');
        expect(result.bookingReference, isNull);
        expect(result.amount, isNull);
      });

      test('success result with minimum amount', () {
        final result = PaymentResult.success(
          bookingReference: 'BK-MIN',
          amount: 0.01,
        );

        expect(result.success, true);
        expect(result.amount, 0.01);
      });

      test('success result with large amount', () {
        final result = PaymentResult.success(
          bookingReference: 'BK-MAX',
          amount: 999999.99,
        );

        expect(result.success, true);
        expect(result.amount, 999999.99);
      });
    });
  });
}

// Helper functions for property-based test generators

String _generateBookingReference(Random random) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomSuffix = random.nextInt(10000).toString().padLeft(4, '0');
  return 'BK-$timestamp-$randomSuffix';
}

double _generateRandomAmount(Random random) {
  // Generate amounts between 0.01 and 10000.00
  return (random.nextDouble() * 10000.0).clamp(0.01, 10000.0);
}

double _generateExtremeAmount(Random random) {
  // Generate extreme values including very small, very large, and edge cases
  final extremeValues = [
    0.0,
    0.01,
    0.001,
    double.minPositive,
    999999999.99,
    double.maxFinite,
  ];
  
  if (random.nextBool()) {
    return extremeValues[random.nextInt(extremeValues.length)];
  } else {
    return _generateRandomAmount(random);
  }
}

String _generateRandomErrorCode(Random random) {
  final errorCodes = [
    'CARD_DECLINED',
    'INSUFFICIENT_FUNDS',
    'NETWORK_ERROR',
    'EXPIRED_CARD',
    'INVALID_DETAILS',
  ];
  return errorCodes[random.nextInt(errorCodes.length)];
}

String _generateRandomErrorMessage(Random random) {
  final messages = [
    'Your payment was declined. Please try a different payment method.',
    'Insufficient funds in your account. Please check your balance.',
    'Network error occurred. Please check your connection and try again.',
    'Your payment method has expired. Please update your details.',
    'Invalid payment details. Please verify your information.',
  ];
  return messages[random.nextInt(messages.length)];
}

String _generateLongString(Random random, int length) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}
