import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/agent.dart';
import '../config/api_config.dart';
import 'dart:async';

class SideNavigation extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const SideNavigation({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  State<SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<SideNavigation> {
  Agent? _agent;

  @override
  void initState() {
    super.initState();
    _loadAgent();
  }

  Future<void> _loadAgent() async {
    // Use refreshCurrentAgent to ensure we get the latest subscription status
    final agent = await AuthService.refreshCurrentAgent();
    if (mounted) {
      setState(() => _agent = agent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header with Profile
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: (_agent?.profileImage != null &&
                          _agent!.profileImage!.isNotEmpty)
                      ? NetworkImage(
                          ApiConfig.getImageUrl(_agent!.profileImage!))
                      : null,
                  onBackgroundImageError: (_agent?.profileImage != null &&
                          _agent!.profileImage!.isNotEmpty)
                      ? (_, __) {}
                      : null,
                  child: (_agent?.profileImage == null ||
                          _agent!.profileImage!.isEmpty)
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  _agent?.businessName ?? _agent?.fullName ?? 'Loading...',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_agent?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _agent!.email,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // ── Plan Badge ──────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_agent?.isPro ?? false)
                        ? Colors.amber.shade600
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (_agent?.isPro ?? false)
                            ? Icons.workspace_premium
                            : Icons.card_membership_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (_agent?.isPro ?? false)
                            ? (_agent!.subscriptionPlan == 'YEARLY'
                                ? 'Pro Annual'
                                : 'Pro Monthly')
                            : 'Free Plan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Navigation Items
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
                    widget.onItemSelected(0);
                    Navigator.pushReplacementNamed(context, '/dashboard');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.add_box_outlined,
                  label: 'Create Package',
                  index: 2,
                  onTap: () {
                    widget.onItemSelected(2);
                    Navigator.pushNamed(context, '/create-package');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: 'Bookings',
                  index: 3,
                  onTap: () {
                    widget.onItemSelected(3);
                    Navigator.pushNamed(context, '/bookings');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.undo_outlined,
                  label: 'Refund Requests',
                  index: 9,
                  onTap: () {
                    widget.onItemSelected(9);
                    Navigator.pushNamed(context, '/refund-requests');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.bar_chart_outlined,
                  label: 'Performance',
                  index: 4,
                  onTap: () {
                    widget.onItemSelected(4);
                    Navigator.pushNamed(context, '/performance');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.payment_outlined,
                  label: 'Payment History',
                  index: 5,
                  onTap: () {
                    widget.onItemSelected(5);
                    Navigator.pushNamed(context, '/payment-history');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.card_membership_outlined,
                  label: 'Subscription',
                  index: 6,
                  onTap: () {
                    widget.onItemSelected(6);
                    Navigator.pushNamed(context, '/subscription');
                  },
                ),
                _buildNavItem(
                  context,
                  icon: Icons.report_problem_outlined,
                  label: 'Complaints',
                  index: 11,
                  onTap: () {
                    widget.onItemSelected(11);
                    Navigator.pushNamed(context, '/agent-complaints');
                  },
                ),
                const Divider(height: 32),
                _buildNavItem(
                  context,
                  icon: Icons.person_outline,
                  label: 'Profile',
                  index: 7,
                  onTap: () {
                    widget.onItemSelected(7);
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
              ],
            ),
          ),
          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text(
                'Logout',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                await AuthService.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                }
              },
            ),
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
  }) {
    final isSelected = widget.selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
