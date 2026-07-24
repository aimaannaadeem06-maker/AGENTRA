import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../services/booking_service.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({Key? key}) : super(key: key);

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 3;
  late TabController _tabController;
  bool _isLoading = true;

  // Track which packages are expanded
  final Set<String> _expandedPackages = {};

  // Real data from API
  List<dynamic> _allBookingsRaw = [];
  Map<String, Map<String, dynamic>> _groupedPackages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    final bookings = await BookingService.getAgentBookings();

    // Group bookings by package
    Map<String, Map<String, dynamic>> grouped = {};
    for (var b in bookings) {
      final package = b['packageId'];
      if (package == null) continue;

      final pkgId = package['_id'];
      if (!grouped.containsKey(pkgId)) {
        grouped[pkgId] = {
          'id': pkgId,
          'title': package['title'] ?? 'Unknown Package',
          'image': package['image'] ?? '',
          'location': package['location'] ?? '',
          'date': b['createdAt'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(b['createdAt']))
              : 'Unknown',
          'price': package['price'] ?? 0,
          'bookings': [],
        };
      }
      grouped[pkgId]!['bookings'].add(b);
    }

    if (mounted) {
      setState(() {
        _allBookingsRaw = bookings;
        _groupedPackages = grouped;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _totalConfirmed => _allBookingsRaw.where((b) {
        final s = (b['status'] ?? '').toString().toUpperCase();
        return s == 'CONFIRMED' || s == 'COMPLETED';
      }).length;

  int get _totalCancelled => _allBookingsRaw
      .where((b) => (b['status'] ?? '').toString().toUpperCase() == 'CANCELLED')
      .length;

  double get _totalRevenue => _allBookingsRaw.where((b) {
        final s = (b['status'] ?? '').toString().toUpperCase();
        return s == 'CONFIRMED' || s == 'COMPLETED';
      }).fold(0.0, (sum, b) => sum + (b['totalAmount'] ?? 0).toDouble());

  Future<void> _cancelBooking(
      String bookingId, String packageTitle, dynamic booking) async {
    final TextEditingController reasonController = TextEditingController();

    // Fetch agent's refund & cancellation policy from the booking's agentId
    String refundPolicy = '';
    String cancellationPolicy = '';
    try {
      final agentId = booking['agentId'];
      if (agentId != null) {
        final agentIdStr = agentId is Map ? agentId['_id'] : agentId.toString();
        final token = await _getToken();
        if (token != null) {
          final resp = await http.get(
            Uri.parse('${ApiConfig.BASE_URL}/packages/agent/$agentIdStr'),
            headers: {'x-auth-token': token},
          );
          // Try fetching agent profile directly
          final agentResp = await http.get(
            Uri.parse('${ApiConfig.BASE_URL}/auth/agent/profile'),
            headers: {'x-auth-token': token},
          );
          if (agentResp.statusCode == 200) {
            final data = jsonDecode(agentResp.body);
            refundPolicy = data['agent']?['refundPolicy'] ?? '';
            cancellationPolicy = data['agent']?['cancellationPolicy'] ?? '';
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(32),
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Cancel Booking',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Are You Sure You Want To Cancel The Booking?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1E28),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booking for $packageTitle',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF7D848D)),
                ),

                // ── Policies ──────────────────────────────────────────
                if (refundPolicy.isNotEmpty ||
                    cancellationPolicy.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Agent Policies',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        if (cancellationPolicy.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Cancellation Policy:',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF1B1E28),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cancellationPolicy,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4A4A4A),
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (refundPolicy.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Refund Policy:',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF1B1E28),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            refundPolicy,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4A4A4A),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                const Text(
                  'Reason for Cancellation',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1B1E28),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Natural disaster, operational issue...',
                    hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Keep',
                          style: TextStyle(
                              color: Color(0xFF1B1E28),
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Cancel Booking',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      final success = await BookingService.cancelBooking(
          bookingId, reasonController.text.trim());
      if (mounted) {
        if (success) {
          _showCancelSuccessDialog();
          _loadBookings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to cancel booking')),
          );
        }
      }
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  void _showCancelSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(40),
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cancelled successfully',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1E28),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Real-time Bookings',
                              style: AppTextStyles.headingMedium),
                          Text(
                            'View and manage all your customer bookings',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                      if (!_isLoading)
                        Row(
                          children: [
                            _buildChip('$_totalConfirmed Active', Colors.green),
                            const SizedBox(width: 8),
                            _buildChip(
                                '$_totalCancelled Cancelled', Colors.red),
                            const SizedBox(width: 8),
                            _buildChip(
                                'PKR ${_totalRevenue.toStringAsFixed(0)}',
                                AppColors.primary),
                          ],
                        ),
                    ],
                  ),
                ),
                // Tabs
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            Container(
                              color: Colors.white,
                              child: TabBar(
                                controller: _tabController,
                                labelColor: AppColors.primary,
                                unselectedLabelColor: AppColors.textTertiary,
                                indicatorColor: AppColors.primary,
                                labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w700),
                                tabs: const [
                                  Tab(text: 'By Package'),
                                  Tab(text: 'All Bookings'),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildByPackageTab(),
                                  _buildAllBookingsTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildByPackageTab() {
    if (_groupedPackages.isEmpty) {
      return _buildEmptyState();
    }

    final packages = _groupedPackages.values.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: packages.length,
      itemBuilder: (context, index) {
        final package = packages[index];
        final bookings = package['bookings'] as List;
        final confirmedCount = bookings.where((b) {
          final s = (b['status'] ?? '').toString().toUpperCase();
          return s == 'CONFIRMED' || s == 'COMPLETED';
        }).length;
        final isExpanded = _expandedPackages.contains(package['id']);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedPackages.remove(package['id']);
                    } else {
                      _expandedPackages.add(package['id']);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          image: (package['image'] != null &&
                                  package['image'].isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(
                                      ApiConfig.getImageUrl(package['image'])),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: (package['image'] == null ||
                                package['image'].isEmpty)
                            ? const Icon(Icons.landscape_outlined,
                                color: AppColors.primary, size: 32)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              package['title'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1E28),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 14, color: Color(0xFF7D848D)),
                                const SizedBox(width: 4),
                                Text(
                                  package['location'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7D848D),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.green, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '$confirmedCount bookings',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: Color(0xFF7D848D)),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                const Divider(height: 1),
                ...List<Widget>.from(
                  (bookings as List).map(
                    (booking) => _buildBookingRow(booking, package['title']),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookingRow(dynamic booking, String packageTitle) {
    final String rawStatus = (booking['status'] ?? '').toString().toUpperCase();
    final bool isConfirmed =
        rawStatus == 'CONFIRMED' || rawStatus == 'COMPLETED';
    final user = booking['userId'] ?? {};
    final fullName = user['fullName'] ?? 'Anonymous';
    final email = user['email'] ?? 'No email';
    final phone = user['phone'] ?? 'No phone';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isConfirmed
            ? Colors.green.withOpacity(0.02)
            : Colors.red.withOpacity(0.02),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              fullName[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1B1E28),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isConfirmed
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        booking['status'].toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isConfirmed ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildDetailRow(Icons.phone_outlined, 'Contact: $phone'),
                _buildDetailRow(Icons.email_outlined, 'Email: $email'),
                _buildDetailRow(
                    Icons.event_seat_outlined, 'Seats: ${booking['seats']}'),
                _buildDetailRow(Icons.payments_outlined,
                    'Total Paid: PKR ${booking['totalAmount']}'),
                Builder(builder: (_) {
                  final total = (booking['totalAmount'] ?? 0).toDouble();
                  final commission = (booking['commissionAmount'] ?? total * 0.05).toDouble();
                  final earning = (booking['agentEarning'] ?? total - commission).toDouble();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildDetailRow(Icons.percent_outlined,
                        'Platform Commission (5%): PKR ${commission.toStringAsFixed(0)}'),
                    _buildDetailRow(Icons.monetization_on_outlined,
                        'Your Earning (95%): PKR ${earning.toStringAsFixed(0)}'),
                  ]);
                }),
                _buildDetailRow(Icons.calendar_today_outlined,
                    'Booked on: ${DateFormat('dd MMM yyyy').format(DateTime.parse(booking['createdAt']))}'),
              ],
            ),
          ),
          if (isConfirmed)
            TextButton(
              onPressed: () =>
                  _cancelBooking(booking['_id'], packageTitle, booking),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: Colors.red.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7D848D)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4A4A4A))),
        ],
      ),
    );
  }

  Widget _buildAllBookingsTab() {
    if (_allBookingsRaw.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: _allBookingsRaw.length,
      itemBuilder: (context, index) {
        final booking = _allBookingsRaw[index];
        final package = booking['packageId'] ?? {};
        return _buildBookingRow(booking, package['title'] ?? 'Unknown Package');
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No bookings found',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
