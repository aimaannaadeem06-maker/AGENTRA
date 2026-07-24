import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/package.dart';
import 'auth_service.dart';

class SavedPackagesService {
  /// Fetches all saved packages for the logged-in user.
  /// Backend: GET /api/saved  → { savedPackages: [{ packageId: {...} }] }
  static Future<List<Package>> getSavedPackages() async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.SAVED_PACKAGES),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend returns savedPackages array where each item has a packageId object
        final List saved = data['savedPackages'] ?? [];
        final List<Package> packages = [];
        for (final item in saved) {
          final pkgJson = item['packageId'];
          if (pkgJson != null && pkgJson is Map<String, dynamic>) {
            try {
              packages.add(Package.fromJson(pkgJson));
            } catch (_) {}
          }
        }
        return packages;
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  /// Returns true if the package is already saved by the current user.
  /// Backend: GET /api/saved/:packageId/check → { isSaved: bool }
  static Future<bool> isPackageSaved(String packageId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.checkSaved(packageId)),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isSaved'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// Toggles save/unsave for a package.
  /// Backend: POST /api/saved/:packageId/toggle → { isSaved: bool }
  /// Returns true if the package is now saved, false if unsaved.
  static Future<bool> toggleSave(String packageId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.toggleSaved(packageId)),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['isSaved'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// Saves a package (convenience wrapper around toggleSave).
  static Future<void> savePackage(String packageId) async {
    await toggleSave(packageId);
  }

  /// Unsaves a package.
  /// Backend: DELETE /api/saved/:packageId
  static Future<void> unsavePackage(String packageId) async {
    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      await http.delete(
        Uri.parse('${ApiConfig.SAVED_PACKAGES}/$packageId'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );
    } catch (_) {}
  }
}
