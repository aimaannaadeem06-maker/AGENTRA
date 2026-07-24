import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class BookingService {
  static Future<List<dynamic>> getAgentBookings() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(ApiConfig.AGENT_BOOKINGS),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['bookings'] ?? [];
      }
    } catch (e) {
      print('Get agent bookings error: $e');
    }
    return [];
  }

  static Future<bool> cancelBooking(String bookingId, String reason) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      // Assuming there is a cancel endpoint, if not, we might need to add it to backend
      // For now, let's check if the backend has a cancel route
      final response = await http.put(
        Uri.parse('${ApiConfig.BASE_URL}/bookings/$bookingId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({'cancellationReason': reason}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Cancel booking error: $e');
      return false;
    }
  }
}
