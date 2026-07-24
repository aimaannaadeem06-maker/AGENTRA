import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  int _selectedNavIndex = 13;
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _packages = [];
  String _selectedCity = 'All';
  Timer? _debounce;

  // Default cities shown when no search query
  static const List<String> _defaultCities = ['Murree', 'Lahore'];
  static const List<String> _cityFilters = ['All', 'Murree', 'Lahore'];

  @override
  void initState() {
    super.initState();
    _loadDefaultPackages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadDefaultPackages() async {
    setState(() => _isLoading = true);
    try {
      final url = '${ApiConfig.SEARCH}?cities=${_defaultCities.join(',')}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _packages = data['packages'] ?? [];
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

  Future<void> _searchPackages(String query) async {
    setState(() => _isLoading = true);
    try {
      String url;
      if (query.isEmpty) {
        // Revert to default Murree + Lahore
        if (_selectedCity == 'All') {
          url = '${ApiConfig.SEARCH}?cities=${_defaultCities.join(',')}';
        } else {
          url = '${ApiConfig.SEARCH}?cities=$_selectedCity';
        }
      } else {
        url = '${ApiConfig.SEARCH}?q=${Uri.encodeComponent(query)}';
        if (_selectedCity != 'All') {
          url += '&location=${Uri.encodeComponent(_selectedCity)}';
        }
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _packages = data['packages'] ?? [];
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchPackages(value);
    });
  }

  void _onCityFilterChanged(String city) {
    setState(() => _selectedCity = city);
    _searchPackages(_searchController.text);
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Search Packages',
                          style: AppTextStyles.headingMedium),
                      const SizedBox(height: 16),
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search by destination, package name...',
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.primary),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Color(0xFF7D848D)),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadDefaultPackages();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFFEEEEEE)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFFEEEEEE)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.primary),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // City Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _cityFilters.map<Widget>((city) {
                            final isSelected = _selectedCity == city;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(city),
                                selected: isSelected,
                                onSelected: (_) => _onCityFilterChanged(city),
                                selectedColor:
                                    AppColors.primary.withOpacity(0.15),
                                checkmarkColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFF7D848D),
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  fontSize: 13,
                                ),
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFFEEEEEE),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Results
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _packages.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadDefaultPackages,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _packages.length,
                                itemBuilder: (context, index) {
                                  return _buildCompactCard(_packages[index]);
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
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No packages found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1E28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term or city',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCard(dynamic pkg) {
    final title = pkg['title'] ?? 'Unknown Package';
    final location = pkg['location'] ?? '';
    final price = (pkg['price'] ?? 0).toDouble();
    final duration = pkg['duration'] ?? '';
    final image = pkg['image'] ?? '';
    final hasDiscount = pkg['hasDiscount'] == true;
    final discountPct = (pkg['discountPercentage'] ?? 0).toDouble();
    final discountedPrice = hasDiscount && discountPct > 0
        ? price * (1 - discountPct / 100)
        : price;
    final rating = (pkg['rating'] ?? 0).toDouble();

    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // Navigate to package detail
          },
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: image.isNotEmpty
                    ? Image.network(
                        ApiConfig.getImageUrl(image),
                        width: 110,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1E28),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Location + Duration
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Color(0xFF7D848D)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '$location • $duration',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7D848D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Price + Discount + Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (hasDiscount && discountPct > 0) ...[
                                Text(
                                  'PKR ${discountedPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '-${discountPct.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ] else
                                Text(
                                  'PKR ${price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 12, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1B1E28),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 110,
      height: 120,
      color: const Color(0xFFEEEEEE),
      child: const Icon(Icons.image_outlined,
          color: Color(0xFFBBBBBB), size: 28),
    );
  }
}
