import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../models/package.dart';
import '../services/package_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

/// Date range options for the performance filter.
enum _DateRange { today, thisWeek, thisMonth, allTime }

class PackagePerformanceScreen extends StatefulWidget {
  const PackagePerformanceScreen({Key? key}) : super(key: key);

  @override
  State<PackagePerformanceScreen> createState() =>
      _PackagePerformanceScreenState();
}

class _PackagePerformanceScreenState extends State<PackagePerformanceScreen> {
  int _selectedNavIndex = 4;
  List<Package> _packages = [];
  int _totalBookings = 0;
  bool _isLoading = true;

  // Selected date range filter
  _DateRange _selectedRange = _DateRange.allTime;

  // Performance data per package: packageId → metrics map
  final Map<String, Map<String, dynamic>> _performanceData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Date range helpers ────────────────────────────────────────────────────

  /// Returns [startDate, endDate] ISO strings for the selected range,
  /// or [null, null] for "All Time".
  List<String?> _getDateRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case _DateRange.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return [start.toIso8601String(), end.toIso8601String()];
      case _DateRange.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final startDay = DateTime(start.year, start.month, start.day);
        return [startDay.toIso8601String(), now.toIso8601String()];
      case _DateRange.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return [start.toIso8601String(), now.toIso8601String()];
      case _DateRange.allTime:
        return [null, null];
    }
  }

  String get _rangeLabel {
    switch (_selectedRange) {
      case _DateRange.today:
        return 'Today';
      case _DateRange.thisWeek:
        return 'This Week';
      case _DateRange.thisMonth:
        return 'This Month';
      case _DateRange.allTime:
        return 'All Time';
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load agent's packages
      final packages = await PackageService.getAgentPackages();

      // Build analytics URL with optional date range params
      final dateRange = _getDateRange();
      String analyticsUrl = ApiConfig.AGENT_ANALYTICS;
      if (dateRange[0] != null && dateRange[1] != null) {
        analyticsUrl +=
            '?startDate=${Uri.encodeComponent(dateRange[0]!)}&endDate=${Uri.encodeComponent(dateRange[1]!)}';
      }

      // Load real booking counts per package (also date-filtered via analytics)
      final bookingsResp = await http.get(
        Uri.parse(ApiConfig.AGENT_BOOKINGS),
        headers: {'x-auth-token': token},
      );

      final Map<String, int> bookingCountMap = {};
      final Map<String, double> revenueMap = {};
      int totalBookingsCount = 0;

      if (bookingsResp.statusCode == 200) {
        final bData = jsonDecode(bookingsResp.body);
        final List<dynamic> bookings = bData['bookings'] ?? [];

        // Apply client-side date filter for bookings list
        final dateRange2 = _getDateRange();
        final DateTime? filterStart =
            dateRange2[0] != null ? DateTime.tryParse(dateRange2[0]!) : null;
        final DateTime? filterEnd =
            dateRange2[1] != null ? DateTime.tryParse(dateRange2[1]!) : null;

        for (final b in bookings) {
          // Date filter
          if (filterStart != null || filterEnd != null) {
            final createdAt = b['createdAt'] != null
                ? DateTime.tryParse(b['createdAt'].toString())
                : null;
            if (createdAt != null) {
              if (filterStart != null && createdAt.isBefore(filterStart)) {
                continue;
              }
              if (filterEnd != null && createdAt.isAfter(filterEnd)) continue;
            }
          }

          final pkgId = (b['packageId'] is Map)
              ? b['packageId']['_id']?.toString() ?? ''
              : b['packageId']?.toString() ?? '';
          if (pkgId.isEmpty) continue;
          bookingCountMap[pkgId] = (bookingCountMap[pkgId] ?? 0) + 1;
          revenueMap[pkgId] = (revenueMap[pkgId] ?? 0) +
              ((b['totalAmount'] ?? 0) as num).toDouble();
        }
        totalBookingsCount =
            bookingCountMap.values.fold(0, (sum, c) => sum + c);
      }

      // Load analytics (views/clicks/CVR) from backend
      final Map<String, Map<String, dynamic>> perfData = {};
      try {
        final analyticsResp = await http.get(
          Uri.parse(analyticsUrl),
          headers: {'x-auth-token': token},
        );
        if (analyticsResp.statusCode == 200) {
          final aData = jsonDecode(analyticsResp.body);
          final List<dynamic> pkgAnalytics = aData['packages'] ?? [];
          for (final item in pkgAnalytics) {
            final pkg = item['package'];
            final analytics = item['analytics'] ?? {};
            if (pkg == null) continue;
            final id = pkg['_id']?.toString() ?? '';
            if (id.isEmpty) continue;

            final int views = (analytics['views'] ?? 0) as int;
            final int clicks = (analytics['clicks'] ?? 0) as int;
            final int bookings =
                bookingCountMap[id] ?? (analytics['bookings'] ?? 0) as int;
            final double revenue =
                revenueMap[id] ?? (analytics['revenue'] ?? 0).toDouble();
            final double cvr = views > 0 ? (bookings / views) * 100 : 0.0;
            final double clickRate = views > 0 ? (clicks / views) * 100 : 0.0;

            perfData[id] = {
              'views': views,
              'clicks': clicks,
              'bookings': bookings,
              'revenue': revenue,
              'conversionRate': cvr.toStringAsFixed(1),
              'clickRate': clickRate.toStringAsFixed(1),
            };
          }
        }
      } catch (_) {}

      // For packages not yet in analytics, use booking data only
      for (final pkg in packages) {
        if (!perfData.containsKey(pkg.id)) {
          final bookings = bookingCountMap[pkg.id] ?? 0;
          final revenue = revenueMap[pkg.id] ?? 0.0;
          perfData[pkg.id] = {
            'views': 0,
            'clicks': 0,
            'bookings': bookings,
            'revenue': revenue,
            'conversionRate': '0.0',
            'clickRate': '0.0',
          };
        }
      }

      if (mounted) {
        setState(() {
          _packages = packages;
          _totalBookings = totalBookingsCount;
          _performanceData
            ..clear()
            ..addAll(perfData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Report generation ─────────────────────────────────────────────────────

  Future<void> _downloadReport() async {
    if (_packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No packages to generate report for')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF Report...')),
    );

    try {
      final doc = pw.Document();
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Package Performance Report',
                style:
                    pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text('Generated: $dateStr  |  Range: $_rangeLabel',
                style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
            pw.Header(level: 1, text: 'Summary'),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Total Bookings', _totalBookings.toString()],
                ['Total Revenue', 'PKR ${_totalRevenue.toStringAsFixed(0)}'],
                ['Total Views', _totalViews.toString()],
                ['Total Clicks', _totalClicks.toString()],
                [
                  'Avg Conversion Rate',
                  '${_avgConversionRate.toStringAsFixed(1)}%'
                ],
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Header(level: 1, text: 'Per-Package Breakdown'),
            pw.Table.fromTextArray(
              headers: [
                'Package',
                'Views',
                'Clicks',
                'Click Rate',
                'CVR',
                'Bookings',
                'Revenue (PKR)'
              ],
              data: _packages.map((p) {
                final perf = _performanceData[p.id] ?? {};
                return [
                  p.title,
                  '${perf['views'] ?? 0}',
                  '${perf['clicks'] ?? 0}',
                  '${perf['clickRate'] ?? '0.0'}%',
                  '${perf['conversionRate'] ?? '0.0'}%',
                  '${perf['bookings'] ?? 0}',
                  ((perf['revenue'] ?? 0.0) as double).toStringAsFixed(0),
                ];
              }).toList(),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'performance-report-$_rangeLabel-$dateStr.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
    }
  }

  // ── Summary stats ─────────────────────────────────────────────────────────

  int get _totalViews => _performanceData.values
      .fold(0, (sum, p) => sum + ((p['views'] ?? 0) as int));
  int get _totalClicks => _performanceData.values
      .fold(0, (sum, p) => sum + ((p['clicks'] ?? 0) as int));
  double get _totalRevenue => _performanceData.values
      .fold(0.0, (sum, p) => sum + ((p['revenue'] ?? 0.0) as double));
  double get _avgConversionRate => _performanceData.isEmpty
      ? 0
      : _performanceData.values
              .map((p) => double.tryParse(p['conversionRate'].toString()) ?? 0)
              .reduce((a, b) => a + b) /
          _performanceData.length;

  // Top package by bookings
  Package? get _topPackage {
    if (_packages.isEmpty) return null;
    return _packages.reduce((a, b) =>
        ((_performanceData[a.id]?['bookings'] ?? 0) as int) >
                ((_performanceData[b.id]?['bookings'] ?? 0) as int)
            ? a
            : b);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          SideNavigation(
            selectedIndex: _selectedNavIndex,
            onItemSelected: (index) {
              setState(() => _selectedNavIndex = index);
            },
          ),
          Expanded(
            child: Column(
              children: [
                // ── Top Bar ──────────────────────────────────────────
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
                          const Text('Package Performance',
                              style: AppTextStyles.headingMedium),
                          Text(
                            'Track how your packages are performing',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // ── Date Range Filter ──────────────────────
                          _buildDateRangeFilter(),
                          const SizedBox(width: 16),
                          // ── Generate Report ────────────────────────
                          ElevatedButton.icon(
                            onPressed: _downloadReport,
                            icon: const Icon(Icons.picture_as_pdf_outlined,
                                color: Colors.white),
                            label: const Text('Generate Report',
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
                    ],
                  ),
                ),
                // ── Content ──────────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Package
                              if (_topPackage != null) ...[
                                const Text(
                                  'Top Package',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1B1E28),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTopPackageCard(_topPackage!),
                                const SizedBox(height: 32),
                              ],

                              // Summary Stats
                              const Text(
                                'Summary Stats',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B1E28),
                                ),
                              ),
                              const SizedBox(height: 16),
                              GridView.count(
                                crossAxisCount: 4,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.5,
                                children: [
                                  _buildStatCard(
                                    'Total Bookings',
                                    _totalBookings.toString(),
                                    Icons.calendar_today_outlined,
                                    Colors.orange,
                                  ),
                                  _buildStatCard(
                                    'Total Revenue',
                                    'PKR ${_totalRevenue.toStringAsFixed(0)}',
                                    Icons.account_balance_wallet_outlined,
                                    Colors.green,
                                  ),
                                  _buildStatCard(
                                    'Total Views',
                                    _totalViews.toString(),
                                    Icons.visibility_outlined,
                                    Colors.blue,
                                  ),
                                  _buildStatCard(
                                    'Avg Conversion',
                                    '${_avgConversionRate.toStringAsFixed(1)}%',
                                    Icons.percent_outlined,
                                    Colors.purple,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // All Packages
                              const Text(
                                'All Packages',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B1E28),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _packages.isEmpty
                                  ? const Center(
                                      child: Column(
                                        children: [
                                          SizedBox(height: 40),
                                          Icon(Icons.inventory_2_outlined,
                                              size: 64, color: Colors.black12),
                                          SizedBox(height: 16),
                                          Text('No packages yet'),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      children: _packages
                                          .map((p) =>
                                              _buildPackagePerformanceRow(p))
                                          .toList(),
                                    ),
                            ],
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

  // ── Date range filter widget ──────────────────────────────────────────────

  Widget _buildDateRangeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _DateRange.values.map<Widget>((range) {
          final label = _rangeLabelFor(range);
          final isSelected = _selectedRange == range;
          return GestureDetector(
            onTap: () {
              if (_selectedRange != range) {
                setState(() => _selectedRange = range);
                _loadData();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF7D848D),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _rangeLabelFor(_DateRange range) {
    switch (range) {
      case _DateRange.today:
        return 'Today';
      case _DateRange.thisWeek:
        return 'Week';
      case _DateRange.thisMonth:
        return 'Month';
      case _DateRange.allTime:
        return 'All';
    }
  }

  // ── Card widgets ──────────────────────────────────────────────────────────

  Widget _buildTopPackageCard(Package package) {
    final perf = _performanceData[package.id] ?? {};
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              ApiConfig.getImageUrl(package.image),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 100,
                height: 100,
                color: Colors.white24,
                child: const Icon(Icons.image_outlined,
                    color: Colors.white54, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${package.duration} | PKR ${package.price}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildTopStat('${perf['views'] ?? 0}', 'Views'),
                    const SizedBox(width: 24),
                    _buildTopStat('${perf['clicks'] ?? 0}', 'Clicks'),
                    const SizedBox(width: 24),
                    _buildTopStat('${perf['bookings'] ?? 0}', 'Bookings'),
                    const SizedBox(width: 24),
                    _buildTopStat('${perf['conversionRate'] ?? '0.0'}%', 'CVR'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7D848D),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B1E28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagePerformanceRow(Package package) {
    final perf = _performanceData[package.id] ?? {};
    final int views = (perf['views'] ?? 0) as int;
    final int clicks = (perf['clicks'] ?? 0) as int;
    final int bookings = (perf['bookings'] ?? 0) as int;
    final double revenue = (perf['revenue'] ?? 0.0) as double;
    final String convRate = perf['conversionRate']?.toString() ?? '0.0';
    final String clickRate = perf['clickRate']?.toString() ?? '0.0';
    final double clickProgress =
        views > 0 ? (clicks / views).clamp(0.0, 1.0) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  ApiConfig.getImageUrl(package.image),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: const Color(0xFFF0F0F0),
                    child: const Icon(Icons.image_outlined,
                        color: Color(0xFFBBBBBB), size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1E28),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${package.duration} | PKR ${package.price}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7D848D),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip('$bookings Bookings', Colors.orange),
                  _buildChip('PKR ${revenue.toStringAsFixed(0)}', Colors.green),
                  _buildChip('$views Views', Colors.blue),
                  _buildChip('$convRate% CVR', Colors.purple),
                  _buildChip('$clickRate% CTR', Colors.teal),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Click Rate',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7D848D),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: clickProgress.clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$clickRate%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1E28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
