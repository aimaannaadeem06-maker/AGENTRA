import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';

class AuthService {
  static String? _token;
  static User? _currentUser;

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      print(' Registering: $email');
      
      final response = await http.post(
        Uri.parse(ApiConfig.USER_REGISTER),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
          'phone': phone,
        }),
      );

      print(' Register Status: ${response.statusCode}');
      print(' Register Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _token = data['token'];
        if (_token != null) {
          await _saveToken(_token!);
          return {'success': true};
        }
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed'
      };
    } catch (e) {
      print(' Register error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<bool> agentRegister({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String businessName,
  }) async {
    try {
      print(' Registering Agent: $email');
      
      final response = await http.post(
        Uri.parse(ApiConfig.AGENT_REGISTER),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
          'phone': phone,
          'businessName': businessName,
        }),
      );

      print(' Agent Register Status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        if (_token != null) {
          await _saveToken(_token!);
          return true;
        }
      }
      return false;
    } catch (e) {
      print(' Agent Register error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool isAgent = false,
  }) async {
    try {
      print(' Logging in (${isAgent ? 'Agent' : 'User'}): $email');
      
      final url = isAgent ? ApiConfig.AGENT_LOGIN : ApiConfig.USER_LOGIN;
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      print(' Login Status: ${response.statusCode}');
      print(' Login Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _token = data['token'];
        if (_token != null) {
          await _saveToken(_token!);
          return {'success': true};
        }
        return {'success': false, 'message': 'No token received from server'};
      }

      // Return the server's error message for all non-200 responses
      return {
        'success': false,
        'message': data['message'] ?? 'Login failed. Please try again.'
      };
    } catch (e) {
      print(' Login error: $e');
      return {'success': false, 'message': 'Connection error. Please check your internet.'};
    }
  }

  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }

  static Future<User?> getCurrentUser({bool forceRefresh = false}) async {
    if (forceRefresh) _currentUser = null;
    if (_currentUser != null) return _currentUser;
    
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.USER_PROFILE),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      print(' Get user Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        return _currentUser;
      }
    } catch (e) {
      print(' Get user error: $e');
    }
    return null;
  }

  static Future<bool> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http.put(
        Uri.parse(ApiConfig.UPDATE_PROFILE),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'fullName': fullName,
          'phone': phone,
        }),
      );

      print(' Update Profile Status: ${response.statusCode}');
      print(' Update Profile Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        return true;
      }
      return false;
    } catch (e) {
      print(' Update profile error: $e');
      return false;
    }
  }

  static bool isLoggedIn() {
    return _token != null;
  }

  /// Clears the in-memory user cache so the next call to getCurrentUser()
  /// fetches fresh data from the server.
  static void clearCache() {
    _currentUser = null;
  }
}