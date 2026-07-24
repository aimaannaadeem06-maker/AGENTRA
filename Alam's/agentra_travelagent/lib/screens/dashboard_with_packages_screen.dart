import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../services/package_service.dart';
import '../services/auth_service.dart';
import '../models/package.dart';
import 'agent_reviews_screen.dart';
import 'edit_package_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/agent.dart';

class DashboardWithPackagesScreen extends StatefulWidget {
  const DashboardWithPackagesScreen({Key? key}) : super(key: key);

  @override
  State<DashboardWithPackagesScreen> createState() => _DashboardWithPackagesScreenState();
}

class _DashboardWithPackagesScreenState extends State<DashboardWithPackagesScreen> {
  List<Package> _packages = [];
  bool _isLoading = true;
  int _totalBookings = 0;
  final double _totalEarnings = 0;
  double _averageRating = 0;
  bool _isPro = false;
  String _agentName = 'Agent';

  // Notifications
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  // Periodic polling timer for real-time notification updates
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _loadDashboardStats();
    _loadNotifications();
    // Poll for new notifications every 30 seconds
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadNotifications(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse(ApiConfig.NOTIFICATIONS),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _notifications = data['notifications'] ?? [];
            _unreadCount = data['unreadCount'] ?? 0;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      await http.patch(
        Uri.parse(ApiConfig.MARK_ALL_READ),
        headers: {'x-auth-token': token},
      );
      if (mounted) {
        setState(() {
          _unreadCount = 0;
          for (final n in _notifications) {
            n['isRead'] = true;
          }
        });
      }
    } catch (_) {}
  }

  void _showNotificationPanel(BuildContext context) {
    _markAllRead();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(_),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // List
              Flexible(
                child: _notifications.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none,
                                size: 56, color: Colors.black12),
                            SizedBox(height: 12),
                            Text('No notifications yet',
                                style: TextStyle(color: Color(0xFF7D848D))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (_, i) {
                          final n = _notifications[i];
                          final isRead = n['isRead'] == true;
                          final type = n['type'] ?? '';
                          Color iconColor = AppColors.primary;
                          IconData iconData = Icons.notifications_outlined;
                          if (type == 'ACCOUNT_BLOCKED') {
                            iconColor = Colors.red;
                            iconData = Icons.block;
                          } else if (type == 'ACCOUNT_DELETED') {
                            iconColor = Colors.red.shade900;
                            iconData = Icons.delete_forever;
                          } else if (type == 'BOOKING_CANCELLED') {
                            iconColor = Colors.orange;
                            iconData = Icons.cancel_outlined;
                          }
                          return Container(
                            color: isRead
                                ? Colors.transparent
                                : AppColors.primary.withOpacity(0.04),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData,
                                      color: iconColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.w600
                                              : FontWeight.w800,
                                          fontSize: 14,
                                          color: const Color(0xFF1B1E28),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        n['message'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF7D848D),
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n['createdAt'] != null
                                            ? DateTime.parse(n['createdAt'])
                                                .toString()
                                                .split(' ')[0]
                                            : '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFAAAAAA),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadDashboardStats() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse(ApiConfig.AGENT_DASHBOARD),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _totalBookings = data['bookings'] ?? 0;
          });
        }
      }
      // Also load agent profile for rating
      final profileResp = await http.get(
        Uri.parse(ApiConfig.AGENT_PROFILE),
        headers: {'x-auth-token': token},
      );
      if (profileResp.statusCode == 200) {
        final pData = jsonDecode(profileResp.body);
        final agentJson = pData['agent'];
        if (mounted && agentJson != null) {
          final agent = Agent.fromJson(agentJson);
          setState(() {
            _averageRating = agent.averageRating;
            _isPro = agent.isPro;
            _agentName = agent.fullName;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);
    final packages = await PackageService.getAgentPackages();
    if (mounted) {
      setState(() {
        _packages = packages;
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
          // Permanent sidebar — same as all other screens
          SideNavigation(
            selectedIndex: 1,
            onItemSelected: (_) {},
          ),
          // Main content
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Top Bar
                SliverAppBar(
                  floating: true,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: false,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Hi, $_agentName!',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B1E28),
                            ),
                          ),
                          if (_isPro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'PRO PREMIUM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Text(
                        'Check your travel portal overview today',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF7D848D),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    // Bell icon with unread badge — Fix 1 (wire onPressed) & Fix 2 (remove profile avatar)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none, color: Color(0xFF1B1E28)),
                            onPressed: () => _showNotificationPanel(context),
                          ),
                          if (_unreadCount > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Stats Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildStatCard('Total Packages',
                                  '${_packages.length}', '', Colors.green),
                              const SizedBox(width: 16),
                              _buildStatCard('Active Bookings',
                                  '$_totalBookings', '', Colors.blue),
                              const SizedBox(width: 16),
                              _buildStatCard('Avg Rating',
                                  _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '—',
                                  '', Colors.amber),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Packages',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B1E28),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/create-package').then((_) => _loadPackages());
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '+ Add New',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                
                // Package List
                _isLoading
                    ? const SliverToBoxAdapter(
                        child: Center(child: Padding(
                          padding: EdgeInsets.all(100.0),
                          child: CircularProgressIndicator(),
                        )),
                      )
                    : _packages.isEmpty
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 50),
                                  const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.black12),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No packages created yet',
                                    style: TextStyle(
                                      color: Color(0xFF7D848D),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: 200,
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.pushNamed(context, '/create-package').then((_) => _loadPackages()),
                                      icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                      label: const Text('Create Package',
                                          style: TextStyle(color: Colors.white, fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 380,
                                mainAxisSpacing: 20,
                                crossAxisSpacing: 20,
                                childAspectRatio: 0.78,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildPackageCard(context, _packages[index]),
                                childCount: _packages.length,
                              ),
                            ),
                          ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String change, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7D848D),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B1E28),
            ),
          ),
          if (change.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  change,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Package', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this package? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await PackageService.deletePackage(id);
      if (success && mounted) {
        _loadPackages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package deleted successfully'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    }
  }

  Widget _buildPackageCard(BuildContext context, Package package) {
    final hasImage = package.image != null && package.image!.isNotEmpty;
    final imageUrl = ApiConfig.getImageUrl(package.image);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
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
          // ── Image area ──────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image with graceful fallback
                    hasImage
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imagePlaceholder(),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: const Color(0xFFF0F0F0),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                          )
                        : _imagePlaceholder(),
                    // Discount Badge
                    if (package.hasDiscount && package.discountPercentage > 0)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_offer,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${package.discountPercentage.toInt()}% OFF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Rating Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              package.rating != null
                                  ? package.rating!.toStringAsFixed(1)
                                  : '—',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Info area ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  package.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B1E28),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${package.duration} · ${package.location}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7D848D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price — Fix 3: show strikethrough original + discounted price
                    if (package.hasDiscount && package.discountPercentage > 0) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PKR ${package.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9E9E9E),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Color(0xFF9E9E9E),
                            ),
                          ),
                          Text(
                            'PKR ${(package.price * (1 - package.discountPercentage / 100)).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        'PKR ${package.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.orange,
                        ),
                      ),
                    // Action buttons — compact
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _cardIconBtn(
                          Icons.star_outline,
                          Colors.amber,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AgentReviewsScreen(package: package),
                            ),
                          ),
                        ),
                        _cardIconBtn(
                          Icons.edit_outlined,
                          Colors.blue,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditPackageScreen(package: package),
                            ),
                          ).then((_) => _loadPackages()),
                        ),
                        _cardIconBtn(
                          Icons.delete_outline,
                          Colors.red,
                          () => _handleDelete(package.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Icon(Icons.image_outlined,
            color: Color(0xFFBBBBBB), size: 40),
      ),
    );
  }
}
