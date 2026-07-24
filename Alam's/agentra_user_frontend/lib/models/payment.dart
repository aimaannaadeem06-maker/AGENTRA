class Payment {
  final String id;
  final String bookingId;
  final double amount;
  final String paymentMethod;
  final String status;
  final String? transactionId;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.transactionId,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    // The backend Transaction model uses 'payoutStatus' not 'status'
    // and stores transactionId inside paymentDetails
    final paymentDetails = json['paymentDetails'] as Map<String, dynamic>? ?? {};
    final rawStatus = json['payoutStatus'] ?? json['status'] ?? 'PENDING';

    return Payment(
      id: json['_id'] ?? json['id'] ?? '',
      bookingId: (json['bookingId'] is Map)
          ? (json['bookingId']['_id'] ?? '')
          : (json['bookingId'] ?? ''),
      amount: (json['amount'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'JAZZCASH',
      status: rawStatus.toString(),
      transactionId: paymentDetails['transactionId'] ?? json['transactionId'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'bookingId': bookingId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': status,
      'transactionId': transactionId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String getMethodIcon() {
    switch (paymentMethod.toUpperCase()) {
      case 'CARD':
        return '💳';
      case 'JAZZCASH':
        return '📱';
      case 'EASYPAISA':
        return '📲';
      case 'BANK':
        return '🏦';
      default:
        return '💰';
    }
  }
}