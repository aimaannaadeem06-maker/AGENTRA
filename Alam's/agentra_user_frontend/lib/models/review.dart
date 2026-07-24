import '../config/api_config.dart';

class Review {
  final String id;
  final String packageId;
  final String userId;
  final String userName;
  final String? userImage;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.packageId,
    required this.userId,
    required this.userName,
    this.userImage,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final userObj = json['userId'] is Map ? json['userId'] : null;
    final rawProfileImage = userObj?['profileImage'];
    return Review(
      id: json['_id'] ?? json['id'] ?? '',
      packageId: json['packageId'] is Map
          ? (json['packageId']['_id'] ?? '')
          : (json['packageId'] ?? ''),
      userId: userObj?['_id'] ?? json['userId'] ?? '',
      userName: userObj?['fullName'] ?? json['userName'] ?? 'Anonymous',
      userImage:
          (rawProfileImage != null && rawProfileImage.toString().isNotEmpty)
              ? ApiConfig.getImageUrl(rawProfileImage.toString())
              : null,
      rating: (json['rating'] ?? 5).toInt(),
      comment: json['comment'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'packageId': packageId,
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
