import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AgentSideDrawer extends StatelessWidget {
  const AgentSideDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Profile Header with Blue Background
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 24,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              children: [
                // Profile Photo
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aimen Nadeem',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Travel Agent',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context,
                  Icons.dashboard_outlined,
                  'Dashboard',
                  () {
                    Navigator.pushReplacementNamed(context, '/agent/dashboard');
                  },
                ),
                _buildMenuItem(
                  context,
                  Icons.add_box_outlined,
                  'Create Package',
                  () {
                    Navigator.pushNamed(context, '/agent/create-package');
                  },
                ),
                _buildMenuItem(
                  context,
                  Icons.list_alt_outlined,
                  'My Packages',
                  () {
                    Navigator.pushNamed(context, '/agent/dashboard-packages');
                  },
                ),
                _buildMenuItem(
                  context,
                  Icons.person_outline,
                  'Edit Profile',
                  () {
                    Navigator.pushNamed(context, '/edit-profile');
                  },
                ),
                _buildMenuItem(
                  context,
                  Icons.money_off_outlined,
                  'Refund Requests',
                  () {
                    Navigator.pushNamed(context, '/refund-request');
                  },
                ),
                const Divider(),
                _buildMenuItem(
                  context,
                  Icons.swap_horiz,
                  'Switch to User Mode',
                  () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                ),
                _buildMenuItem(
                  context,
                  Icons.logout,
                  'Logout',
                  () {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  },
                  isLogout: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isLogout ? AppColors.error : AppColors.textPrimary,
        size: 20,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isLogout ? AppColors.error : AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textTertiary,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
