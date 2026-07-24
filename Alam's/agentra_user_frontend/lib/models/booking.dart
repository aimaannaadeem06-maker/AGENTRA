import '../config/api_config.dart';

class Booking {
  final String id;
  final String packageId;
  final String packageTitle;
  final String userId;
  final int seats;
  final String travelDate;
  final double totalPrice;
  final String status;
  final String paymentMethod;
  final String? paymentStatus;
  final String? refundStatus;
  final String? packageImage;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.packageId,
    required this.packageTitle,
    required this.userId,
    required this.seats,
    required this.travelDate,
    required this.totalPrice,
    required this.status,
    required this.paymentMethod,
    this.paymentStatus,
    this.refundStatus,
    this.packageImage,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['_id'] ?? json['id'] ?? '',
      packageId: json['packageId'] is Map
          ? json['packageId']['_id']
          : (json['packageId'] ?? ''),
      packageTitle: json['packageId'] is Map
          ? (json['packageId']['title'] ?? 'Package #${(json['packageId']['_id'] ?? '').toString().substring(0, 6)}')
          : (json['packageTitle'] ?? 'Unknown Package'),
      userId: json['userId'] ?? '',
      seats: json['seats'] ?? 1,
      travelDate: json['travelDate'] ?? '',
      totalPrice: (json['totalAmount'] ?? json['totalPrice'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      paymentMethod: json['paymentMethod'] ?? 'CARD',
      paymentStatus: json['paymentStatus'],
      refundStatus: json['refundStatus'],
      packageImage: (() {
        final rawImage = json['packageId'] is Map
            ? json['packageId']['image']
            : json['packageImage'];
        if (rawImage == null || rawImage.toString().isEmpty) return null;
        return ApiConfig.getImageUrl(rawImage.toString());
      })(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'packageId': packageId,
      'packageTitle': packageTitle,
      'userId': userId,
      'seats': seats,
      'travelDate': travelDate,
      'totalPrice': totalPrice,
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String getStatusText() {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }
}
