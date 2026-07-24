import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/package_card.dart';  // ✅ Widget
import '../../models/package.dart';         // ✅ Model
import '../../services/saved_packages_service.dart'; 

class SavedPackagesScreen extends StatefulWidget {
  const SavedPackagesScreen({super.key});

  @override
  State<SavedPackagesScreen> createState() => _SavedPackagesScreenState();
}

class _SavedPackagesScreenState extends State<SavedPackagesScreen> {
  List<Package> _savedPackages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPackages();
  }

  Future<void> _loadSavedPackages() async {
    final packages = await SavedPackagesService.getSavedPackages();
    if (mounted) {
      setState(() {
        _savedPackages = packages;
        _isLoading = false;
      });
    }
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
          'Saved Packages',
          style: AppTextStyles.headingSmall,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _savedPackages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border,
                          size: 64, color: AppColors.textTertiary),
                      SizedBox(height: 16),
                      Text(
                        'No saved packages yet',
                        style: AppTextStyles.bodyMedium,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap the bookmark icon on any package to save it',
                        style: TextStyle(color: AppColors.textTertiary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: _savedPackages.length,
                  itemBuilder: (context, index) {
                    final package = _savedPackages[index];
                    return PackageCard(
                      imageUrl: package.image ?? '',
                      title: package.title,
                      duration: package.duration,
                      price: 'PKR ${package.price}',
                      description: package.description,
                      rating: package.rating ?? 4.5,
                      showSaleBadge: false,
                      package: package,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/package-detail',
                          arguments: package.id,
                        );
                      },
                    );
                  },
                ),
    );
  }
}