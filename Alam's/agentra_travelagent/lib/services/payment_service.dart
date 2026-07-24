import 'dart:async';
import 'dart:math';

/// Result of a payment processing attempt
class PaymentResult {
  final bool success;
  final String? bookingReference;
  final double? amount;
  final String? errorCode;
  final String? errorMessage;

  /// Private constructor to enforce use of named constructors
  PaymentResult._({
    required this.success,
    this.bookingReference,
    this.amount,
    this.errorCode,
    this.errorMessage,
  }) {
    // Enforce invariants
    if (success) {
      assert(bookingReference != null, 'Success result must have bookingReference');
      assert(amount != null, 'Success result must have amount');
      assert(errorCode == null, 'Success result must not have errorCode');
      assert(errorMessage == null, 'Success result must not have errorMessage');
    } else {
      assert(errorCode != null, 'Failure result must have errorCode');
      assert(errorMessage != null, 'Failure result must have errorMessage');
      assert(bookingReference == null, 'Failure result must not have bookingReference');
      assert(amount == null, 'Failure result must not have amount');
    }
  }

  /// Creates a successful payment result
  /// 
  /// Requires:
  /// - [bookingReference]: Unique booking reference (format: BK-{timestamp}-{random4digits})
  /// - [amount]: Payment amount processed
  PaymentResult.success({
    required String bookingReference,
    required double amount,
  }) : this._(
          success: true,
          bookingReference: bookingReference,
          amount: amount,
          errorCode: null,
          errorMessage: null,
        );

  /// Creates a failed payment result
  /// 
  /// Requires:
  /// - [errorCode]: Error code indicating failure reason
  /// - [errorMessage]: Human-readable error message
  PaymentResult.failure({
    required String errorCode,
    required String errorMessage,
  }) : this._(
          success: false,
          bookingReference: null,
          amount: null,
          errorCode: errorCode,
          errorMessage: errorMessage,
        );
}

/// Result of payment input validation
class ValidationResult {
  final bool isValid;
  final Map<String, String> errors;

  /// Private constructor to enforce use of factory constructors
  ValidationResult._({
    required this.isValid,
    required this.errors,
  });

  /// Creates a valid validation result with no errors
  factory ValidationResult.valid() {
    return ValidationResult._(
      isValid: true,
      errors: {},
    );
  }

  /// Creates an invalid validation result with field-specific errors
  /// 
  /// Requires:
  /// - [errors]: Map of field names to error messages
  factory ValidationResult.invalid(Map<String, String> errors) {
    return ValidationResult._(
      isValid: false,
      errors: errors,
    );
  }
}

/// Payment service for mock payment processing
class PaymentService {
  /// Validates mobile number format
  /// 
  /// Requirements:
  /// - Must be exactly 11 digits
  /// - Must start with "03"
  /// - Must contain only numeric characters
  /// 
  /// Returns error message if validation fails, null if valid
  static String? _validateMobileNumber(String mobileNumber) {
    if (mobileNumber.isEmpty) {
      return 'Mobile number is required';
    }
    
    if (mobileNumber.length != 11) {
      return 'Mobile number must be exactly 11 digits';
    }
    
    if (!mobileNumber.startsWith('03')) {
      return 'Mobile number must start with 03';
    }
    
    // Check if all characters are numeric
    if (!RegExp(r'^\d+$').hasMatch(mobileNumber)) {
      return 'Mobile number must contain only numeric characters';
    }
    
    return null;
  }

  /// Validates CNIC last 6 digits format
  /// 
  /// Requirements:
  /// - Must be exactly 6 digits
  /// - Must contain only numeric characters
  /// 
  /// Returns error message if validation fails, null if valid
  static String? _validateCNIC(String cnicLastSix) {
    if (cnicLastSix.isEmpty) {
      return 'CNIC last 6 digits are required';
    }
    
    if (cnicLastSix.length != 6) {
      return 'CNIC must be exactly 6 digits';
    }
    
    // Check if all characters are numeric
    if (!RegExp(r'^\d+$').hasMatch(cnicLastSix)) {
      return 'CNIC must contain only numeric characters';
    }
    
    return null;
  }

