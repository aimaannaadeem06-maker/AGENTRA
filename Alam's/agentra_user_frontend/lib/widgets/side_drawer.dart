import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';
import '../../models/user.dart';

class SideDrawer extends StatefulWidget {
  const SideDrawer({super.key});

  @override
  State<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends State<SideDrawer> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    // Always fetch fresh data (clearCache ensures no stale data)
    AuthService.clearCache();
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() => _user = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Header
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 40,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: (_user?.profileImage != null && _user!.profileImage!.isNotEmpty)
                        ? Image.network(
                            _user!.profileImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.person,
                              size: 36,
                              color: AppColors.textTertiary,
                            ),
                          )
                        : const Icon(Icons.person, size: 36, color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _user?.fullName ?? 'Traveler',
                  style: AppTextStyles.headingMedium.copyWith(fontSize: 22, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.email ?? 'Connecting...',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: AppColors.borderLight, indent: 24, endIndent: 24),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                _buildSectionTitle('ACCOUNT'),
                _buildMenuItem(
                  context,
                  Icons.person_outline_rounded,
                  'Edit Profile',
                  () => Navigator.pushNamed(context, '/edit-profile').then((updated) {
                    if (updated == true) _loadUser();
                  }),
                ),
                _buildMenuItem(
                  context,
                  Icons.bookmark_border_rounded,
                  'Saved Packages',
                  () => Navigator.pushNamed(context, '/saved-packages'),
                ),
                
                const SizedBox(height: 24),
                _buildSectionTitle('ACTIVITY'),
                _buildMenuItem(
                  context,
                  Icons.receipt_long_outlined,
                  'My Bookings',
                  () => Navigator.pushNamed(context, '/bookings'),
                ),
                _buildMenuItem(
                  context,
                  Icons.local_offer_outlined,
                  'Promotions',
                  () => Navigator.pushNamed(context, '/promotions'),
                ),
                _buildMenuItem(
                  context,
                  Icons.credit_card_outlined,
                  'Payments',
                  () => Navigator.pushNamed(context, '/payment-history'),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('SUPPORT'),
                _buildMenuItem(
                  context,
                  Icons.account_balance_wallet_outlined,
                  'Refunds',
                  () => Navigator.pushNamed(context, '/refund-request'),
                ),
                _buildMenuItem(
                  context,
                  Icons.info_outline_rounded,
                  'Help & Complaints',
                  () => Navigator.pushNamed(context, '/complaint'),
                ),
              ],
            ),
          ),
          
          // Logout Footer
          Padding(
            padding: const EdgeInsets.all(24),
            child: InkWell(
              onTap: () async {
                await AuthService.logout();
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textTertiary.withOpacity(0.5),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      minLeadingWidth: 20,
      leading: Icon(icon, color: AppColors.textPrimary, size: 20),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
