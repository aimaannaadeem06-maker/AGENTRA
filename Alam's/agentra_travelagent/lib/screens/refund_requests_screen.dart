import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../services/refund_service.dart';
import '../services/auth_service.dart';

class RefundRequestsScreen extends StatefulWidget {
  const RefundRequestsScreen({Key? key}) : super(key: key);

  @override
  State<RefundRequestsScreen> createState() => _RefundRequestsScreenState();
}

class _RefundRequestsScreenState extends State<RefundRequestsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 9;
  late TabController _tabController;
  bool _isLoading = true;

  // Refund requests loaded from API
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRefundRequests();
  }

  Future<void> _loadRefundRequests() async {
    setState(() => _isLoading = true);
    final requests = await RefundService.getRefundRequests();
    if (mounted) {
      setState(() {
        _requests = requests.map((r) {
          // Normalize API response to match UI expectations
          final user = r['userId'] is Map ? r['userId'] : {};
          final pkg = r['packageId'] is Map ? r['packageId'] : {};
          return {
            'id': r['_id'] ?? '',
            'user': user['fullName'] ?? 'Unknown User',
            'contact': user['phone'] ?? 'N/A',
            'email': user['email'] ?? 'N/A',
            'package': pkg['title'] ?? 'Unknown Package',
            'date': r['createdAt'] != null
                ? _formatDate(r['createdAt'])
                : 'N/A',
            'amount': (r['totalAmount'] ?? 0).toDouble(),
            'reason': r['cancellationReason'] ?? 'No reason provided',
            'status': _mapStatus(r['refundStatus']),
            'rejectionReason': null,
          };
        }).toList();
        _isLoading = false;
      });
    }
  }

  String _mapStatus(String? refundStatus) {
    switch (refundStatus) {
      case 'APPROVED':
        return 'accepted';
      case 'REJECTED':
        return 'rejected';
      default:
        return 'pending';
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}-${dt.month}-${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _pendingRequests =>
      _requests.where((r) => r['status'] == 'pending').toList();
  List<Map<String, dynamic>> get _acceptedRequests =>
      _requests.where((r) => r['status'] == 'accepted').toList();
  List<Map<String, dynamic>> get _rejectedRequests =>
      _requests.where((r) => r['status'] == 'rejected').toList();

  /// Shows a payment confirmation dialog before processing the refund.
  /// Fetches agent wallet balance first so the agent can see they have enough funds.
  void _showAcceptDialog(Map<String, dynamic> request) async {
    final amount = (request['amount'] as num).toDouble();

    // Fetch agent wallet balance
    double agentBalance = 0;
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        final r = await http.get(
          Uri.parse('${ApiConfig.BASE_URL}/wallet'),
          headers: {'x-auth-token': token},
        );
        if (r.statusCode == 200) {
          agentBalance = ((jsonDecode(r.body)['wallet']['balance']) ?? 0).toDouble();
        }
      }
    } catch (_) {}

    if (!mounted) return;

    final bool hasFunds = agentBalance >= amount;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: Colors.green, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Process Refund',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B1E28))),
                        Text('Transfer funds back to user wallet',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF7D848D))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Refund summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow('Customer', request['user']),
                    const SizedBox(height: 8),
                    _summaryRow('Package', request['package']),
                    const SizedBox(height: 8),
                    _summaryRow('Reason', request['reason'] ?? 'N/A'),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Refund Amount',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1B1E28))),
                        Text('PKR ${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Wallet balance indicator
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: hasFunds
                      ? Colors.green.withOpacity(0.06)
                      : Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasFunds
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasFunds
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: hasFunds ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Wallet Balance: PKR ${agentBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: hasFunds ? Colors.green : Colors.red,
                            ),
                          ),
                          if (!hasFunds)
                            const Text(
                              'Insufficient balance to process this refund.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Info note
              const Text(
                '💡 The refund amount will be deducted from your wallet and credited to the user\'s wallet instantly.',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7D848D),
                    height: 1.5),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFEEEEEE)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF1B1E28))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: hasFunds
                          ? () async {
                              Navigator.pop(ctx);
                              await _processRefund(request['id']);
                            }
                          : null,
                      icon: const Icon(Icons.send_outlined,
                          color: Colors.white, size: 18),
                      label: Text(
                        'Send PKR ${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF7D848D))),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B1E28))),
        ),
      ],
    );
  }

  Future<void> _processRefund(String id) async {
    final success = await RefundService.approveRefund(id);
    if (mounted) {
      if (success) {
        await _loadRefundRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Refund processed! Amount credited to user wallet.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to process refund. Check your wallet balance.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(String id) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.undo_outlined,
                    color: Colors.red, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reject Request',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1E28),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to reject this request?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7D848D),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for Rejection',
                  hintText: 'Enter reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side:
                            const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel',
                          style:
                              TextStyle(color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final success = await RefundService.rejectRefund(
                          id,
                          reason: reasonController.text.isNotEmpty
                              ? reasonController.text
                              : 'No reason provided',
                        );
                        if (success) {
                          await _loadRefundRequests();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Refund request rejected'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to reject refund'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Reject',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
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
                          const Text('Refund Requests',
                              style: AppTextStyles.headingMedium),
                          Text(
                            'Manage customer refund requests',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                      // Summary chips
                      Row(
                        children: [
                          _buildCountChip(
                              '${_pendingRequests.length} Pending',
                              Colors.orange),
                          const SizedBox(width: 8),
                          _buildCountChip(
                              '${_acceptedRequests.length} Accepted',
                              Colors.green),
                          const SizedBox(width: 8),
                          _buildCountChip(
                              '${_rejectedRequests.length} Rejected',
                              Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
                // Tabs
                Expanded(
                  child: Column(
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
                          tabs: [
                            Tab(
                                text:
                                    'Pending (${_pendingRequests.length})'),
                            Tab(
                                text:
                                    'Accepted (${_acceptedRequests.length})'),
                            Tab(
                                text:
                                    'Rejected (${_rejectedRequests.length})'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildRequestsList(_pendingRequests,
                                showActions: true),
                            _buildRequestsList(_acceptedRequests),
                            _buildRequestsList(_rejectedRequests,
                                showRejectionReason: true),
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

  Widget _buildCountChip(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildRequestsList(
    List<Map<String, dynamic>> requests, {
    bool showActions = false,
    bool showRejectionReason = false,
  }) {
    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.black12),
            SizedBox(height: 16),
            Text(
              'No requests here',
              style: TextStyle(
                color: Color(0xFF7D848D),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(
          request,
          showActions: showActions,
          showRejectionReason: showRejectionReason,
        );
      },
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> request, {
    bool showActions = false,
    bool showRejectionReason = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  request['user'][0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User: ${request['user']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1B1E28),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact: ${request['contact']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                    Text(
                      'Email id: ${request['email']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                    Text(
                      'Package: ${request['package']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                    Text(
                      'Requested: ${request['date']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7D848D),
                      ),
                    ),
                    if (request['reason'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${request['reason']}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7D848D),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${request['amount']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1E28),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(request['status']),
                ],
              ),
            ],
          ),

          // Rejection reason
          if (showRejectionReason &&
              request['rejectionReason'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection reason: ${request['rejectionReason']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons
          if (showActions) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(request['id']),
                  icon: const Icon(Icons.close,
                      color: Colors.red, size: 18),
                  label: const Text('Reject',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAcceptDialog(request),
                  icon: const Icon(Icons.check,
                      color: Colors.white, size: 18),
                  label: const Text('Accept & Refund',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'accepted':
        color = Colors.green;
        label = 'Accepted';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