  /// Validates payment details
  /// 
  /// Validates both mobile number and CNIC last 6 digits.
  /// Collects all validation errors in a map.
  /// 
  /// Parameters:
  /// - [mobileNumber]: JazzCash mobile number
  /// - [cnicLastSix]: Last 6 digits of CNIC
  /// 
  /// Returns [ValidationResult] with isValid flag and errors map
  static ValidationResult validatePaymentDetails({
    required String mobileNumber,
    required String cnicLastSix,
  }) {
    final Map<String, String> errors = {};
    
    // Validate mobile number
    final mobileError = _validateMobileNumber(mobileNumber);
    if (mobileError != null) {
      errors['mobileNumber'] = mobileError;
    }
    
    // Validate CNIC
    final cnicError = _validateCNIC(cnicLastSix);
    if (cnicError != null) {
      errors['cnicLastSix'] = cnicError;
    }
    
    // Return result
    if (errors.isEmpty) {
      return ValidationResult.valid();
    } else {
      return ValidationResult.invalid(errors);
    }
  }

  /// Generates a unique booking reference
  /// 
  /// Format: BK-{timestamp}-{random4digits}
  /// Uses current timestamp in milliseconds for uniqueness
  /// Generates random 4-digit suffix using dart:math Random
  /// 
  /// Returns unique booking reference string
  static String _generateBookingReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random();
    final randomSuffix = random.nextInt(10000).toString().padLeft(4, '0');
    return 'BK-$timestamp-$randomSuffix';
  }

  /// Generates a random error code and message
  /// 
  /// Randomly selects from predefined error codes:
  /// - CARD_DECLINED
  /// - INSUFFICIENT_FUNDS
  /// - NETWORK_ERROR
  /// - EXPIRED_CARD
  /// - INVALID_DETAILS
  /// 
  /// Returns a map with 'code' and 'message' keys
  static Map<String, String> _generateErrorCode() {
    final random = Random();
    final errorCodes = [
      {
        'code': 'CARD_DECLINED',
        'message': 'Your payment was declined. Please try a different payment method.',
      },
      {
        'code': 'INSUFFICIENT_FUNDS',
        'message': 'Insufficient funds in your account. Please check your balance.',
      },
      {
        'code': 'NETWORK_ERROR',
        'message': 'Network error occurred. Please check your connection and try again.',
      },
      {
        'code': 'EXPIRED_CARD',
        'message': 'Your payment method has expired. Please update your details.',
      },
      {
        'code': 'INVALID_DETAILS',
        'message': 'Invalid payment details. Please verify your information.',
      },
    ];
    
    return errorCodes[random.nextInt(errorCodes.length)];
  }

  /// Processes a payment with the provided details
  /// 
  /// Simulates payment processing with:
  /// - Input validation
  /// - Random delay (1000-2000ms) to simulate network latency
  /// - Random outcome (80% success, 20% failure)
  /// 
  /// Parameters:
  /// - [mobileNumber]: JazzCash mobile number
  /// - [cnicLastSix]: Last 6 digits of CNIC
  /// - [amount]: Payment amount
  /// 
  /// Returns [PaymentResult] after simulating processing delay
  static Future<PaymentResult> processPayment({
    required String mobileNumber,
    required String cnicLastSix,
    required double amount,
  }) async {
    // Validate payment details first
    final validation = validatePaymentDetails(
      mobileNumber: mobileNumber,
      cnicLastSix: cnicLastSix,
    );
    
    if (!validation.isValid) {
      // Return failure result with validation error
      return PaymentResult.failure(
        errorCode: 'INVALID_DETAILS',
        errorMessage: validation.errors.values.first,
      );
    }
    
    // Generate random delay between 1000-2000ms
    final random = Random();
    final delayMs = 1000 + random.nextInt(1001); // 1000 + [0-1000] = [1000-2000]
    
    // Simulate network latency
    await Future.delayed(Duration(milliseconds: delayMs));
    
    // Generate random outcome: 80% success, 20% failure
    final isSuccess = random.nextDouble() < 0.8;
    
    if (isSuccess) {
      // Generate booking reference and return success
      final bookingReference = _generateBookingReference();
      return PaymentResult.success(
        bookingReference: bookingReference,
        amount: amount,
      );
    } else {
      // Generate error code and return failure
      final error = _generateErrorCode();
      return PaymentResult.failure(
        errorCode: error['code']!,
        errorMessage: error['message']!,
      );
    }
  }
}
