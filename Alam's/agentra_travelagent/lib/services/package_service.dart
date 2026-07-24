import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/package.dart';
import 'auth_service.dart';

class PackageService {
  static Future<List<String>> getPackageLocations() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.PACKAGES}/locations'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final locations = data['locations'];
          if (locations is List) {
            return locations
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList();
          }
        }
      }
    } catch (e) {
      print('Get package locations error: $e');
    }

    return ['Lahore', 'Murree'];
  }

  static Future<List<Package>> getAgentPackages() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(ApiConfig.AGENT_PACKAGES),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> packagesJson = data['packages'] ?? [];
        return packagesJson.map((json) => Package.fromJson(json)).toList();
      }
    } catch (e) {
      print('Get agent packages error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> createPackage({
    required String title,
    required String description,
    required String location,
    required double price,
    required String duration,
    required int availableSeats,
    String? image,
    String? province,
    String? departureCity,
    String? notIncluded,
    String? tripHighlights,
    bool includesTransport = false,
    bool includesAccommodation = false,
    bool includesMeals = false,
    bool isFeatured = false,
    bool hasDiscount = false,
    double discountPercentage = 0,
    DateTime? startDate,
    DateTime? endDate,
    List<DateTime> availableDates = const [],
    List<Map<String, dynamic>> itinerary = const [],
    String? departureTime,
    String? departureLocation,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final requestBody = {
        'title': title,
        'description': description,
        'location': location,
        'price': price,
        'duration': duration,
        'availableSeats': availableSeats,
        if (image != null && image.isNotEmpty) 'image': image,
        if (province != null && province.isNotEmpty) 'province': province,
        if (departureCity != null && departureCity.isNotEmpty)
          'departureCity': departureCity,
        if (notIncluded != null && notIncluded.isNotEmpty)
          'notIncluded': notIncluded,
        if (tripHighlights != null && tripHighlights.isNotEmpty)
          'tripHighlights': tripHighlights,
        'includes': {
          'transport': includesTransport,
          'accommodation': includesAccommodation,
          'meals': includesMeals,
        },
        'isFeatured': isFeatured,
        'hasDiscount': hasDiscount,
        'discountPercentage': discountPercentage,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        'availableDates':
            availableDates.map((d) => d.toIso8601String()).toList(),
        'itinerary': itinerary,
        if (departureTime != null && departureTime.isNotEmpty)
          'departureTime': departureTime,
        if (departureLocation != null && departureLocation.isNotEmpty)
          'departureLocation': departureLocation,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.PACKAGES),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create package'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<bool> updatePackage(
      String id, Map<String, dynamic> updateData) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse(ApiConfig.packageDetail(id)),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode(updateData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Update package error: $e');
      return false;
    }
  }

  static Future<bool> deletePackage(String id) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse(ApiConfig.packageDetail(id)),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Delete package error: $e');
      return false;
    }
  }

  /// Uploads an [XFile] image to the server.
  /// Uses [MultipartFile.fromBytes] so it works on all platforms
  /// (Flutter Web, Android, iOS, Windows desktop).
  static Future<String?> uploadImage(dynamic imageFile) async {
    try {
      // Read bytes — works on every platform, no dart:io needed
      final bytes = await imageFile.readAsBytes();
      final filename =
          imageFile.name.isNotEmpty ? imageFile.name : 'profile.jpg';

      final token = await AuthService.getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.UPLOAD_IMAGE),
      );

      if (token != null) {
        request.headers['x-auth-token'] = token;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: filename,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['url'];
      }
      return null;
    } catch (e) {
      print('❌ [UPLOAD] Exception: $e');
      return null;
    }
  }
}
