import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';

class SavedPackagesScreen extends StatefulWidget {
  const SavedPackagesScreen({Key? key}) : super(key: key);

  @override
  State<SavedPackagesScreen> createState() => _SavedPackagesScreenState();
}

class _SavedPackagesScreenState extends State<SavedPackagesScreen> {
  int _selectedNavIndex = 12;
  bool _isLoading = true;
  List<dynamic> _savedPackages = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPackages();
  }

  Future<void> _loadSavedPackages() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.SAVED_PACKAGES),
        headers: {'x-auth-token': token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _savedPackages = data['savedPackages'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unsavePackage(String packageId, String packageTitle) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final response = await http.delete(
        Uri.parse(ApiConfig.unsavePackage(packageId)),
        headers: {'x-auth-token': token},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$packageTitle" removed from saved'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadSavedPackages();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove package'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          SideNavigation(
            selectedIndex: _selectedNavIndex,
            onItemSelected: (index) =>
                setState(() => _selectedNavIndex = index),
          ),
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Saved Packages',
                              style: AppTextStyles.headingMedium),
                          Text(
                            '${_savedPackages.length} package${_savedPackages.length == 1 ? '' : 's'} saved',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadSavedPackages,
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _savedPackages.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadSavedPackages,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(24),
                                itemCount: _savedPackages.length,
                                itemBuilder: (context, index) {
                                  final item = _savedPackages[index];
                                  final pkg = item['packageId'];
                                  if (pkg == null) return const SizedBox();
                                  return _buildSavedCard(item, pkg);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No saved packages yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1E28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Packages you save will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCard(dynamic item, dynamic pkg) {
    final title = pkg['title'] ?? 'Unknown Package';
    final location = pkg['location'] ?? '';
    final price = (pkg['price'] ?? 0).toDouble();
    final rating = (pkg['rating'] ?? 0).toDouble();
    final duration = pkg['duration'] ?? '';
    final image = pkg['image'] ?? '';
    final hasDiscount = pkg['hasDiscount'] == true;
    final discountPct = (pkg['discountPercentage'] ?? 0).toDouble();
    final discountedPrice = hasDiscount && discountPct > 0
        ? price * (1 - discountPct / 100)
        : price;
    final savedAt = item['savedAt'] ?? item['createdAt'];
    final savedDate = savedAt != null
        ? DateTime.parse(savedAt).toString().split(' ')[0]
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            child: image.isNotEmpty
                ? Image.network(
                    ApiConfig.getImageUrl(image),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderImage(),
                  )
                : _placeholderImage(),
          ),
          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Bookmark
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1E28),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark,
                            color: AppColors.primary, size: 22),
                        onPressed: () => _unsavePackage(pkg['_id'], title),
                        tooltip: 'Remove from saved',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: Color(0xFF7D848D)),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7D848D),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.schedule_outlined,
                          size: 14, color: Color(0xFF7D848D)),
                      const SizedBox(width: 4),
                      Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7D848D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Price + Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasDiscount && discountPct > 0) ...[
                            Text(
                              'PKR ${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7D848D),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'PKR ${discountedPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '-${discountPct.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Text(
                              'PKR ${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B1E28),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (savedDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Saved on $savedDate',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 120,
      height: 120,
      color: const Color(0xFFEEEEEE),
      child: const Icon(Icons.image_outlined,
          color: Color(0xFFBBBBBB), size: 32),
    );
  }
}
