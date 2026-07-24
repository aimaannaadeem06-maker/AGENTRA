import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../models/complaint.dart';
import '../../services/complaint_service.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  int _currentIndex = 0;
  List<Complaint> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await ComplaintService.getMyComplaints();
    if (mounted) setState(() { _complaints = list; _isLoading = false; });
  }

  // ── Status helpers ──────────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':    return Colors.green;
      case 'IN_PROGRESS': return Colors.orange;
      default:            return Colors.red;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':    return Icons.check_circle_rounded;
      case 'IN_PROGRESS': return Icons.hourglass_top_rounded;
      default:            return Icons.report_problem_outlined;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':    return 'Resolved';
      case 'IN_PROGRESS': return 'In Progress';
      default:            return 'Open';
    }
  }

  // ── Detail dialog ───────────────────────────────────────────────────────────
  void _showDetail(Complaint c) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('Complaint Details',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B1E28)),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 40),
                ]),
                const Divider(),
                const SizedBox(height: 12),

                // Status badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _statusColor(c.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_statusIcon(c.status),
                          color: _statusColor(c.status), size: 16),
                      const SizedBox(width: 6),
                      Text(_statusLabel(c.status),
                          style: TextStyle(
                              color: _statusColor(c.status),
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                _row('Subject', c.subject),
                if (c.agentName != null) _row('Agent', c.agentName!),
                _row('Date',
                    '${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}'),
                const SizedBox(height: 12),

                // Description
                _sectionLabel('Your Complaint'),
                _box(c.description),

                // Timeline
                const SizedBox(height: 16),
                _sectionLabel('Progress Timeline'),
                _timelineStep(
                  icon: Icons.send_outlined,
                  color: AppColors.primary,
                  title: 'Complaint Submitted',
                  subtitle: 'Received by admin',
                  done: true,
                ),
                _timelineStep(
                  icon: Icons.forward_to_inbox_outlined,
                  color: Colors.orange,
                  title: 'Forwarded to Agent',
                  subtitle: c.forwardedToAgent || c.status == 'IN_PROGRESS'
                      ? 'Admin forwarded your complaint to the agent'
                      : (c.status == 'RESOLVED'
                          ? 'Admin reviewed your complaint'
                          : 'Pending admin review'),
                  done: c.forwardedToAgent ||
                      c.status == 'IN_PROGRESS' ||
                      c.status == 'RESOLVED',
                ),
                _timelineStep(
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  title: 'Resolved',
                  subtitle: c.status == 'RESOLVED'
                      ? 'Complaint has been resolved'
                      : 'Awaiting resolution',
                  done: c.status == 'RESOLVED',
                  isLast: true,
                ),

                // Admin message
                if ((c.adminResponse ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('Admin Message'),
                  _box(c.adminResponse!, color: Colors.blue.shade50,
                      borderColor: Colors.blue.shade200),
                ],

                // Agent response
                if ((c.agentResponse ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionLabel('Agent Response'),
                  _box(c.agentResponse!, color: Colors.green.shade50,
                      borderColor: Colors.green.shade200),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7D848D),
                  fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1B1E28))),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF7D848D),
              fontSize: 13)),
    );
  }

  Widget _box(String text,
      {Color? color, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor ?? const Color(0xFFEEEEEE)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF4A4A4A), height: 1.6)),
    );
  }

  Widget _timelineStep({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool done,
    bool isLast = false,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: done ? color : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: done ? Colors.white : Colors.grey, size: 16),
        ),
        if (!isLast)
          Container(
              width: 2,
              height: 32,
              color: done ? color.withOpacity(0.3) : Colors.grey.shade200),
      ]),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: done ? const Color(0xFF1B1E28) : Colors.grey)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: done ? const Color(0xFF7D848D) : Colors.grey.shade400)),
          ]),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final open       = _complaints.where((c) => c.status == 'OPEN').length;
    final inProgress = _complaints.where((c) => c.status == 'IN_PROGRESS').length;
    final resolved   = _complaints.where((c) => c.status == 'RESOLVED').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Complaints', style: AppTextStyles.headingSmall),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/file-complaint');
              if (result == true) _load();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  // Status chips
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: Colors.white,
                    child: Row(children: [
                      _chip('$open Open', Colors.red),
                      const SizedBox(width: 8),
                      _chip('$inProgress In Progress', Colors.orange),
                      const SizedBox(width: 8),
                      _chip('$resolved Resolved', Colors.green),
                    ]),
                  ),
                  Expanded(
                    child: _complaints.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inbox_outlined,
                                    size: 64, color: Colors.black12),
                                const SizedBox(height: 16),
                                const Text('No complaints yet'),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () async {
                                    final r = await Navigator.pushNamed(
                                        context, '/file-complaint');
                                    if (r == true) _load();
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary),
                                  child: const Text('File a Complaint',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _complaints.length,
                            itemBuilder: (context, i) {
                              final c = _complaints[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _statusColor(c.status)
                                          .withOpacity(0.2)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2))
                                  ],
                                ),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _statusColor(c.status)
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(_statusIcon(c.status),
                                        color: _statusColor(c.status),
                                        size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(_statusLabel(c.status),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      _statusColor(c.status))),
                                          Text(c.subject,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1B1E28)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          if (c.agentName != null)
                                            Text('Agent: ${c.agentName}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF7D848D))),
                                          Text(
                                              '${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF7D848D))),
                                        ]),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _showDetail(c),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    child: const Text('View',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12)),
                                  ),
                                ]),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
          switch (index) {
            case 0: Navigator.pushReplacementNamed(context, '/home'); break;
            case 1: Navigator.pushReplacementNamed(context, '/bookings'); break;
            case 2: Navigator.pushReplacementNamed(context, '/chat'); break;
            case 3: Navigator.pushReplacementNamed(context, '/search'); break;
            case 4: Navigator.pushReplacementNamed(context, '/profile'); break;
          }
        },
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
