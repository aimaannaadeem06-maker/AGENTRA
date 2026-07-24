import '../config/api_config.dart';

class Agent {
  final String id;
  final String fullName;
  final String businessName;
  final String email;
  final String phone;
  final String cnic;
  final String? profileImage;
  final String? location;
  final String? refundPolicy;
  final String? cancellationPolicy;
  final String role;
  final bool isVerified;
  final String status;
  final String? rejectionReason;
  final int totalPackages;
  final int totalBookings;
  final double averageRating;

  // AI Subscription fields
  final String subscriptionPlan; // FREE | MONTHLY | YEARLY
  final bool subscriptionActive;
  final DateTime? subscriptionExpiry;

  Agent({
    required this.id,
    required this.fullName,
    required this.businessName,
    required this.email,
    required this.phone,
    required this.cnic,
    this.profileImage,
    this.location,
    this.refundPolicy,
    this.cancellationPolicy,
    this.role = 'AGENT',
    this.isVerified = false,
    this.status = 'PENDING_APPROVAL',
    this.rejectionReason,
    this.totalPackages = 0,
    this.totalBookings = 0,
    this.averageRating = 0.0,
    this.subscriptionPlan = 'FREE',
    this.subscriptionActive = false,
    this.subscriptionExpiry,
  });

  bool get isPro =>
      subscriptionActive &&
      (subscriptionPlan == 'MONTHLY' || subscriptionPlan == 'YEARLY') &&
      (subscriptionExpiry == null ||
          subscriptionExpiry!.isAfter(DateTime.now()));

  factory Agent.fromJson(Map<String, dynamic> json) {
    final aiSub = json['aiSubscription'] as Map<String, dynamic>? ?? {};
    return Agent(
      id: json['_id'] ?? '',
      fullName: json['fullName'] ?? '',
      businessName: json['businessName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      cnic: json['cnic'] ?? '',
      profileImage: ApiConfig.getImageUrl(json['profileImage']),
      location: json['location'],
      refundPolicy: json['refundPolicy'],
      cancellationPolicy: json['cancellationPolicy'],
      role: json['role'] ?? 'AGENT',
      isVerified: json['isVerified'] ?? false,
      status: json['status'] ?? 'PENDING_APPROVAL',
      rejectionReason: json['rejectionReason'],
      totalPackages: json['totalPackages'] ?? 0,
      totalBookings: (json['totalBookings'] ?? 0) < 0 ? 0 : (json['totalBookings'] ?? 0),
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      subscriptionPlan: aiSub['plan'] ?? 'FREE',
      subscriptionActive: aiSub['isActive'] ?? false,
      subscriptionExpiry: aiSub['expiryDate'] != null
          ? DateTime.tryParse(aiSub['expiryDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'businessName': businessName,
      'email': email,
      'phone': phone,
      'cnic': cnic,
      'profileImage': profileImage,
      'location': location,
      'refundPolicy': refundPolicy,
      'cancellationPolicy': cancellationPolicy,
    };
  }
}
