import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/package_card.dart';
import '../../models/package.dart';
import '../../services/package_service.dart';
import '../../widgets/side_drawer.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../config/api_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Package> _packages = [];
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();
    final packages = await PackageService.getPackages();
    if (mounted) {
      setState(() {
        _user = user;
        _packages = packages;
        _isLoading = false;
      });
    }
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushNamed(context, '/bookings').then((_) {
          setState(() => _currentIndex = 0);
        });
        break;
      case 2:
        Navigator.pushNamed(context, '/chat').then((_) {
          setState(() => _currentIndex = 0);
        });
        break;
      case 3:
        Navigator.pushNamed(context, '/search').then((_) {
          setState(() => _currentIndex = 0);
        });
        break;
      case 4:
        Navigator.pushNamed(context, '/profile').then((_) {
          setState(() => _currentIndex = 0);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const SideDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // ── Header & Greeting ──────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                        onPressed: () => scaffoldKey.currentState?.openDrawer(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        backgroundImage: (_user?.profileImage != null &&
                                _user!.profileImage!.isNotEmpty)
                            ? NetworkImage(_user!.profileImage!)
                            : null,
                        child: (_user?.profileImage == null ||
                                _user!.profileImage!.isEmpty)
                            ? const Icon(Icons.person,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Explore Title ──────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_user != null && _user!.fullName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Hello, ${_user!.fullName.split(' ')[0]}!',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      RichText(
                        text: TextSpan(
                          style: AppTextStyles.headingLarge.copyWith(
                            fontSize: 28,
                            height: 1.2,
                          ),
                          children: const [
                            TextSpan(text: 'Explore the\nBeautiful '),
                            TextSpan(
                              text: 'world!',
                              style: TextStyle(
                                color: AppColors.orange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Search Bar ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radius),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              color: AppColors.textTertiary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Search destinations...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Content (Loading/Empty/List) ───────────────────────
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                )
              else if (_packages.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined,
                            size: 64, color: AppColors.textTertiary),
                        SizedBox(height: 16),
                        Text(
                          'No packages available',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
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
                            package.discountPercentage ?? 0.0,
                        package: package,
                        onReviewTap: () {
                          Navigator.pushNamed(
                            context,
                            '/reviews',
                            arguments: package.id,
                          );
                        },
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/package-detail',
                            arguments: package.id,
                          );
                        },
                      );
                    },
                    childCount: _packages.length,
                  ),
                ),
              
              // Bottom padding for navigation bar
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
