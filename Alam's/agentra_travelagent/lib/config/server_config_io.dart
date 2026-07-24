import 'dart:io' show Platform;

class ServerConfig {
  static String get serverUrl {
    // All platforms point to the live Render backend
    return 'https://agentra-backend.onrender.com';
  }
}
