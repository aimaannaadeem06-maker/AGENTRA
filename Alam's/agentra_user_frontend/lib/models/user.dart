import '../config/api_config.dart';
class User {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profileImage;
  final String role;
  final int totalBookings;
  final int rewardPoints;
  final int favoritesCount;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.profileImage,
    this.role = 'user',
    this.totalBookings = 0,
    this.rewardPoints = 0,
    this.favoritesCount = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      profileImage: ApiConfig.getImageUrl(json['profileImage']),
      role: json['role'] ?? 'user',
      totalBookings: (json['totalBookings'] ?? 0) < 0 ? 0 : (json['totalBookings'] ?? 0),
      rewardPoints: json['rewardPoints'] ?? 0,
      favoritesCount: json['favoritesCount'] ?? (json['favorites'] as List?)?.length ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'role': role,
    };
  }
}
