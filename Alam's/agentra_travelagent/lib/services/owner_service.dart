import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/file_saver.dart';

class OwnerService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.OWNER_LOGIN),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        if (data['token'] != null) {
          await prefs.setString('token', data['token']);
          await prefs.setBool('isOwner', true);
        }
        return {'success': true};
      }

      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('owner_token');
  }

  static Future<List<dynamic>> getAllAgents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(ApiConfig.ALL_AGENTS),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['agents'] ?? [];
      }
      return [];
    } catch (e) {
      print('Get all agents error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getOwnerDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return {};

      final response = await http.get(
        Uri.parse(ApiConfig.OWNER_DASHBOARD),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body;
      }

      final fallback = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/owner/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (fallback.statusCode == 200) {
        final body = jsonDecode(fallback.body) as Map<String, dynamic>;
        final stats = body['stats'] as Map<String, dynamic>? ?? {};
        return {
          ...body,
          'totalUsers': stats['totalUsers'] ?? 0,
          'totalAgents': stats['totalAgents'] ?? 0,
          'totalBookings': stats['totalBookings'] ?? 0,
          'totalComplaints': stats['totalComplaints'] ?? 0,
        };
      }

      return {};
    } catch (e) {
      return {};
    }
  }

  static Map<String, String> buildCommissionQueryParameters({
    String? startDate,
    String? endDate,
    String? agentId,
  }) {
    final query = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) {
      query['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      query['endDate'] = endDate;
    }
    if (agentId != null && agentId.isNotEmpty) {
      query['agentId'] = agentId;
    }
    return query;
  }

  static Future<Map<String, dynamic>> getOwnerCommissionAnalytics({
    String? startDate,
    String? endDate,
    String? agentId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return {};

      final query = buildCommissionQueryParameters(
        startDate: startDate,
        endDate: endDate,
        agentId: agentId,
      );

      final response = await http.get(
        Uri.parse(ApiConfig.OWNER_COMMISSION_ANALYTICS)
            .replace(queryParameters: query),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return body;
        }
        return {};
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  static Future<String?> exportCommissionReport({
    String? startDate,
    String? endDate,
    String? agentId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return null;

      final query = buildCommissionQueryParameters(
        startDate: startDate,
        endDate: endDate,
        agentId: agentId,
      );

      final response = await http.get(
        Uri.parse(ApiConfig.OWNER_COMMISSION_REPORT)
            .replace(queryParameters: query),
        headers: {
          'x-auth-token': token,
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      return await downloadOrSaveFile(
        response.bodyBytes,
        'commission-report.xlsx',
      );
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>> getUnverifiedAgents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(ApiConfig.PENDING_AGENTS),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['agents'] ?? [];
      }
      return [];
    } catch (e) {
      print('Fetch agents error: $e');
      return [];
    }
  }

  static Future<bool> verifyAgent(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return false;

      final response = await http.patch(
        Uri.parse(ApiConfig.approveAgent(id)),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );
      if (response.statusCode != 200) {
        print('Verify agent failed with status: ${response.statusCode}');
        print('Response: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      print('Verify agent error: $e');
      return false;
    }
  }

  static Future<bool> rejectAgent(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return false;

      final response = await http.patch(
        Uri.parse(ApiConfig.rejectAgent(id)),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({'reason': 'Rejected by Owner'}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Reject agent error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getPendingAgents() => getUnverifiedAgents();
  static Future<bool> approveAgent(String agentId) => verifyAgent(agentId);

  static Future<bool> rejectAgentApproval(String agentId,
      {String? reason}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return false;

      final response = await http.patch(
        Uri.parse(ApiConfig.rejectAgent(agentId)),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({'reason': reason ?? 'Rejected by Owner'}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Reject agent approval error: $e');
      return false;
    }
  }

  static Future<bool> blockAgent(String id) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('${ApiConfig.BASE_URL}/owner/agents/$id/block'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unblockAgent(String id) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('${ApiConfig.BASE_URL}/owner/agents/$id/unblock'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> deleteAgent(String id) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.delete(
        Uri.parse('${ApiConfig.BASE_URL}/owner/agents/$id'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> sendNotice(
    String id,
    String noticeType,
    String message,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/owner/agents/$id/notice'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'noticeType': noticeType,
          'noticeMessage': message,
        }),
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<List<dynamic>> getComplaints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(ApiConfig.COMPLAINTS),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['complaints'] ?? [];
      }
      return [];
    } catch (e) {
      print('Get complaints error: $e');
      return [];
    }
  }

  static Future<bool> resolveComplaint(String id, String responseText) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return false;

      final response = await http.put(
        Uri.parse(ApiConfig.updateComplaint(id)),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'status': 'RESOLVED',
          'OwnerResponse': responseText,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Resolve complaint error: $e');
      return false;
    }
  }
}
