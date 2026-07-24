import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class RefundService {
  static Future<List<Map<String, dynamic>>> getRefundRequests() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      // ApiConfig.BASE_URL already ends with /api, so no extra /api prefix
      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/refund/agent'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> raw = data['refundRequests'] ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('🔴 Get refund requests error: $e');
    }
    return [];
  }

  static Future<bool> approveRefund(String bookingId, {String? reason}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/refund/approve/$bookingId'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({'reason': reason ?? 'Approved by agent'}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('🔴 Approve refund error: $e');
      return false;
    }
  }

  static Future<bool> rejectRefund(String bookingId, {String? reason}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/refund/reject/$bookingId'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({'reason': reason ?? 'Rejected by agent'}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('🔴 Reject refund error: $e');
      return false;
    }
  }
}
