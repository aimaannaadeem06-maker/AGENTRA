import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/review.dart';
import 'auth_service.dart';

class ReviewService {
  static Future<List<Review>> getPackageReviews(String packageId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.REVIEWS}?packageId=$packageId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> reviewsJson = data['reviews'] ?? [];
        return reviewsJson.map((json) => Review.fromJson(json)).toList();
      }
    } catch (e) {
      print('🔴 Get reviews error: $e');
    }
    return [];
  }

  static Future<bool> createReview({
    required String packageId,
    required int rating,
    required String comment,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse(ApiConfig.CREATE_REVIEW),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'packageId': packageId,
          'rating': rating,
          'comment': comment,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('🔴 Create review error: $e');
      return false;
    }
  }

  static Future<List<Review>> getMyReviews() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(ApiConfig.MY_REVIEWS),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> reviewsJson = data['reviews'] ?? [];
        return reviewsJson.map((json) => Review.fromJson(json)).toList();
      }
    } catch (e) {
      print('🔴 Get my reviews error: $e');
    }
    return [];
  }
}