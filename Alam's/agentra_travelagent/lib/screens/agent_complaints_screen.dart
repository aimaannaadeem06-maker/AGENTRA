import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class AgentComplaintsScreen extends StatefulWidget {
  const AgentComplaintsScreen({Key? key}) : super(key: key);
  @override
  State<AgentComplaintsScreen> createState() => _AgentComplaintsScreenState();
}

class _AgentComplaintsScreenState extends State<AgentComplaintsScreen> {
  int _selectedNavIndex = 11;
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse(ApiConfig.AGENT_COMPLAINTS),
        headers: {'x-auth-token': token},
      );
      if (r.statusCode == 200 && mounted) {
        final raw = jsonDecode(r.body)['complaints'] as List? ?? [];
        setState(() {
          _complaints =
              raw.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showResolveDialog(Map<String, dynamic> complaint) {
    final responseCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Resolve Complaint',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1E28))),
              const SizedBox(height: 6),
              Text(complaint['subject'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF7D848D))),
              const SizedBox(height: 20),
              const Text('Your Response',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF7D848D))),
              const SizedBox(height: 8),
              TextField(
                controller: responseCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Explain how you resolved this issue...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFDDDDDD))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFDDDDDD))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF1B1E28))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (responseCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter a response')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      await _resolveComplaint(
                          complaint['_id'], responseCtrl.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Mark as Resolved',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resolveComplaint(String id, String response) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final r = await http.put(
        Uri.parse('${ApiConfig.BASE_URL}/complaints/$id/resolve'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({'agentResponse': response}),
      );
      if (mounted) {
        if (r.statusCode == 200) {
          await _load();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Complaint resolved. The user has been notified.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  jsonDecode(r.body)['message'] ?? 'Failed to resolve'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Network error'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> complaint) {
    final status     = complaint['status'] ?? 'OPEN';
    final isResolved = status == 'RESOLVED';
    final forwarded  = complaint['forwardedToAgent'] == true;
    final user       = complaint['userId'] is Map ? complaint['userId'] : {};
    final OwnerMsg   = complaint['OwnerResponse'] ?? complaint['ownerResponse'] ?? '';
    final agentResp  = complaint['agentResponse'] ?? '';
    final createdAt  = complaint['createdAt'] != null
        ? DateTime.tryParse(complaint['createdAt'])
        : null;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('Back',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
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
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 12),

                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_statusLabel(status),
                        style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 16),

                _row('From', user['fullName'] ?? 'Unknown'),
                _row('Email', user['email'] ?? 'N/A'),
                if (createdAt != null)
                  _row('Date',
                      '${createdAt.day}/${createdAt.month}/${createdAt.year}'),
                _row('Subject', complaint['subject'] ?? ''),
                const SizedBox(height: 12),

                _label('Description'),
                const SizedBox(height: 6),
                _box(complaint['description'] ?? ''),

                if (OwnerMsg.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _label('Owner Message'),
                  const SizedBox(height: 6),
                  _box(OwnerMsg,
                      bg: const Color(0xFFFFF8E1),
                      border: const Color(0xFFFFE082)),
                ],

                if (agentResp.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _label('Your Response'),
                  const SizedBox(height: 6),
                  _box(agentResp,
                      bg: Colors.green.shade50,
                      border: Colors.green.shade200),
                ],

                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(color: Color(0xFF1B1E28))),
                    ),
                  ),
                  if (!isResolved && forwarded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showResolveDialog(complaint);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Resolve',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'RESOLVED':    return Colors.green;
      case 'IN_PROGRESS': return Colors.orange;
      default:            return Colors.red;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'RESOLVED':    return 'Resolved';
      case 'IN_PROGRESS': return 'Action Required';
      default:            return 'Open';
    }
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF7D848D),
          fontSize: 13));

  Widget _box(String text, {Color? bg, Color? border}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg ?? const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border ?? const Color(0xFFEEEEEE)),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF4A4A4A), height: 1.6)),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7D848D),
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1B1E28))),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final open       = _complaints.where((c) => c['status'] == 'OPEN').length;
    final inProgress = _complaints.where((c) => c['status'] == 'IN_PROGRESS').length;
    final resolved   = _complaints.where((c) => c['status'] == 'RESOLVED').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          SideNavigation(
            selectedIndex: _selectedNavIndex,
            onItemSelected: (i) => setState(() => _selectedNavIndex = i),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        bottom:
                            BorderSide(color: AppColors.border, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Complaints',
                                style: AppTextStyles.headingMedium),
                            Text('Complaints forwarded to you by Owner',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textTertiary)),
                          ]),
                      Row(children: [
                        _chip('$open Open', Colors.red),
                        const SizedBox(width: 8),
                        _chip('$inProgress Action Required', Colors.orange),
                        const SizedBox(width: 8),
                        _chip('$resolved Resolved', Colors.green),
                        const SizedBox(width: 12),
                        TextButton(
                            onPressed: _load,
                            child: const Text('Refresh')),
                      ]),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _complaints.isEmpty
                          ? const Center(
                              child: Text('No complaints yet.',
                                  style: TextStyle(
                                      color: Color(0xFF7D848D),
                                      fontSize: 16)))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(32),
                                itemCount: _complaints.length,
                                itemBuilder: (_, i) =>
                                    _buildCard(_complaints[i]),
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

  Widget _buildCard(Map<String, dynamic> complaint) {
    final status     = complaint['status'] ?? 'OPEN';
    final isResolved = status == 'RESOLVED';
    final forwarded  = complaint['forwardedToAgent'] == true;
    final user       = complaint['userId'] is Map ? complaint['userId'] : {};
    final createdAt  = complaint['createdAt'] != null
        ? DateTime.tryParse(complaint['createdAt'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor(status).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: _statusColor(status),
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(_statusLabel(status),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(status))),
                    if (createdAt != null) ...[
                      const Spacer(),
                      Text(
                          '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7D848D))),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text('From: ${user['fullName'] ?? 'Unknown'}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF4A4A4A))),
                  const SizedBox(height: 2),
                  Text(complaint['subject'] ?? '',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1E28)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(complaint['description'] ?? '',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7D848D),
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
        ]),

        // Action required notice
        if (forwarded && !isResolved) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Text(
                'Owner has forwarded this complaint to you. Please resolve it.',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF57F17),
                    fontWeight: FontWeight.w600)),
          ),
        ],

        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(
            onPressed: () => _showDetail(complaint),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              side: const BorderSide(color: Color(0xFFDDDDDD)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View Details',
                style: TextStyle(color: Color(0xFF1B1E28))),
          ),
          if (forwarded && !isResolved) ...[
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _showResolveDialog(complaint),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Resolve',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      );
}
