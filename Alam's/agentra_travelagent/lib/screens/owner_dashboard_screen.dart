import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../services/owner_service.dart';
import '../widgets/owner_side_navigation.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  List<dynamic> _agents = [];
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;

  List<Map<String, dynamic>> _getMonthlyStats() {
    return [
      {
        'label': 'Total Users',
        'value': _dashboardData['totalUsers'] ?? 0,
        'color': Colors.indigo,
      },
      {
        'label': 'Total Agents',
        'value': _dashboardData['totalAgents'] ?? 0,
        'color': AppColors.primary,
      },
      {
        'label': 'Total Bookings',
        'value': _dashboardData['totalBookings'] ?? 0,
        'color': Colors.blue,
      },
      {
        'label': 'Pending Refunds',
        'value': _dashboardData['pendingRefunds'] ?? 0,
        'color': Colors.orange,
      },
      {
        'label': 'Total Complaints',
        'value': _dashboardData['totalComplaints'] ?? 0,
        'color': Colors.red,
      },
    ];
  }

  List<Map<String, dynamic>> _getCommissionStats() {
    Map<String, dynamic> summary = {};
    try {
      final commAnalytics = _dashboardData['commissionAnalytics'];
      if (commAnalytics is Map<String, dynamic>) {
        final s = commAnalytics['summary'];
        if (s is Map<String, dynamic>) {
          summary = s;
        }
      }
    } catch (_) {}
    return [
      {
        'label': 'Commission Earned',
        'value':
            'PKR ${((summary['totalCommissionRevenue'] ?? 0) as num).toStringAsFixed(0)}',
        'color': Colors.indigo,
      },
      {
        'label': 'Today\'s Commission',
        'value':
            'PKR ${((summary['todayCommissionRevenue'] ?? 0) as num).toStringAsFixed(0)}',
        'color': Colors.green,
      },
      {
        'label': 'Successful Bookings',
        'value': summary['totalSuccessfulBookings'] ?? 0,
        'color': Colors.blue,
      },
      {
        'label': 'Refunded Commission',
        'value':
            'PKR ${((summary['totalRefundedCommission'] ?? 0) as num).toStringAsFixed(0)}',
        'color': Colors.orange,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final agents = await OwnerService.getAllAgents();
    final dashboard = await OwnerService.getOwnerDashboard();
    if (mounted) {
      setState(() {
        _agents = agents;
        _dashboardData = dashboard;
        _isLoading = false;
      });
    }
  }

  // ── Generate a plain-text report for an agent and show it in a dialog ──
  void _showAgentDetails(Map<String, dynamic> agent) {
    showDialog(
      context: context,
      builder: (context) => _AgentDetailDialog(agent: agent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          OwnerSideNavigation(
            selectedIndex: 0,
            onItemSelected: (_) {},
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B1E28),
                            ),
                          ),
                          Text(
                            'General platform performance and analytics',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7D848D),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadData,
                        tooltip: 'Refresh',
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
                                // ── Stats Grid ─────────────────────────
                                const Text(
                                  'Platform Statistics',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1B1E28),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final w = constraints.maxWidth;
                                    final statCols = w > 700 ? 3 : w > 400 ? 2 : 1;
                                    return GridView.count(
                                      crossAxisCount: statCols,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio:
                                          w > 700 ? 1.8 : 2.2,
                                      children: _getMonthlyStats()
                                          .map<Widget>((s) => _buildStatCard(s))
                                          .toList(),
                                    );
                                  },
                                ),
                                const SizedBox(height: 32),


                                // ── Registered Travel Agents ───────────
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Registered Travel Agents',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1B1E28),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_agents.length} Total',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _agents.isEmpty
                                    ? const Center(
                                        child: Column(
                                          children: [
                                            SizedBox(height: 40),
                                            Icon(Icons.people_outlined,
                                                size: 64,
                                                color: Colors.black12),
                                            SizedBox(height: 16),
                                            Text('No agents found'),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        children: _agents
                                            .map<Widget>((a) => _buildAgentRow(a))
                                            .toList(),
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

  Widget _buildStatCard(Map<String, dynamic> stat) {
    final color = stat['color'] as Color;
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stat['label'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7D848D),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Text(
            '${stat['value']}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentRow(Map<String, dynamic> agent) {
    final status = agent['status'] ?? 'UNKNOWN';

    Color statusColor = Colors.grey;
    String statusLabel = status;
    if (status == 'APPROVED') {
      statusColor = Colors.green;
      statusLabel = 'Active';
    }
    if (status == 'BLOCKED') {
      statusColor = Colors.red;
      statusLabel = 'Blocked';
    }
    if (status == 'PENDING_APPROVAL') {
      statusColor = Colors.orange;
      statusLabel = 'Pending';
    }
    if (status == 'REJECTED') {
      statusColor = Colors.grey;
      statusLabel = 'Rejected';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: (agent['profileImage'] != null &&
                    agent['profileImage'].toString().isNotEmpty)
                ? NetworkImage(ApiConfig.getImageUrl(agent['profileImage']))
                : null,
            onBackgroundImageError: (agent['profileImage'] != null &&
                    agent['profileImage'].toString().isNotEmpty)
                ? (_, __) {}
                : null,
            child: (agent['profileImage'] == null ||
                    agent['profileImage'].toString().isEmpty)
                ? Text(
                    (agent['fullName'] ?? agent['businessName'] ?? 'A')[0]
                        .toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent['businessName'] ?? agent['fullName'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1B1E28),
                  ),
                ),
                Text(
                  agent['email'] ?? '',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF7D848D)),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // View details button
          TextButton(
            onPressed: () => _showAgentDetails(agent),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'View Detail',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Agent Detail Dialog with PDF report download ──────────────────────────────
class _AgentDetailDialog extends StatelessWidget {
  final Map<String, dynamic> agent;
  const _AgentDetailDialog({required this.agent});

  @override
  Widget build(BuildContext context) {
    final revenue = (agent['revenue'] ?? 0) as num;
    final bookings =
        (agent['bookingCount'] ?? agent['totalBookings'] ?? 0) as num;
    final packages = (agent['totalPackages'] ?? 0) as num;
    final rating = (agent['averageRating'] ?? 0) as num;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Agent Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1E28),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 8),

            // Agent name + email
            Text(
              agent['businessName'] ?? agent['fullName'] ?? 'Unknown',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B1E28),
              ),
            ),
            Text(
              agent['email'] ?? '',
              style: const TextStyle(fontSize: 13, color: Color(0xFF7D848D)),
            ),
            const SizedBox(height: 20),

            // Revenue card
            _infoCard(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: Colors.green,
              label: 'Total Revenue',
              value: 'PKR ${revenue.toStringAsFixed(0)}',
              valueColor: Colors.green,
            ),
            const SizedBox(height: 12),

            // Performance grid
            Row(
              children: [
                Expanded(
                  child: _infoCard(
                    icon: Icons.calendar_today_outlined,
                    iconColor: Colors.blue,
                    label: 'Total Bookings',
                    value: '$bookings',
                    valueColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoCard(
                    icon: Icons.card_travel_outlined,
                    iconColor: AppColors.primary,
                    label: 'Total Packages',
                    value: '$packages',
                    valueColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoCard(
                    icon: Icons.star_outline,
                    iconColor: Colors.amber,
                    label: 'Avg Rating',
                    value: '${rating.toStringAsFixed(1)}/5',
                    valueColor: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Download Report button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadReport(context),
                icon: const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.white),
                label: const Text(
                  'Download PDF Report',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7D848D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReport(BuildContext context) async {
    final revenue = (agent['revenue'] ?? 0) as num;
    final bookings =
        (agent['bookingCount'] ?? agent['totalBookings'] ?? 0) as num;
    final packages = (agent['totalPackages'] ?? 0) as num;
    final rating = (agent['averageRating'] ?? 0) as num;
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Build the PDF document
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('007AFF'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'AGENTRA',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Agent Performance Report',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated: $dateStr',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // ── Agent Info ───────────────────────────────────────────
              pw.Text(
                'Agent Information',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('1B1E28'),
                ),
              ),
              pw.Divider(color: PdfColor.fromHex('EEEEEE')),
              pw.SizedBox(height: 8),
              _pdfRow('Full Name', agent['fullName'] ?? 'N/A'),
              _pdfRow('Business Name', agent['businessName'] ?? 'N/A'),
              _pdfRow('Email', agent['email'] ?? 'N/A'),
              _pdfRow('Phone', agent['phone'] ?? 'N/A'),
              _pdfRow('Location', agent['location'] ?? 'N/A'),
              _pdfRow('Status', agent['status'] ?? 'N/A'),
              _pdfRow('Joined',
                  agent['createdAt']?.toString().split('T')[0] ?? 'N/A'),
              pw.SizedBox(height: 24),

              // ── Performance Summary ──────────────────────────────────
              pw.Text(
                'Performance Summary',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('1B1E28'),
                ),
              ),
              pw.Divider(color: PdfColor.fromHex('EEEEEE')),
              pw.SizedBox(height: 12),

              // Stats grid (2 columns)
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _pdfStatBox(
                      'Total Revenue',
                      'PKR ${revenue.toStringAsFixed(0)}',
                      PdfColor.fromHex('22C55E'),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: _pdfStatBox(
                      'Total Bookings',
                      '$bookings',
                      PdfColor.fromHex('007AFF'),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _pdfStatBox(
                      'Total Packages',
                      '$packages',
                      PdfColor.fromHex('8B5CF6'),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: _pdfStatBox(
                      'Average Rating',
                      '${rating.toStringAsFixed(1)} / 5.0',
                      PdfColor.fromHex('F59E0B'),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // ── Footer ───────────────────────────────────────────────
              pw.Divider(color: PdfColor.fromHex('EEEEEE')),
              pw.SizedBox(height: 8),
              pw.Text(
                'This report was generated automatically by Agentra Owner Portal.',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Use the printing package to show a print/save dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Agentra_Report_${(agent['businessName'] ?? agent['fullName'] ?? 'Agent').toString().replaceAll(' ', '_')}_$dateStr',
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('7D848D'),
              ),
            ),
          ),
          pw.Text(
            ':  $value',
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.08),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: PdfColor(color.red, color.green, color.blue, 0.3),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
