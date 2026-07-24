import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 5;
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> _subscriptionPayments = [];
  List<Map<String, dynamic>> _packageSales = [];
  List<Map<String, dynamic>> _refunds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Use the payments/history endpoint which returns all transactions for this agent
      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/payments/history'),
        headers: {'x-auth-token': token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend returns both 'transactions' and 'payments' keys for compatibility
        final List<dynamic> transactions =
            data['transactions'] ?? data['payments'] ?? [];

        final List<Map<String, dynamic>> subs = [];
        final List<Map<String, dynamic>> sales = [];
        final List<Map<String, dynamic>> refs = [];

        for (var t in transactions) {
          final type = (t['type'] ?? '').toString();
          final date = t['createdAt'] != null
              ? DateTime.parse(t['createdAt']).toString().split(' ')[0]
              : 'N/A';

          if (type == 'SUBSCRIPTION') {
            subs.add({
              'plan': t['notes'] ?? 'Pro Plan',
              'date': date,
              'amount': (t['amount'] ?? 0).toDouble(),
              'status': 'Paid',
              'method': t['paymentMethod'] ?? 'JAZZCASH',
            });
          } else if (type == 'EARNING') {
            final commission = ((t['commissionAmount'] ?? 0) as num).toDouble();
            final netEarning = ((t['amount'] ?? 0) as num).toDouble();
            final grossAmount = netEarning + commission;

            final bookingData = t['bookingId'];
            final bookingPaymentStatus = bookingData is Map
                ? (bookingData['paymentStatus'] ?? '').toString()
                : '';
            final bookingStatus = bookingData is Map
                ? (bookingData['status'] ?? '').toString()
                : '';
            final transactionPayoutStatus =
                (t['payoutStatus'] ?? '').toString();

            final isSuccessfulBooking = bookingPaymentStatus == 'PAID' &&
                transactionPayoutStatus != 'FAILED' &&
                bookingStatus != 'CANCELLED' &&
                bookingStatus != 'REFUNDED';

            if (isSuccessfulBooking) {
              final bookingIdRaw = t['bookingId'];
              final bookingId = bookingIdRaw is Map
                  ? (bookingIdRaw['_id'] ?? '').toString()
                  : (bookingIdRaw ?? '').toString();
              sales.add({
                'bookingId': bookingId.isNotEmpty
                    ? bookingId.substring(
                        bookingId.length > 8 ? bookingId.length - 8 : 0)
                    : 'N/A',
                'package': t['packageId']?['title'] ?? 'Travel Package',
                'customer': t['userId']?['fullName'] ?? 'Customer',
                'date': date,
                'gross': grossAmount,
                'commission': commission,
                'net': netEarning,
                'status': 'Received',
              });
            }
          } else if (type == 'REFUND') {
            refs.add({
              'package': t['packageId']?['title'] ?? 'Travel Package',
              'customer': t['userId']?['fullName'] ?? 'Customer',
              'date': date,
              'amount': (t['amount'] ?? 0).toDouble(),
              'reason': t['notes'] ?? 'Cancelled',
              'status': 'Processed',
            });
          }
        }

        if (mounted) {
          setState(() {
            _subscriptionPayments = subs;
            _packageSales = sales;
            _refunds = refs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Summary calculations
  double get _totalEarned => _packageSales
      .where((s) => s['status'] == 'Received')
      .fold(0.0, (sum, s) => sum + (s['gross'] as num).toDouble());

  double get _totalSubscriptions => _subscriptionPayments.fold(
      0.0, (sum, s) => sum + (s['amount'] as num).toDouble());

  double get _totalRefunded => _refunds
      .where((r) => r['status'] == 'Processed')
      .fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());

  double get _totalCommission => _packageSales
      .where((s) => s['status'] == 'Received')
      .fold(0.0, (sum, s) => sum + (s['commission'] as num).toDouble());

  double get _netAmount =>
      _totalEarned - _totalCommission - _totalSubscriptions - _totalRefunded;

  Future<void> _downloadReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating report...')),
      );

      final doc = pw.Document();
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text('Payment History Report',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text('Generated: $dateStr',
                style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),

            // Summary
            pw.Header(level: 1, text: 'Summary'),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Amount (PKR)'],
              data: [
                ['Total Earned', _totalEarned.toStringAsFixed(0)],
                ['Platform Commission', _totalCommission.toStringAsFixed(0)],
                [
                  'Paid to Subscriptions',
                  _totalSubscriptions.toStringAsFixed(0)
                ],
                ['Refunded Amount', _totalRefunded.toStringAsFixed(0)],
                ['Net Amount', _netAmount.toStringAsFixed(0)],
              ],
            ),
            pw.SizedBox(height: 16),

            // Package Sales
            if (_packageSales.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Package Sales'),
              pw.Table.fromTextArray(
                headers: [
                  'Booking ID',
                  'Package',
                  'Customer',
                  'Date',
                  'Net (PKR)',
                  'Status'
                ],
                data: _packageSales
                    .map((s) => [
                          s['bookingId'] ?? 'N/A',
                          s['package'],
                          s['customer'],
                          s['date'],
                          s['net'].toString(),
                          s['status'],
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // Subscriptions
            if (_subscriptionPayments.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Subscriptions'),
              pw.Table.fromTextArray(
                headers: ['Plan', 'Method', 'Date', 'Amount (PKR)', 'Status'],
                data: _subscriptionPayments
                    .map((s) => [
                          s['plan'],
                          s['method'],
                          s['date'],
                          s['amount'].toString(),
                          s['status'],
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // Refunds
            if (_refunds.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Refunds'),
              pw.Table.fromTextArray(
                headers: [
                  'Package',
                  'Customer',
                  'Date',
                  'Amount (PKR)',
                  'Reason',
                  'Status'
                ],
                data: _refunds
                    .map((r) => [
                          r['package'],
                          r['customer'],
                          r['date'],
                          r['amount'].toString(),
                          r['reason'],
                          r['status'],
                        ])
                    .toList(),
              ),
            ],
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'payment-history-$dateStr.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment History',
                              style: AppTextStyles.headingMedium),
                          Text(
                            'Track all your financial transactions',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _downloadReport,
                        icon: const Icon(Icons.download_outlined,
                            color: Colors.white),
                        label: const Text('Download Report',
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
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Summary Cards ──────────────────────────────
                                GridView.count(
                                  crossAxisCount: MediaQuery.of(context)
                                              .size
                                              .width >=
                                          1400
                                      ? 5
                                      : MediaQuery.of(context).size.width >= 900
                                          ? 4
                                          : 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.4,
                                  children: [
                                    _buildSummaryCard(
                                      'Total Earned',
                                      'PKR ${_totalEarned.toStringAsFixed(0)}',
                                      Icons.trending_up,
                                      Colors.green,
                                    ),
                                    _buildSummaryCard(
                                      'Platform Commission',
                                      'PKR ${_totalCommission.toStringAsFixed(0)}',
                                      Icons.percent_outlined,
                                      Colors.red,
                                    ),
                                    _buildSummaryCard(
                                      'Paid to Subscriptions',
                                      'PKR ${_totalSubscriptions.toStringAsFixed(0)}',
                                      Icons.card_membership_outlined,
                                      Colors.blue,
                                    ),
                                    _buildSummaryCard(
                                      'Refunded Amount',
                                      'PKR ${_totalRefunded.toStringAsFixed(0)}',
                                      Icons.undo_outlined,
                                      Colors.orange,
                                    ),
                                    _buildSummaryCard(
                                      'Net Amount',
                                      'PKR ${_netAmount.toStringAsFixed(0)}',
                                      Icons.account_balance_wallet_outlined,
                                      _netAmount >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                // ── Tabs ───────────────────────────────────────
                                Container(
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
                                      TabBar(
                                        controller: _tabController,
                                        labelColor: AppColors.primary,
                                        unselectedLabelColor:
                                            AppColors.textTertiary,
                                        indicatorColor: AppColors.primary,
                                        indicatorSize: TabBarIndicatorSize.tab,
                                        labelStyle: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                        tabs: const [
                                          Tab(text: 'Package Sales'),
                                          Tab(text: 'Subscriptions'),
                                          Tab(text: 'Refunds'),
                                        ],
                                      ),
                                      SizedBox(
                                        height: 500,
                                        child: TabBarView(
                                          controller: _tabController,
                                          children: [
                                            _buildPackageSalesTab(),
                                            _buildSubscriptionsTab(),
                                            _buildRefundsTab(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7D848D),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color == Colors.red ? Colors.red : const Color(0xFF1B1E28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSalesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _packageSales.length,
      itemBuilder: (context, index) {
        final sale = _packageSales[index];
        final bool isPending = sale['status'] == 'Pending';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sell_outlined,
                    color: Colors.green, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale['package'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1B1E28),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sale['customer']} • ${sale['date']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7D848D),
                      ),
                    ),
                    if ((sale['bookingId'] ?? 'N/A') != 'N/A') ...[
                      const SizedBox(height: 2),
                      Text(
                        'Booking #${sale['bookingId']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFAAAAAA),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${sale['net']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sale['status'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPending ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _subscriptionPayments.length,
      itemBuilder: (context, index) {
        final sub = _subscriptionPayments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_membership_outlined,
                    color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub['plan'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1B1E28),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sub['method']} • ${sub['date']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7D848D),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${sub['amount']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Paid',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRefundsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _refunds.length,
      itemBuilder: (context, index) {
        final refund = _refunds[index];
        final bool isPending = refund['status'] == 'Pending';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.undo_outlined,
                    color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refund['package'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1B1E28),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${refund['customer']} • ${refund['date']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7D848D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      refund['reason'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7D848D),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${refund['amount']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      refund['status'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPending ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
