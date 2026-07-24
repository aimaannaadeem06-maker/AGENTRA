import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/package.dart';
import 'auth_service.dart';

class PackageService {
  static Future<List<Package>> getPackages({String? search}) async {
    try {
      String url = ApiConfig.PACKAGES;
      if (search != null && search.isNotEmpty) {
        url = '${ApiConfig.SEARCH}?q=$search';
      }

      print('🔵 Fetching packages from: $url');

      final response = await http.get(Uri.parse(url));

      print('🟢 Packages Status: ${response.statusCode}');
      print('🟢 Packages Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> packagesJson = data['packages'] ?? data['data'] ?? [];
        return packagesJson.map((json) => Package.fromJson(json)).toList();
      }
    } catch (e) {
      print('🔴 Get packages error: $e');
    }
    return [];
  }

  static Future<Package?> getPackageDetail(String id) async {
    try {
      print('🔵 Fetching package detail: $id');
      
      final response = await http.get(
        Uri.parse(ApiConfig.packageDetail(id)),
      );

      print('🟢 Package Detail Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Bug 5 fix: track view so analytics/performance screen shows real data
        _trackView(id);
        return Package.fromJson(data['package']);
      }
    } catch (e) {
      print('🔴 Get package detail error: $e');
    }
    return null;
  }

  /// Fire-and-forget view tracking — does not block the UI.
  static void _trackView(String packageId) {
    http.post(
      Uri.parse('${ApiConfig.BASE_URL}/analytics/package/$packageId/view'),
    ).catchError((_) {});
  }

  /// Fire-and-forget click tracking — call when user taps "Book Now".
  static void trackClick(String packageId) {
    http.post(
      Uri.parse('${ApiConfig.BASE_URL}/analytics/package/$packageId/click'),
    ).catchError((_) {});
  }

  static Future<bool> createBooking({
    required String packageId,
    required int seats,
    required String travelDate,
    required String paymentMethod,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse(ApiConfig.BOOKINGS),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'packageId': packageId,
          'seats': seats,
          'travelDate': travelDate,
          'paymentMethod': paymentMethod,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('🔴 Create booking error: $e');
      return false;
    }
  }

  static Future<List<String>> getLocations() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.PACKAGE_LOCATIONS));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['locations'] ?? []);
      }
    } catch (e) {
      print('🔴 Get locations error: $e');
    }
    return [];
  }
}