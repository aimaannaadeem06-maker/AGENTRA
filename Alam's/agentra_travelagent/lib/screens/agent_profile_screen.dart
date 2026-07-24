import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../models/agent.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';

class AgentProfileScreen extends StatefulWidget {
  const AgentProfileScreen({Key? key}) : super(key: key);

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen> {
  int _selectedNavIndex = 7;
  Agent? _agent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgent();
  }

  Future<void> _loadAgent() async {
    setState(() => _isLoading = true);
    final agent = await AuthService.getCurrentAgent();
    if (mounted) {
      setState(() {
        _agent = agent;
        _isLoading = false;
      });
    }
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Profile',
                          style: AppTextStyles.headingMedium),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/edit-profile')
                              .then((_) => _loadAgent());
                        },
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.white, size: 18),
                        label: const Text('Edit Profile',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _agent == null
                          ? const Center(child: Text('Failed to load profile'))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 900),
                                  child: Column(
                                    children: [
                                      // ── Profile Card ───────────────────
                                      Container(
                                        padding: const EdgeInsets.all(32),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.04),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            // Avatar
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 60,
                                                  backgroundColor: AppColors
                                                      .primary
                                                      .withOpacity(0.1),
                                                  backgroundImage: (_agent!
                                                                  .profileImage !=
                                                              null &&
                                                          _agent!.profileImage!
                                                              .isNotEmpty)
                                                      ? NetworkImage(ApiConfig
                                                          .getImageUrl(_agent!
                                                              .profileImage!))
                                                      : null,
                                                  onBackgroundImageError:
                                                      (_agent!.profileImage !=
                                                                  null &&
                                                              _agent!
                                                                  .profileImage!
                                                                  .isNotEmpty)
                                                          ? (_, __) {}
                                                          : null,
                                                  child:
                                                      (_agent!.profileImage ==
                                                                  null ||
                                                              _agent!
                                                                  .profileImage!
                                                                  .isEmpty)
                                                          ? Text(
                                                              _agent!
                                                                  .fullName[0]
                                                                  .toUpperCase(),
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 40,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color: AppColors
                                                                    .primary,
                                                              ),
                                                            )
                                                          : null,
                                                ),
                                                if (_agent!.isVerified)
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                          Icons.check,
                                                          color: Colors.white,
                                                          size: 16),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),
                                            // Name
                                            Text(
                                              _agent!.businessName.isNotEmpty
                                                  ? _agent!.businessName
                                                  : _agent!.fullName,
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF1B1E28),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _agent!.location != null &&
                                                      _agent!
                                                          .location!.isNotEmpty
                                                  ? _agent!.location!
                                                  : 'Travel Agent',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF7D848D),
                                              ),
                                            ),
                                            const SizedBox(height: 32),
                                            // Stats row
                                            Container(
                                              padding: const EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8F9FA),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  _buildStat(
                                                    _agent!.totalPackages
                                                        .toString(),
                                                    'Trips Uploaded',
                                                    AppColors.primary,
                                                  ),
                                                  Container(
                                                      width: 1,
                                                      height: 40,
                                                      color: const Color(
                                                          0xFFEEEEEE)),
                                                  _buildStat(
                                                    _agent!.totalBookings
                                                        .toString(),
                                                    'Total Bookings',
                                                    Colors.orange,
                                                  ),
                                                  Container(
                                                      width: 1,
                                                      height: 40,
                                                      color: const Color(
                                                          0xFFEEEEEE)),
                                                  _buildStat(
                                                    '${_agent!.averageRating.toStringAsFixed(1)}/5',
                                                    'Avg Rating',
                                                    Colors.amber,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // ── Two Column Layout ───────────────
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Left column
                                          Expanded(
                                            child: Column(
                                              children: [
                                                // Business Details
                                                _buildInfoCard(
                                                  'Business Details',
                                                  Icons.business_outlined,
                                                  [
                                                    _buildInfoRow(
                                                        Icons.phone_outlined,
                                                        'Contact',
                                                        _agent!.phone.isNotEmpty
                                                            ? _agent!.phone
                                                            : 'Not provided'),
                                                    _buildInfoRow(
                                                        Icons.email_outlined,
                                                        'Email',
                                                        _agent!.email),
                                                    _buildInfoRow(
                                                        Icons
                                                            .location_on_outlined,
                                                        'Location',
                                                        _agent!.location !=
                                                                    null &&
                                                                _agent!
                                                                    .location!
                                                                    .isNotEmpty
                                                            ? _agent!.location!
                                                            : 'Not provided'),
                                                    _buildInfoRow(
                                                        Icons.badge_outlined,
                                                        'CNIC',
                                                        _agent!.cnic.isNotEmpty
                                                            ? _agent!.cnic
                                                            : 'Not provided'),
                                                  ],
                                                ),
                                                const SizedBox(height: 24),
                                                // Verification Status
                                                _buildInfoCard(
                                                  'Account Status',
                                                  Icons.verified_outlined,
                                                  [
                                                    _buildStatusRow(
                                                        'Verification',
                                                        _agent!.isVerified
                                                            ? 'Verified'
                                                            : 'Pending',
                                                        _agent!.isVerified
                                                            ? Colors.green
                                                            : Colors.orange),
                                                    _buildStatusRow(
                                                        'Role',
                                                        _agent!.role,
                                                        AppColors.primary),
                                                    _buildStatusRow(
                                                        'Subscription',
                                                        'Free Plan',
                                                        Colors.blue),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          // Right column
                                          Expanded(
                                            child: Column(
                                              children: [
                                                // Refund Policy
                                                _buildPolicyCard(
                                                  'Refund Policy',
                                                  Icons.undo_outlined,
                                                  _agent!.refundPolicy,
                                                  Colors.orange,
                                                ),
                                                const SizedBox(height: 24),
                                                // Cancellation Policy
                                                _buildPolicyCard(
                                                  'Cancellation Policy',
                                                  Icons.cancel_outlined,
                                                  _agent!.cancellationPolicy,
                                                  Colors.red,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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

  Widget _buildStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF7D848D),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1E28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7D848D)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7D848D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1B1E28),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7D848D),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(
      String title, IconData icon, String? policy, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1E28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          policy != null && policy.isNotEmpty
              ? Text(
                  policy,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A4A4A),
                    height: 1.8,
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: color.withOpacity(0.2),
                        style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No $title added yet. Edit your profile to add one.',
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
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
