import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/package_card.dart';
import '../../models/package.dart';
import '../../services/package_service.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  List<Package> _packages = [];
  bool _isLoading = true;
  String? _query;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _query == null) {
      _query = args;
      _fetchResults();
    } else if (_query == null) {
      _query = "";
      _fetchResults();
    }
  }

  Future<void> _fetchResults() async {
    setState(() => _isLoading = true);
    final results = await PackageService.getPackages(search: _query);
    if (mounted) {
      setState(() {
        _packages = results;
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
        title: Text(
          _query?.isNotEmpty == true ? 'Search: $_query' : 'Search Results',
          style: AppTextStyles.headingSmall,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${_packages.length} Packages Found',
                    style: AppTextStyles.headingSmall.copyWith(fontSize: 18),
                  ),
                ),
                Expanded(
                  child: _packages.isEmpty
                      ? const Center(
                          child: Text(
                            'No packages found for this search.',
                            style: AppTextStyles.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _packages.length,
                          itemBuilder: (context, index) {
                            final package = _packages[index];
                            return PackageCard(
                              imageUrl: package.image ?? '',
                              title: package.title,
                              duration: package.duration,
                              price: 'PKR ${package.price}',
                              description: package.description,
                              rating: package.rating ?? 0.0,
                              showSaleBadge: package.hasDiscount == true &&
                                  (package.discountPercentage ?? 0) > 0,
                              discountPercentage:
                                  package.discountPercentage ?? 0,
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
                ),
              ],
            ),
    );
  }
}
