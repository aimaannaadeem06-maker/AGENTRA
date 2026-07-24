import 'server_config.dart';

class ApiConfig {
  // ── Change this to match where you're running ──────────────────────────────
  // Web browser → localhost
  // Android emulator → 10.0.2.2
  // Physical device (same Wi-Fi) → your PC's LAN IP
  static final String SERVER_URL = ServerConfig.serverUrl;
  static final String BASE_URL = '$SERVER_URL/api';

  // ===== AUTH ENDPOINTS =====
  static final String USER_LOGIN = "$BASE_URL/auth/user/login";
  static final String USER_REGISTER = "$BASE_URL/auth/user/register";

  static final String AGENT_LOGIN = "$BASE_URL/auth/agent/login";
  static final String AGENT_REGISTER = "$BASE_URL/auth/agent/register";

  // ===== PACKAGE ENDPOINTS =====
  static final String PACKAGES = '$BASE_URL/packages';
  static final String AGENT_PACKAGES = '$BASE_URL/packages/agent';
  static String packageDetail(String id) => '$BASE_URL/packages/$id';

  // ===== SEARCH ENDPOINTS =====
  static final String SEARCH = '$BASE_URL/search';
  // Default search: only Murree & Lahore
  static final String SEARCH_DEFAULT = '$BASE_URL/search?cities=Murree,Lahore';
  static String searchQuery(String q) =>
      '$BASE_URL/search?q=${Uri.encodeComponent(q)}';
  static String searchByCities(String cities) =>
      '$BASE_URL/search?cities=${Uri.encodeComponent(cities)}';

  // ===== SAVED PACKAGES ENDPOINTS =====
  static final String SAVED_PACKAGES = '$BASE_URL/saved';
  static final String SAVED_COUNT = '$BASE_URL/saved/count';
  static String toggleSave(String packageId) =>
      '$BASE_URL/saved/$packageId/toggle';
  static String checkSaved(String packageId) =>
      '$BASE_URL/saved/$packageId/check';
  static String unsavePackage(String packageId) => '$BASE_URL/saved/$packageId';

  // ===== WALLET ENDPOINTS =====
  static final String WALLET = '$BASE_URL/wallet';
  static final String WALLET_CARDS = '$BASE_URL/wallet/cards';
  static String removeCard(String cardId) => '$BASE_URL/wallet/cards/$cardId';
  static final String WALLET_PAY = '$BASE_URL/wallet/pay';
  static final String WALLET_WITHDRAW = '$BASE_URL/wallet/withdraw';
  static final String WALLET_BANK = '$BASE_URL/wallet/bank-account';

  // ===== AGENT ENDPOINTS =====
  static final String AGENT_PROFILE = '$BASE_URL/auth/agent/profile';
  static final String UPDATE_AGENT_PROFILE = '$BASE_URL/auth/agent/profile';
  static final String AGENT_DASHBOARD = '$BASE_URL/dashboard/agent';
  static final String AGENT_ANALYTICS = '$BASE_URL/analytics/agent';
  static final String AGENT_PERFORMANCE = '$BASE_URL/dashboard/agent';
  static final String AGENT_COMPLAINTS = '$BASE_URL/complaints/agent-received';
  static final String AGENT_BOOKINGS = '$BASE_URL/bookings/agent';
  static final String AGENT_REFUNDS = '$BASE_URL/refund/agent';

  // ===== PAYMENT ENDPOINTS =====
  static final String PAYMENT_PROCESS = '$BASE_URL/payments/process';
  static final String PAYMENT_HISTORY = '$BASE_URL/payments/history';
  static final String PAYMENT_INTENT = '$BASE_URL/payments/intent';

  // ===== BOOKING ENDPOINTS =====
  static final String CREATE_BOOKING = '$BASE_URL/users/bookings';
  static final String USER_BOOKINGS = '$BASE_URL/users/bookings';

  // ===== Owner / OWNER ENDPOINTS =====
  static final String OWNER_LOGIN = '$BASE_URL/auth/owner/login';
  static final String OWNER_DASHBOARD = '$BASE_URL/dashboard/owner';
  static final String OWNER_COMMISSION_ANALYTICS =
      '$BASE_URL/dashboard/owner/commission-analytics';
  static final String OWNER_COMMISSION_REPORT =
      '$BASE_URL/dashboard/owner/commission-report';
  static final String ALL_AGENTS = '$BASE_URL/owner/agents';

  // New Approval Workflow Routes
  static final String PENDING_AGENTS = '$BASE_URL/auth/owner/agents/pending';
  static String approveAgent(String id) =>
      '$BASE_URL/owner/travel-agents/$id/approve';
  static String rejectAgent(String id) =>
      '$BASE_URL/owner/travel-agents/$id/reject';

  // Legacy / Other Owner Routes
  static final String COMPLAINTS = '$BASE_URL/complaints';
  static String updateComplaint(String id) => '$BASE_URL/complaints/$id';

  // ===== NOTIFICATION ENDPOINTS =====
  static final String NOTIFICATIONS = '$BASE_URL/notifications';
  static final String MARK_ALL_READ = '$BASE_URL/notifications/read-all';
  static String markRead(String id) => '$BASE_URL/notifications/$id/read';

  // ===== UPLOAD ENDPOINTS =====
  static final String UPLOAD_IMAGE = '$BASE_URL/upload/image';

  // ===== UTILITY =====
  static String getImageUrl(String? path) {
    final String result;
    if (path == null || path.isEmpty) {
      result = 'https://placehold.co/600x400/e2e8f0/475569?text=No+Image';
    } else if (path.startsWith('http')) {
      result = path;
    } else if (path.startsWith('/')) {
      result = '$SERVER_URL$path';
    } else {
      result = '$SERVER_URL/$path';
    }
    print('🖼️ [AgentApp] getImageUrl: "$path" -> "$result"');
    return result;
  }
}
