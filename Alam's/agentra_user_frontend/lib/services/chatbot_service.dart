import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ChatbotService {
  static String get _chatbotUrl => '${ApiConfig.BASE_URL}/chatbot/chat';

  static String? _sessionId;

  static Future<String?> startConversation() async {
    _sessionId = null;
    return 'ready';
  }

  // Original method — kept for compatibility
  static Future<String?> sendMessage({
    required String conversationId,
    required String message,
  }) async {
    final result = await sendMessageWithPackages(
      conversationId: conversationId,
      message: message,
    );
    return result?['reply'] as String?;
  }

  // New method — returns reply + packages
  static Future<Map<String, dynamic>?> sendMessageWithPackages({
    required String conversationId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_chatbotUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          if (_sessionId != null) 'sessionId': _sessionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sessionId = data['sessionId'];
        return {
          'reply': data['reply'] ?? '',
          'packages': data['packages'] ?? [],
        };
      }
    } catch (e) {
      print('🔴 Chatbot error: $e');
    }
    return null;
  }

  static Future<List<dynamic>> getConversationHistory(String conversationId) async {
    return [];
  }

  static void clearSession() {
    _sessionId = null;
  }
}