import 'server_config.dart';

class ApiConfig {
  static final String SERVER_URL = ServerConfig.serverUrl;
  static final String BASE_URL = '$SERVER_URL/api';

  static String getImageUrl(String? path) {
    final String result;
    if (path == null || path.isEmpty) {
      result = 'https://placehold.co/600x400/e2e8f0/475569?text=No+Image';
    } else if (path.startsWith('http') || path.startsWith('data:')) {
      result = path;
    } else if (path.startsWith('/')) {
      result = '$SERVER_URL$path';
    } else {
      result = '$SERVER_URL/$path';
    }
    print('🖼️ [UserApp] getImageUrl: "$path" -> "$result"');
    return result;
  }

  // ===== AUTH ENDPOINTS =====
  static final String USER_REGISTER = '$BASE_URL/auth/user/register';
  static final String USER_LOGIN = '$BASE_URL/auth/user/login';
  static final String USER_LOGOUT = '$BASE_URL/auth/user/logout';
  static final String AGENT_REGISTER = '$BASE_URL/auth/agent/register';
  static final String AGENT_LOGIN = '$BASE_URL/auth/agent/login';

  // ===== PACKAGE ENDPOINTS =====
  static final String PACKAGES = '$BASE_URL/packages';
  static final String PACKAGE_LOCATIONS = '$BASE_URL/packages/locations';
  static final String SEARCH = '$BASE_URL/search';
  static final String PROMOTIONS = '$BASE_URL/promotion';
  static String packageDetail(String id) => '$BASE_URL/packages/$id';

  // ===== BOOKING ENDPOINTS =====
  static final String BOOKINGS = '$BASE_URL/bookings';
  static final String MY_BOOKINGS = '$BASE_URL/bookings/my';
  static String cancelBooking(String id) => '$BASE_URL/bookings/$id/cancel';

  // ===== USER ENDPOINTS =====
  static final String USER_PROFILE = '$BASE_URL/users/profile';
  static final String UPDATE_PROFILE = '$BASE_URL/users/profile';
  static final String USER_PREFERENCES = '$BASE_URL/users/preferences';
  static final String UPLOAD_IMAGE = '$BASE_URL/upload/image';

  // ===== PAYMENT ENDPOINTS =====
  static final String PAYMENT_METHODS = '$BASE_URL/payments/methods';
  static final String PAYMENT_INTENT = '$BASE_URL/payments/intent';
  static final String PROCESS_PAYMENT = '$BASE_URL/payments/process';
  // /payments/history returns transactions for the logged-in user
  static final String PAYMENT_HISTORY = '$BASE_URL/payments/history';
  static String verifyPayment(String transactionId) =>
      '$BASE_URL/payments/verify/$transactionId';

  // ===== REVIEW ENDPOINTS =====
  static final String REVIEWS = '$BASE_URL/users/reviews';
  static final String CREATE_REVIEW = '$BASE_URL/users/reviews';
  static final String MY_REVIEWS = '$BASE_URL/users/reviews';

  // ===== COMPLAINT ENDPOINTS =====
  static final String SUBMIT_COMPLAINT = '$BASE_URL/complaints';
  static final String MY_COMPLAINTS = '$BASE_URL/complaints';

  // ===== CHATBOT ENDPOINTS =====
  static final String CHATBOT = '$BASE_URL/chatbot';
  static final String CHATBOT_START = '$BASE_URL/chatbot/start';
  static final String CHATBOT_MESSAGE = '$BASE_URL/chatbot/message';
  static String chatbotHistory(String conversationId) =>
      '$BASE_URL/chatbot/$conversationId';

  // ===== SAVED PACKAGES ENDPOINTS =====
  // Backend routes: POST /saved/:packageId/toggle  GET /saved
  static final String SAVED_PACKAGES = '$BASE_URL/saved';
  static String toggleSaved(String packageId) =>
      '$BASE_URL/saved/$packageId/toggle';
  static String checkSaved(String packageId) =>
      '$BASE_URL/saved/$packageId/check';

  // Legacy favorites endpoint (kept for backward compat)
  static final String TOGGLE_FAVORITE = '$BASE_URL/users/favorites/toggle';

  // ===== WALLET ENDPOINTS =====
  static final String WALLET = '$BASE_URL/wallet';
  static final String WALLET_CARDS = '$BASE_URL/wallet/cards';
  static String removeCard(String cardId) => '$BASE_URL/wallet/cards/$cardId';
  static final String WALLET_PAY = '$BASE_URL/wallet/pay';

  // ===== AGENT ENDPOINTS =====
  static final String AGENT_DASHBOARD = '$BASE_URL/dashboard/agent';
  static final String AGENT_ANALYTICS = '$BASE_URL/analytics/agent';
  static final String SUBSCRIPTION_PLANS = '$BASE_URL/subscription/plans';
  static final String CURRENT_SUBSCRIPTION = '$BASE_URL/subscription/current';
  static final String EARNINGS_OVERVIEW = '$BASE_URL/earnings/overview';
}
