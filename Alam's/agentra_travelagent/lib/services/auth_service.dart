import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/agent.dart';

class AuthService {
  static String? _token;
  static Agent? _currentAgent;

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 [LOGIN] Attempting login for: $email');
      print('🔗 [LOGIN] URL: ${ApiConfig.AGENT_LOGIN}');

      final requestBody = {
        'email': email,
        'password': password,
      };
      print('📤 [LOGIN] Request body: $requestBody');

      final response = await http.post(
        Uri.parse(ApiConfig.AGENT_LOGIN),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('📥 [LOGIN] Response status: ${response.statusCode}');
      print('📥 [LOGIN] Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _token = data['token'];
        _currentAgent = Agent.fromJson(data['agent']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('agent', jsonEncode(data['agent']));

        print('✅ [LOGIN] Login successful for: $email');
        return {'success': true, 'agent': _currentAgent};
      } else if (response.statusCode == 403) {
        // Handle pending approval or rejection
        print('⏳ [LOGIN] Login blocked: ${data['message']}');
        return {'success': false, 'message': data['message'] ?? 'Account not approved'};
      } else {
        print('❌ [LOGIN] Login failed: ${data['message']}');
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      print('❌ [LOGIN] Exception: $e');
      return {'success': false, 'message': 'Network error. Please check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String businessName,
    required String email,
    required String phone,
    required String cnic,
    required String password,
    String? licenseNumber,
  }) async {
    try {
      print('📝 [SIGNUP] Attempting registration for: $email');
      print('🔗 [SIGNUP] URL: ${ApiConfig.AGENT_REGISTER}');

      final requestBody = {
        'fullName': fullName,
        'businessName': businessName,
        'email': email,
        'phone': phone,
        'cnic': cnic,
        'password': password,
        'licenseNumber': licenseNumber,
      };
      print('📤 [SIGNUP] Request body: $requestBody');

      final response = await http.post(
        Uri.parse(ApiConfig.AGENT_REGISTER),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('📥 [SIGNUP] Response status: ${response.statusCode}');
      print('📥 [SIGNUP] Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Agent created successfully, but status is PENDING_APPROVAL
        // Don't save token or auto-login
        print('✅ [SIGNUP] Agent created with status: ${data['status']}');

        return {
          'success': true,
          'message': data['message'] ?? 'Account created successfully',
          'status': data['status'] ?? 'PENDING_APPROVAL',
          'agent': data['agent']
        };
      } else {
        print('❌ [SIGNUP] Registration failed: ${data['message']}');
        return {'success': false, 'message': data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      print('❌ [SIGNUP] Exception: $e');
      return {'success': false, 'message': 'Network error. Please check your connection.'};
    }
  }

  static Future<void> logout() async {
    _token = null;
    _currentAgent = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<Agent?> getCurrentAgent() async {
    if (_currentAgent != null) return _currentAgent;
    
    final prefs = await SharedPreferences.getInstance();
    final agentStr = prefs.getString('agent');
    if (agentStr != null) {
      _currentAgent = Agent.fromJson(jsonDecode(agentStr));
      _token = prefs.getString('token');
      return _currentAgent;
    }
    return null;
  }
static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data) async {
  try {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    final response = await http.put(
      Uri.parse(ApiConfig.UPDATE_AGENT_PROFILE),
      headers: {
        'Content-Type': 'application/json',
        'x-auth-token': token,
      },
      body: jsonEncode(data),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Update local cache
      _currentAgent = Agent.fromJson(responseData['agent']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('agent', jsonEncode(responseData['agent']));
      return {'success': true};
    }
    return {
      'success': false,
      'message': responseData['message'] ?? 'Update failed'
    };
  } catch (e) {
    return {'success': false, 'message': 'Error: $e'};
  }
}
  static Future<String?> getToken() async {
    if (_token != null) return _token;
    
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }

  /// Force-fetches the agent profile from the server and updates the local
  /// cache. Call this after any profile update so the side nav photo refreshes.
  static Future<Agent?> refreshCurrentAgent() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse(ApiConfig.AGENT_PROFILE),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final agentJson = data['agent'];
        if (agentJson != null) {
          _currentAgent = Agent.fromJson(agentJson);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('agent', jsonEncode(agentJson));
          return _currentAgent;
        }
      }
    } catch (_) {}
    return _currentAgent;
  }

  static String? get token => _token;
}
