import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/complaint.dart';
import 'auth_service.dart';

class ComplaintService {
  static Future<bool> submitComplaint({
    required String bookingId,
    required String subject,
    required String description,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse(ApiConfig.SUBMIT_COMPLAINT),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'bookingId': bookingId,
          'subject': subject,
          'description': description,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('🔴 Submit complaint error: $e');
      return false;
    }
  }

  static Future<List<Complaint>> getMyComplaints() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('${ApiConfig.MY_COMPLAINTS}/my'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> list = data['complaints'] ?? [];
        return list.map((j) => Complaint.fromJson(j)).toList();
      }
    } catch (e) {
      print('🔴 Get complaints error: $e');
    }
    return [];
  }
}