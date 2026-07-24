import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/owner_side_navigation.dart';
import '../services/owner_service.dart';
import '../config/api_config.dart';

class OwnerComplaintsScreen extends StatefulWidget {
  const OwnerComplaintsScreen({Key? key}) : super(key: key);
  @override
  State<OwnerComplaintsScreen> createState() => _OwnerComplaintsScreenState();
}

class _OwnerComplaintsScreenState extends State<OwnerComplaintsScreen> {
  int _selectedNavIndex = 3;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<dynamic> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await OwnerService.getComplaints();
    if (mounted) setState(() { _complaints = data; _isLoading = false; });
  }

  List<dynamic> get _filtered {
    if (_searchQuery.isEmpty) return _complaints;
    return _complaints.where((c) {
      final user = c['userId'];
      final name = (user?['fullName'] ?? '').toString().toLowerCase();
      final subj = (c['subject'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || subj.contains(_searchQuery);
    }).toList();
  }

  Future<void> _forwardToAgent(String id, String message) async {
    try {
      final token = await OwnerService.getToken();
      if (token == null) return;
      final r = await http.put(
        Uri.parse('${ApiConfig.BASE_URL}/complaints/$id/forward'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({'OwnerMessage': message}),
      );
      if (mounted) {
        _load();
        final ok = r.statusCode == 200;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Complaint sent to agent.'
              : jsonDecode(r.body)['message'] ?? 'Failed'),
          backgroundColor: ok ? Colors.orange : Colors.red,
        ));
      }
    } catch (_) {}
  }

  void _showDetail(Map<String, dynamic> complaint) {
    final responseCtrl = TextEditingController(
        text: complaint['OwnerResponse'] ?? complaint['ownerResponse'] ?? '');
    final user      = complaint['userId'];
    final agent     = complaint['agentId'];
    final userName  = user?['fullName'] ?? 'Unknown';
    final userEmail = user?['email'] ?? 'N/A';
    final agentName = agent?['businessName'] ?? agent?['fullName'] ?? 'N/A';
    final dateStr   = complaint['createdAt'] != null
        ? DateTime.parse(complaint['createdAt']).toString().split(' ')[0]
        : 'N/A';
    final status    = complaint['status'] ?? 'OPEN';
    final forwarded = complaint['forwardedToAgent'] == true;
    final agentResp = complaint['agentResponse'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
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
                        horizontal: 16, vertical: 7),
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

                _row('From', userName),
                _row('Email', userEmail),
                _row('Agent', agentName),
                _row('Date', dateStr),
                _row('Subject', complaint['subject'] ?? ''),
                const SizedBox(height: 12),

                _label('Description'),
                const SizedBox(height: 6),
                _box(complaint['description'] ?? ''),

                if (agentResp.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _label('Agent Response'),
                  const SizedBox(height: 6),
                  _box(agentResp,
                      bg: Colors.green.shade50,
                      border: Colors.green.shade200),
                ],

                const SizedBox(height: 16),
                _label('Message to Agent'),
                const SizedBox(height: 6),
                TextField(
                  controller: responseCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write a message for the agent...',
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

                if (status != 'RESOLVED') ...[
                  if (agent != null && !forwarded) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _forwardToAgent(
                              complaint['_id'], responseCtrl.text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Send to Agent',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final ok = await OwnerService.resolveComplaint(
                            complaint['_id'], responseCtrl.text);
                        if (ok && mounted) {
                          Navigator.pop(ctx);
                          _load();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Complaint resolved.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Resolve Directly',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(color: Color(0xFF1B1E28))),
                  ),
                ),
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
      case 'IN_PROGRESS': return 'In Progress';
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
            width: 70,
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
          OwnerSideNavigation(
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
                        bottom: BorderSide(
                            color: Color(0xFFEEEEEE), width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Complaint Management',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B1E28))),
                          Text('Review, forward and resolve complaints',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7D848D))),
                        ],
                      ),
                      Row(children: [
                        _chip('$open Open', Colors.red),
                        const SizedBox(width: 8),
                        _chip('$inProgress In Progress', Colors.orange),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by user name or subject...',
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFEEEEEE))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFEEEEEE))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _filtered.isEmpty
                              ? const Center(
                                  child: Text('No complaints found.',
                                      style: TextStyle(
                                          color: Color(0xFF7D848D),
                                          fontSize: 16)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(32),
                                  itemCount: _filtered.length,
                                  itemBuilder: (_, i) =>
                                      _buildCard(_filtered[i]),
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

  Widget _buildCard(Map<String, dynamic> c) {
    final status    = c['status'] ?? 'OPEN';
    final forwarded = c['forwardedToAgent'] == true;
    final user      = c['userId'];
    final agent     = c['agentId'];
    final dateStr   = c['createdAt'] != null
        ? DateTime.parse(c['createdAt']).toString().split(' ')[0]
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: _statusColor(status), shape: BoxShape.circle),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(_statusLabel(status),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status))),
                  if (forwarded) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Sent to Agent',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF7D848D))),
                ]),
                const SizedBox(height: 4),
                Text('From: ${user?['fullName'] ?? 'Unknown'}',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF4A4A4A))),
                if (agent != null)
                  Text(
                      'Agent: ${agent['businessName'] ?? agent['fullName'] ?? 'N/A'}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF7D848D))),
                const SizedBox(height: 2),
                Text(c['subject'] ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B1E28)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () => _showDetail(c),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('View',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
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
