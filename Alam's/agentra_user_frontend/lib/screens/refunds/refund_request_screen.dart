import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';
import '../../config/api_config.dart';

class RefundRequestScreen extends StatefulWidget {
  const RefundRequestScreen({super.key});

  @override
  State<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends State<RefundRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Submit tab ──────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingBookings = true;
  List<Booking> _bookings = [];
  String? _selectedBookingId;

  // ── My Refunds tab ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _myRefunds = [];
  bool _isLoadingRefunds = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _isLoadingRefunds) {
        _loadMyRefunds();
      }
    });
    _loadBookings();
    _loadMyRefunds();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoadingBookings = true);
    final bookings = await BookingService.getMyBookings();
    if (mounted) {
      setState(() {
        _bookings = bookings
            .where((b) =>
                b.paymentStatus == 'PAID' &&
                b.status.toLowerCase() == 'cancelled' &&
                (b.refundStatus == null ||
                    b.refundStatus == 'NONE' ||
                    b.refundStatus == 'REQUESTED'))
            .toList();
        _isLoadingBookings = false;
      });
    }
  }

  Future<void> _loadMyRefunds() async {
    setState(() => _isLoadingRefunds = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/refund/my'),
        headers: {'x-auth-token': token},
      );
      if (r.statusCode == 200 && mounted) {
        final data = jsonDecode(r.body);
        final List raw = data['refundRequests'] ?? [];
        setState(() {
          _myRefunds = raw.map((e) {
            final pkg = e['packageId'] is Map ? e['packageId'] : {};
            return {
              'id':           e['_id'] ?? '',
              'package':      pkg['title'] ?? 'Unknown Package',
              'amount':       (e['totalAmount'] ?? 0).toDouble(),
              'refundStatus': e['refundStatus'] ?? 'NONE',
              'paymentStatus': e['paymentStatus'] ?? 'PAID',
              'reason':       e['cancellationReason'] ?? '',
              'date':         e['createdAt'] != null
                  ? _fmt(e['createdAt'])
                  : 'N/A',
            };
          }).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingRefunds = false);
  }

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _submitRefund() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBookingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a booking')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) { setState(() => _isLoading = false); return; }

      final response = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/refund/request'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({
          'bookingId': _selectedBookingId,
          'reason':    _reasonController.text.trim(),
        }),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.statusCode == 200 || response.statusCode == 201) {
          _reasonController.clear();
          setState(() => _selectedBookingId = null);
          await _loadBookings();
          await _loadMyRefunds();
          _tabController.animateTo(1); // switch to My Refunds tab
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Refund request submitted! The agent will review it shortly.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          final data = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to submit refund request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please try again.'), backgroundColor: Colors.red),
        );
      }
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
        title: const Text('Refunds', style: AppTextStyles.headingSmall),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Request Refund'),
            Tab(text: 'My Refunds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestTab(),
          _buildMyRefundsTab(),
        ],
      ),
    );
  }

  // ── Request Refund tab ──────────────────────────────────────────────────────
  Widget _buildRequestTab() {
    if (_isLoadingBookings) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Cancelled Booking',
                style: AppTextStyles.headingSmall),
            const SizedBox(height: 12),
            if (_bookings.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'No eligible bookings found. Only cancelled bookings with PAID status can be refunded.',
                  style: TextStyle(color: Colors.orange),
                ),
              )
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedBookingId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                hint: const Text('Select a booking'),
                items: _bookings.map((b) {
                  return DropdownMenuItem<String>(
                    value: b.id,
                    child: Text(
                      '${b.packageTitle} — PKR ${b.totalPrice.toStringAsFixed(0)}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedBookingId = val),
              ),
            const SizedBox(height: 24),
            CustomInput(
              label: 'Reason for Refund',
              hint: 'Please explain the reason for your refund request...',
              controller: _reasonController,
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a reason';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Submit Refund Request',
              onPressed: _bookings.isEmpty ? null : _submitRefund,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  // ── My Refunds tab ──────────────────────────────────────────────────────────
  Widget _buildMyRefundsTab() {
    if (_isLoadingRefunds) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_myRefunds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('No refund requests yet',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMyRefunds,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myRefunds.length,
        itemBuilder: (context, i) => _buildRefundCard(_myRefunds[i]),
      ),
    );
  }

  Widget _buildRefundCard(Map<String, dynamic> refund) {
    final status = refund['refundStatus'] as String;
    final paymentStatus = refund['paymentStatus'] as String;
    final amount = (refund['amount'] as double);

    // Determine display state
    final bool isApproved = status == 'APPROVED';
    final bool isRejected = status == 'REJECTED';
    final bool isPending  = status == 'REQUESTED';
    final bool isRefunded = paymentStatus == 'REFUNDED';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isApproved || isRefunded) {
      statusColor = Colors.green;
      statusLabel = 'Refunded ✅';
      statusIcon  = Icons.check_circle_rounded;
    } else if (isRejected) {
      statusColor = Colors.red;
      statusLabel = 'Rejected';
      statusIcon  = Icons.cancel_rounded;
    } else {
      statusColor = Colors.orange;
      statusLabel = 'Pending Review';
      statusIcon  = Icons.hourglass_empty_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        border: Border.all(
          color: statusColor.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  refund['package'],
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Requested: ${refund['date']}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              Text('PKR ${amount.toStringAsFixed(0)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isApproved || isRefunded
                          ? Colors.green
                          : AppColors.textPrimary)),
            ],
          ),
          if (refund['reason'] != null &&
              (refund['reason'] as String).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reason: ${refund['reason']}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary)),
          ],

          // Refunded confirmation banner
          if (isApproved || isRefunded) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PKR ${amount.toStringAsFixed(0)} has been credited to your wallet.',
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
