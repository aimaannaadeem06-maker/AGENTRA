import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/owner_side_navigation.dart';
import '../services/owner_service.dart';

class OwnerManageAccountsScreen extends StatefulWidget {
  const OwnerManageAccountsScreen({Key? key}) : super(key: key);
  @override
  State<OwnerManageAccountsScreen> createState() =>
      _OwnerManageAccountsScreenState();
}

class _OwnerManageAccountsScreenState extends State<OwnerManageAccountsScreen> {
  int _selectedNavIndex = 1;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<dynamic> _agents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getInitial(dynamic fullName, dynamic bizName) {
    final str1 = (fullName ?? '').toString().trim();
    if (str1.isNotEmpty) return str1[0].toUpperCase();
    final str2 = (bizName ?? '').toString().trim();
    if (str2.isNotEmpty) return str2[0].toUpperCase();
    return 'A';
  }

  Future<void> _loadAgents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final agents = await OwnerService.getAllAgents();
      if (mounted) {
        setState(() {
          _agents = agents;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Load agents error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredAgents {
    if (_searchQuery.isEmpty) return _agents;
    return _agents.where((a) {
      final name = (a['fullName'] ?? '').toString().toLowerCase();
      final biz = (a['businessName'] ?? '').toString().toLowerCase();
      final email = (a['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          biz.contains(_searchQuery) ||
          email.contains(_searchQuery);
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'BLOCKED':
        return Colors.red;
      case 'PENDING_APPROVAL':
        return Colors.orange;
      case 'REJECTED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Active';
      case 'BLOCKED':
        return 'Blocked';
      case 'PENDING_APPROVAL':
        return 'Pending';
      case 'REJECTED':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  // ── Send Notice Dialog ────────────────────────────────────────────────────
  void _showSendNoticeDialog(Map<String, dynamic> agent, String noticeType) {
    final name = agent['businessName'] ?? agent['fullName'] ?? 'Agent';
    final msgController = TextEditingController(
      text: noticeType == 'block'
          ? 'Your account has been flagged. If the issue is not resolved within 30 days, your account will be blocked.'
          : 'Your account has been flagged. If the issue is not resolved within 30 days, your account will be permanently deleted.',
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.warning_amber_outlined,
                        color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Send 30-Day Notice',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B1E28),
                          ),
                        ),
                        Text(
                          'To: $name',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF7D848D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  'This will notify the agent that their account is scheduled for '
                  '${noticeType == 'block' ? 'blocking' : 'deletion'} in 30 days '
                  'unless the issue is resolved.',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.orange, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Notice Message',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1B1E28))),
              const SizedBox(height: 8),
              TextField(
                controller: msgController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                ),
              ),
              const SizedBox(height: 20),
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
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final result = await OwnerService.sendNotice(
                          agent['_id'],
                          noticeType,
                          msgController.text.trim(),
                        );
                        if (mounted) {
                          if (result['success'] == true) {
                            _loadAgents();
                            _showNoticeSentConfirmation(name, noticeType);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ??
                                    'Failed to send notice'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.send_outlined,
                          color: Colors.white, size: 18),
                      label: const Text('Send Notice',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
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

  void _showNoticeSentConfirmation(String name, String noticeType) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Notice Sent!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1E28))),
              const SizedBox(height: 8),
              Text(
                '$name has been notified. They have 30 days to resolve the issue before their account is ${noticeType == 'block' ? 'blocked' : 'deleted'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF7D848D), fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(_),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Okay',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Block Confirmation ────────────────────────────────────────────────────
  void _showBlockDialog(Map<String, dynamic> agent) {
    final name = agent['businessName'] ?? agent['fullName'] ?? 'Agent';
    final hasNotice = agent['noticeSentAt'] != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Block Account',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Block $name\'s account?'),
            const SizedBox(height: 8),
            if (!hasNotice)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Text(
                  '⚠️  No notice has been sent yet. It is recommended to send a 30-day notice first.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Once blocked, the agent will not be able to log in and will see a "Your account has been blocked" message.',
              style: TextStyle(fontSize: 13, color: Color(0xFF7D848D)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await OwnerService.blockAgent(agent['_id']);
              if (mounted) {
                if (success) {
                  _loadAgents();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name has been blocked'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to block agent'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.block, color: Colors.white, size: 16),
            label: const Text('Block', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Delete Confirmation ───────────────────────────────────────────────────
  void _showDeleteDialog(Map<String, dynamic> agent) {
    final name = agent['businessName'] ?? agent['fullName'] ?? 'Agent';
    final hasNotice = agent['noticeSentAt'] != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Delete Account',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Permanently delete $name\'s account?'),
            const SizedBox(height: 8),
            if (!hasNotice)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Text(
                  '⚠️  No notice has been sent yet. It is recommended to send a 30-day notice first.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All agent data will be permanently removed from the platform.',
              style: TextStyle(
                  fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await OwnerService.deleteAgent(agent['_id']);
              if (mounted) {
                if (result['success'] == true) {
                  _loadAgents();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name has been deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(result['message'] ?? 'Failed to delete agent'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon:
                const Icon(Icons.delete_forever, color: Colors.white, size: 16),
            label: const Text('Delete Permanently',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                // ── Top Bar ──────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account Management',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B1E28))),
                          Text('Manage travel agent accounts',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF7D848D))),
                        ],
                      ),
                      Row(
                        children: [
                          _chip(
                              '${_agents.where((a) => a['status'] == 'APPROVED').length} Active',
                              Colors.green),
                          const SizedBox(width: 8),
                          _chip(
                              '${_agents.where((a) => a['status'] == 'BLOCKED').length} Blocked',
                              Colors.red),
                          const SizedBox(width: 8),
                          _chip(
                              '${_agents.where((a) => a['status'] == 'PENDING_APPROVAL').length} Pending',
                              Colors.orange),
                          const SizedBox(width: 12),
                          IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadAgents),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Search ───────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by name, business or email...',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF7D848D)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFEEEEEE))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFEEEEEE))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                // ── List ─────────────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredAgents.isEmpty
                          ? const Center(
                              child: Text('No agents found',
                                  style: TextStyle(
                                      color: Color(0xFF7D848D), fontSize: 16)))
                          : RefreshIndicator(
                              onRefresh: _loadAgents,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(32),
                                itemCount: _filteredAgents.length,
                                itemBuilder: (_, i) =>
                                    _buildAgentCard(_filteredAgents[i]),
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

  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final status = agent['status'] ?? 'UNKNOWN';
    final hasNotice = agent['noticeSentAt'] != null;
    final noticeType = agent['noticeType'];
    final noticeSentAt = agent['noticeSentAt'];

    // Calculate days remaining on notice
    int? daysLeft;
    if (hasNotice && noticeSentAt != null) {
      final sent = DateTime.tryParse(noticeSentAt.toString());
      if (sent != null) {
        final deadline = sent.add(const Duration(days: 30));
        daysLeft = deadline.difference(DateTime.now()).inDays;
        if (daysLeft < 0) daysLeft = 0;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Main row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    _getInitial(agent['fullName'], agent['businessName']),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18),
                  ),
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
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1B1E28)),
                      ),
                      Text(
                        agent['email'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF7D848D)),
                      ),
                      Text(
                        'Joined ${agent['createdAt']?.toString().split('T')[0] ?? 'N/A'}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF7D848D)),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(status)),
                  ),
                ),
                const SizedBox(width: 16),
                // ── Action buttons: Send Notice | Block | Delete ────
                _actionBtn(
                  icon: Icons.notifications_outlined,
                  label: 'Notice',
                  color: Colors.orange,
                  onTap: () => _showSendNoticeDialog(agent, 'block'),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.block,
                  label: status == 'BLOCKED' ? 'Unblock' : 'Block',
                  color: status == 'BLOCKED' ? Colors.green : Colors.red,
                  onTap: () {
                    if (status == 'BLOCKED') {
                      _unblockAgent(agent);
                    } else {
                      _showBlockDialog(agent);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.red.shade800,
                  onTap: () => _showDeleteDialog(agent),
                ),
              ],
            ),
          ),
          // ── Notice banner (shown when a notice is active) ──────────
          if (hasNotice && daysLeft != null && daysLeft >= 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_outlined,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '30-day ${noticeType ?? ''} notice sent • $daysLeft day${daysLeft == 1 ? '' : 's'} remaining',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _unblockAgent(Map<String, dynamic> agent) async {
    final name = agent['businessName'] ?? agent['fullName'] ?? 'Agent';
    final success = await OwnerService.unblockAgent(agent['_id']);
    if (mounted) {
      if (success) {
        _loadAgents();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name has been unblocked'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unblock agent'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
