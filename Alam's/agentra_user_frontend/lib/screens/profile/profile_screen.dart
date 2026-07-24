import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/side_drawer.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/saved_packages_service.dart';
import '../../models/user.dart';
import '../../models/booking.dart';
import '../../models/package.dart';
import '../../config/api_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 4;
  User? _user;
  List<Booking> _completedBookings = [];
  List<Package> _savedPackages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      AuthService.getCurrentUser(forceRefresh: true),
      BookingService.getMyBookings(),
      SavedPackagesService.getSavedPackages(),
    ]);

    if (mounted) {
      setState(() {
        _user = results[0] as User?;
        final bookings = results[1] as List<Booking>;
        _completedBookings = bookings
            .where((b) =>
                b.status.toLowerCase() == 'completed' &&
                b.packageTitle != 'Unknown Package')
            .toList();
        _savedPackages = results[2] as List<Package>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const SideDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Profile', style: AppTextStyles.headingSmall),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // ── Avatar ──────────────────────────────────────────
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primary,
                      backgroundImage: (_user?.profileImage != null &&
                              _user!.profileImage!.isNotEmpty)
                          ? NetworkImage(_user!.profileImage!)
                          : null,
                      onBackgroundImageError: (_user?.profileImage != null &&
                              _user!.profileImage!.isNotEmpty)
                          ? (exception, stackTrace) {
                              print('🔴 Profile image load error: $exception');
                            }
                          : null,
                      child: (_user?.profileImage == null ||
                              _user!.profileImage!.isEmpty)
                          ? const Icon(Icons.person,
                              size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _user?.fullName ?? 'Guest User',
                      style: AppTextStyles.headingMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _user?.email ?? 'Sign in to see details',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),

                    // ── Stats Row ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: _buildStatItem(
                                'Travel\nTrips',
                                '${_user?.totalBookings ?? 0}',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/bookings'),
                              ),
                            ),
                          ),
                          Container(
                              width: 1, height: 40, color: AppColors.border),
                          Expanded(
                            child: Center(
                              child: _buildStatItem(
                                'Favourites',
                                '${_savedPackages.length}',
                                onTap: () => Navigator.pushNamed(
                                        context, '/saved-packages')
                                    .then((_) => _loadData()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Trips Completed ─────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Trips Completed',
                            style: AppTextStyles.headingSmall),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _completedBookings.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'No trips completed yet.',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textTertiary),
                            ),
                          )
                        : SizedBox(
                            height: 180,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _completedBookings.length,
                              itemBuilder: (context, index) =>
                                  _buildTripCard(_completedBookings[index]),
                            ),
                          ),
                    const SizedBox(height: 24),

                    // ── Edit Profile ────────────────────────────────────
                    if (_user != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CustomButton(
                          text: 'Edit Profile',
                          onPressed: () =>
                              Navigator.pushNamed(context, '/edit-profile')
                                  .then((_) => _loadData()),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 4) return;
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/home');
              break;
            case 1:
              Navigator.pushNamed(context, '/bookings');
              break;
            case 2:
              Navigator.pushNamed(context, '/chat');
              break;
            case 3:
              Navigator.pushNamed(context, '/search');
              break;
          }
        },
      ),
    );
  }

  // ── Tappable stat item ──────────────────────────────────────────────────────
  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.primary,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Completed trip card ─────────────────────────────────────────────────────
  Widget _buildTripCard(Booking booking) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              image: (booking.packageImage != null &&
                      booking.packageImage!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(
                          ApiConfig.getImageUrl(booking.packageImage!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child:
                (booking.packageImage == null || booking.packageImage!.isEmpty)
                    ? const Center(
                        child: Icon(Icons.image,
                            color: AppColors.textTertiary, size: 40),
                      )
                    : null,
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.packageTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  booking.travelDate,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (booking.status.toLowerCase() == 'completed')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/write-review',
                        arguments: {
                          'packageId': booking.packageId,
                          'packageTitle': booking.packageTitle,
                        },
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(0, 30),
                      ),
                      child: const Text(
                        'Write Review',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
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
}
