import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/owner_service.dart';

class OwnerSideNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const OwnerSideNavigation({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agentra',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Owner Portal',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  index: 0,
                  onTap: () {
                    onItemSelected(0);
                    Navigator.pushReplacementNamed(
                        context, '/owner-dashboard');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.people_outlined,
                  label: 'Manage Accounts',
                  index: 1,
                  onTap: () {
                    onItemSelected(1);
                    Navigator.pushNamed(
                        context, '/owner-manage-accounts');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.verified_outlined,
                  label: 'Agent Verification',
                  index: 2,
                  onTap: () {
                    onItemSelected(2);
                    Navigator.pushNamed(
                        context, '/owner-agent-verification');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.report_outlined,
                  label: 'Complaints',
                  index: 3,
                  onTap: () {
                    onItemSelected(3);
                    Navigator.pushNamed(
                        context, '/owner-complaints');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Financial Overview',
                  index: 4,
                  onTap: () {
                    onItemSelected(4);
                    Navigator.pushNamed(
                        context, '/owner-financial');
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  child: Divider(color: Colors.white12),
                ),
                _buildNavItem(
                  context,
                  icon: Icons.logout,
                  label: 'Logout',
                  index: 99,
                  isLogout: true,
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              '© 2026 Agentra',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log out of your account?',
          style: TextStyle(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            children: [
              const Divider(),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await OwnerService.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/login', (route) => false);
                    }
                  },
                  child: const Text(
                    'Log out',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const Divider(),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final bool isSelected = selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(
                color: AppColors.primary.withOpacity(0.3))
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout
              ? Colors.red
              : isSelected
                  ? AppColors.primary
                  : Colors.white54,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isLogout
                ? Colors.red
                : isSelected
                    ? Colors.white
                    : Colors.white70,
            fontWeight: isSelected
                ? FontWeight.w700
                : FontWeight.w400,
            fontSize: 14,
          ),
        ),
        trailing: (!isLogout && !isSelected)
            ? const Icon(Icons.chevron_right,
                color: Colors.white24, size: 18)
            : null,
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
