import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../services/package_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilter = false;
  bool _isLoadingLocations = true;
  List<String> _locations = [];
  
  // Filter states
  final Set<String> _selectedPrices = {};
  final Set<String> _selectedLocations = {};
  final Set<String> _selectedDurations = {};

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final locs = await PackageService.getLocations();
    if (mounted) {
      setState(() {
        _locations = locs;
        _isLoadingLocations = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFilter() {
    setState(() => _showFilter = !_showFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Search',
          style: AppTextStyles.headingSmall,
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: AppTextStyles.bodyMedium,
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              Navigator.pushNamed(context, '/search-results', arguments: value);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Search places...',
                            hintStyle: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textTertiary,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.textTertiary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _toggleFilter,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _showFilter ? AppColors.primary : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          border: Border.all(
                            color: _showFilter ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Icon(
                          Icons.tune,
                          color: _showFilter ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Search Places Grid
              Expanded(
                child: _isLoadingLocations
                    ? const Center(child: CircularProgressIndicator())
                    : _locations.isEmpty
                        ? const Center(child: Text('No locations available.'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: _locations.length,
                            itemBuilder: (context, index) {
                              return _buildPlaceCard(_locations[index], index);
                            },
                          ),
              ),
            ],
          ),
          // Filter Modal
          if (_showFilter)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleFilter,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: GestureDetector(
                    onTap: () {}, // Prevent closing when tapping modal
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Handle
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.borderLight,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Scrollable filter checklist
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Filter',
                                      style: AppTextStyles.headingMedium,
                                    ),
                                    const SizedBox(height: 24),
                                    // Price
                                    Text(
                                      'Price',
                                      style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildCheckbox('0 - 5000', _selectedPrices),
                                    _buildCheckbox('6000 - 10000', _selectedPrices),
                                    _buildCheckbox('11000 & Above', _selectedPrices),
                                    const SizedBox(height: 24),
                                    // Location
                                    Text(
                                      'Location',
                                      style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildCheckbox('Murree', _selectedLocations),
                                    _buildCheckbox('Lahore', _selectedLocations),
                                    const SizedBox(height: 24),
                                    // Duration
                                    Text(
                                      'Duration',
                                      style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildCheckbox('1-3 Days', _selectedDurations),
                                    _buildCheckbox('4-7 Days', _selectedDurations),
                                    _buildCheckbox('8-11 Days', _selectedDurations),
                                  ],
                                ),
                              ),
                            ),
                            // Fixed "See Results" Action Button at the bottom
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: CustomButton(
                                text: 'See Results',
                                onPressed: () {
                                  _toggleFilter();
                                  Navigator.pushNamed(context, '/search-results');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(String place, int index) {
    // Variety of travel-related images for the grid
    final images = [
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500',
      'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=500',
      'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=500',
      'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=500',
      'https://images.unsplash.com/photo-1433086566085-52f0b8982a84?w=500',
      'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=500',
    ];
    final imageUrl = images[index % images.length];

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/search-results', arguments: place);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radius),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(12),
          child: Text(
            place,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, Set<String> selectedSet) {
    final isSelected = selectedSet.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedSet.remove(label);
          } else {
            selectedSet.add(label);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
