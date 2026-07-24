import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/owner_service.dart';
import '../theme/app_theme.dart';
import '../widgets/owner_side_navigation.dart';

class OwnerFinancialScreen extends StatefulWidget {
  const OwnerFinancialScreen({Key? key}) : super(key: key);

  @override
  State<OwnerFinancialScreen> createState() => _OwnerFinancialScreenState();
}

class _OwnerFinancialScreenState extends State<OwnerFinancialScreen> {
  int _selectedNavIndex = 4;
  Map<String, dynamic> _dashboardData = {};
  Map<String, dynamic> _commissionAnalytics = {};
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String? _selectedAgentId;
  List<dynamic> _agents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  /// Safely converts any numeric-like value to num (handles int, double, String).
  num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  /// Safely casts a dynamic value to List<dynamic>.
  List<dynamic> _toList(dynamic value) {
    if (value == null) return <dynamic>[];
    if (value is List) return List<dynamic>.from(value);
    return <dynamic>[];
  }

  /// Safely casts a dynamic value to Map<String, dynamic>.
  Map<String, dynamic> _toMap(dynamic value) {
    if (value == null) return <String, dynamic>{};
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OwnerService.getOwnerDashboard();
      final analytics = await OwnerService.getOwnerCommissionAnalytics();
      final agents = await OwnerService.getAllAgents();
      final txns = await _loadAllTransactions();
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _commissionAnalytics = analytics;
          _agents = agents;
          _transactions = txns;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);
    try {
      final analytics = await OwnerService.getOwnerCommissionAnalytics(
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        agentId: _selectedAgentId,
      );
      if (mounted) {
        setState(() {
          _commissionAnalytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportReport() async {
    try {
      final path = await OwnerService.exportCommissionReport(
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        agentId: _selectedAgentId,
      );
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to export commission report')),
        );
        return;
      }
      final msg = path.startsWith('Downloaded')
          ? 'Commission report downloaded successfully!'
          : 'Report exported to $path';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed. Please try again.')),
      );
    }
  }

  Future<List<dynamic>> _loadAllTransactions() async {
    try {
      final token = await OwnerService.getToken();
      if (token == null) return <dynamic>[];

      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/payments/all'),
        headers: {'x-auth-token': token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _toList(data['transactions']);
      }
    } catch (e) {
      // ignore
    }
    return <dynamic>[];
  }


  List<dynamic> get _topAgents {
    return _toList(_dashboardData['topAgents']);
  }

  List<Map<String, dynamic>> get _commissionSummaryCards {
    final Map<String, dynamic> summary = _toMap(_commissionAnalytics['summary']);
    final total = _toNum(summary['totalCommissionRevenue']);
    final today = _toNum(summary['todayCommissionRevenue']);
    final monthly = _toNum(summary['monthlyCommissionRevenue']);
    final yearly = _toNum(summary['yearlyCommissionRevenue']);

    return <Map<String, dynamic>>[
      {
        'label': 'Total Commission Earned',
        'value': 'PKR ${total.toStringAsFixed(0)}',
        'icon': Icons.percent_outlined,
        'color': Colors.indigo,
      },
      {
        'label': "Today's Commission",
        'value': 'PKR ${today.toStringAsFixed(0)}',
        'icon': Icons.today_outlined,
        'color': Colors.green,
      },
      {
        'label': 'Monthly Commission',
        'value': 'PKR ${monthly.toStringAsFixed(0)}',
        'icon': Icons.calendar_month_outlined,
        'color': Colors.orange,
      },
      {
        'label': 'Yearly Commission',
        'value': 'PKR ${yearly.toStringAsFixed(0)}',
        'icon': Icons.emoji_events_outlined,
        'color': Colors.teal,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          OwnerSideNavigation(
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
                      bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Financial Overview',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B1E28),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Platform revenue and financial summary',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7D848D),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadData,
                            tooltip: 'Refresh',
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _exportReport,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Export Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
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
                              children: <Widget>[
                                // Summary Cards
                                const Text(
                                  'Commission Analytics',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1B1E28),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final crossAxisCount =
                                        constraints.maxWidth < 600
                                            ? 2
                                            : 4;
                                    return GridView.count(
                                      crossAxisCount: crossAxisCount,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 1.6,
                                      children: _commissionSummaryCards
                                          .map<Widget>(
                                            (card) => _buildSummaryCard(card),
                                          )
                                          .toList(),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Filters',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 12),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final fieldWidth = (constraints.maxWidth - 12 * 3).clamp(120.0, 220.0);
                                          final dropWidth = (constraints.maxWidth - 12 * 3).clamp(120.0, 240.0);
                                          return Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: <Widget>[
                                              SizedBox(
                                                width: fieldWidth,
                                                child: TextField(
                                                  controller: _startDateController,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Start Date',
                                                    border: OutlineInputBorder(),
                                                    hintText: 'YYYY-MM-DD',
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: fieldWidth,
                                                child: TextField(
                                                  controller: _endDateController,
                                                  decoration: const InputDecoration(
                                                    labelText: 'End Date',
                                                    border: OutlineInputBorder(),
                                                    hintText: 'YYYY-MM-DD',
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: dropWidth,
                                                child: DropdownButtonFormField<String>(
                                                  value: _selectedAgentId,
                                                  isExpanded: true,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Travel Agent',
                                                    border: OutlineInputBorder(),
                                                  ),
                                                  items: <DropdownMenuItem<String>>[
                                                    const DropdownMenuItem<String>(
                                                        value: null,
                                                        child: Text('All Agents')),
                                                    ..._agents
                                                        .map<DropdownMenuItem<String>>(
                                                          (agent) {
                                                            final agentMap = _toMap(agent);
                                                            final id = agentMap['_id']?.toString() ?? '';
                                                            final name = agentMap['businessName'] ??
                                                                agentMap['fullName'] ??
                                                                'Agent';
                                                            return DropdownMenuItem<String>(
                                                              value: id,
                                                              child: Text(
                                                                name.toString(),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            );
                                                          },
                                                        )
                                                        .toList(),
                                                  ],
                                                  onChanged: (value) => setState(
                                                      () => _selectedAgentId = value),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: _applyFilters,
                                                icon: const Icon(Icons.filter_list),
                                                label: const Text('Apply'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildAnalyticsSection(),
                                const SizedBox(height: 32),

                                // All Transactions
                                const Text(
                                  'Recent Commission Transactions',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1B1E28),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTransactionsSection(),
                                const SizedBox(height: 32),

                                // Top Agents by Bookings
                                if (_topAgents.isNotEmpty) ...<Widget>[
                                  const Text(
                                    'Top Travel Agents (by Bookings)',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1B1E28),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ..._topAgents
                                      .asMap()
                                      .entries
                                      .map<Widget>((entry) {
                                    final i = entry.key;
                                    final agent = _toMap(entry.value);
                                    final agentRevenue =
                                        _toNum(agent['totalRevenue']);
                                    final agentBookings =
                                        _toNum(agent['totalBookings']);
                                    final agentCommission = _toNum(
                                        agent['totalCommission'] ??
                                            (agentRevenue * 0.05));
                                    return Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.04),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          // Rank badge
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: i == 0
                                                  ? Colors.amber
                                                  : i == 1
                                                      ? Colors.grey.shade400
                                                      : i == 2
                                                          ? Colors
                                                              .brown.shade300
                                                          : AppColors.primary
                                                              .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '#${i + 1}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                  color: i < 3
                                                      ? Colors.white
                                                      : AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Agent info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  (agent['businessName'] ??
                                                          agent['fullName'] ??
                                                          'Unknown')
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    color: Color(0xFF1B1E28),
                                                  ),
                                                ),
                                                Text(
                                                  (agent['fullName'] ?? '')
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF7D848D),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Stats
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: <Widget>[
                                              Text(
                                                '$agentBookings Bookings',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              Text(
                                                'Revenue: PKR ${agentRevenue.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Text(
                                                'Commission: PKR ${agentCommission.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                  color: Colors.indigo,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
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

  Widget _buildTransactionsSection() {
    final recentTxns =
        _toList(_commissionAnalytics['recentTransactions']);
    if (recentTxns.isEmpty && _transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No transactions yet',
            style: TextStyle(
              color: Color(0xFF7D848D),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final displayList = recentTxns.isNotEmpty ? recentTxns : _transactions;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: displayList
            .map<Widget>((txn) => _buildCommissionTransactionRow(txn))
            .toList(),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    final summary = _toMap(_commissionAnalytics['summary']);
    final trend = _toList(_commissionAnalytics['trend']);
    final agentBreakdown = _toList(_commissionAnalytics['agentBreakdown']);
    final monthlyReport = _toList(_commissionAnalytics['monthlyReport']);

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Platform Metrics',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _metricChip('Successful Bookings',
                      '${summary['totalSuccessfulBookings'] ?? 0}'),
                  _metricChip(
                      'Booking Revenue',
                      'PKR ${_toNum(summary['totalBookingRevenue']).toStringAsFixed(0)}'),
                  _metricChip(
                      'Refunded Commission',
                      'PKR ${_toNum(summary['totalRefundedCommission']).toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _analyticsPanel(
                title: 'Commission Revenue Trend',
                child: Column(
                  children: trend.isEmpty
                      ? <Widget>[const Text('No trend data yet')]
                      : trend.map<Widget>((item) {
                          final m = _toMap(item);
                          return ListTile(
                            dense: true,
                            title: Text((m['month'] ?? 'N/A').toString()),
                            trailing: Text(
                                'PKR ${_toNum(m['commissionRevenue']).toStringAsFixed(0)}'),
                          );
                        }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _analyticsPanel(
                title: 'Agent-wise Commission Breakdown',
                child: Column(
                  children: agentBreakdown.isEmpty
                      ? <Widget>[const Text('No agent breakdown yet')]
                      : agentBreakdown.map<Widget>((item) {
                          final m = _toMap(item);
                          return ListTile(
                            dense: true,
                            title: Text(
                                (m['agentName'] ?? 'Unknown Agent').toString()),
                            subtitle: Text(
                                '${m['bookingCount'] ?? 0} bookings'),
                            trailing: Text(
                                'PKR ${_toNum(m['commissionRevenue']).toStringAsFixed(0)}'),
                          );
                        }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _analyticsPanel(
                title: 'Monthly Commission Report',
                child: Column(
                  children: monthlyReport.isEmpty
                      ? <Widget>[const Text('No monthly report yet')]
                      : monthlyReport.map<Widget>((item) {
                          final m = _toMap(item);
                          return ListTile(
                            dense: true,
                            title: Text((m['month'] ?? 'N/A').toString()),
                            subtitle: Text(
                                'Bookings: ${m['bookingCount'] ?? 0}'),
                            trailing: Text(
                                'PKR ${_toNum(m['commissionRevenue']).toStringAsFixed(0)}'),
                          );
                        }).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _analyticsPanel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF7D848D))),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildCommissionTransactionRow(dynamic txn) {
    final txnMap = _toMap(txn);
    final bookingId = txnMap['bookingId']?.toString() ?? 'N/A';
    final agentName = txnMap['agentName']?.toString() ?? 'Unknown Agent';
    final bookingAmount = _toNum(txnMap['bookingAmount']).toDouble();
    final commissionPercentage =
        _toNum(txnMap['commissionPercentage'] ?? 5).toDouble();
    final commissionAmount = _toNum(txnMap['commissionAmount']).toDouble();
    final agentEarnings = _toNum(txnMap['agentEarnings']).toDouble();
    final bookingStatus = txnMap['bookingStatus']?.toString() ?? 'CONFIRMED';
    final paymentStatus = txnMap['paymentStatus']?.toString() ?? 'PAID';
    String createdAt = 'N/A';
    try {
      if (txnMap['createdAt'] != null) {
        createdAt = DateTime.parse(txnMap['createdAt'].toString())
            .toString()
            .split(' ')[0];
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Booking #$bookingId',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              Text(
                'PKR ${commissionAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.indigo),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Agent: $agentName',
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF7D848D))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              Text('Amount: PKR ${bookingAmount.toStringAsFixed(0)}'),
              Text('Commission: ${commissionPercentage.toStringAsFixed(0)}%'),
              Text('Agent Earnings: PKR ${agentEarnings.toStringAsFixed(0)}'),
              Text('Booking Status: $bookingStatus'),
              Text('Payment Status: $paymentStatus'),
              Text('Created: $createdAt'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> card) {
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
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  card['label']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7D848D),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (card['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(card['icon'] as IconData,
                    color: card['color'] as Color, size: 18),
              ),
            ],
          ),
          Text(
            card['value']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B1E28),
            ),
          ),
        ],
      ),
    );
  }
}
