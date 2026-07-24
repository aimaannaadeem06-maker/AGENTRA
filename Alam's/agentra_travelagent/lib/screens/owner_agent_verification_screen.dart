import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/owner_service.dart';
import '../widgets/owner_side_navigation.dart';

class OwnerAgentVerificationScreen extends StatefulWidget {
  const OwnerAgentVerificationScreen({Key? key}) : super(key: key);

  @override
  State<OwnerAgentVerificationScreen> createState() =>
      _OwnerAgentVerificationScreenState();
}

class _OwnerAgentVerificationScreenState
    extends State<OwnerAgentVerificationScreen> {
  List<dynamic> _agents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    final agents = await OwnerService.getUnverifiedAgents();
    if (mounted) {
      setState(() {
        _agents = agents;
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyAgent(String id, String name) async {
    final success = await OwnerService.verifyAgent(id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name has been verified!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadAgents();
    }
  }

  Future<void> _rejectAgent(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Agent',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Are you sure you want to reject $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Reject',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await OwnerService.rejectAgent(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name has been rejected'),
            backgroundColor: Colors.red,
          ),
        );
        _loadAgents();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          OwnerSideNavigation(
            selectedIndex: 2,
            onItemSelected: (_) {},
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
                      bottom: BorderSide(
                          color: Color(0xFFEEEEEE), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agent Verification',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B1E28),
                            ),
                          ),
                          Text(
                            'Review and approve pending travel agents',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7D848D),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_agents.length} Pending',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadAgents,
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
                      : _agents.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_outlined,
                                      size: 80, color: Colors.black12),
                                  SizedBox(height: 16),
                                  Text(
                                    'No pending agents',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFF7D848D),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(32),
                              itemCount: _agents.length,
                              itemBuilder: (context, index) {
                                final agent = _agents[index];
                                return Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.04),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: AppColors
                                                .primary
                                                .withOpacity(0.1),
                                            child: Text(
                                              (agent['businessName'] ??
                                                      'A')[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight:
                                                    FontWeight.w800,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(
                                                  agent['businessName'] ??
                                                      'Unknown',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color:
                                                        Color(0xFF1B1E28),
                                                  ),
                                                ),
                                                Text(
                                                  agent['fullName'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        Color(0xFF7D848D),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      20),
                                            ),
                                            child: const Text(
                                              'Pending',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                              child: _buildDetail(
                                                  'Email',
                                                  agent['email'] ??
                                                      'N/A')),
                                          Expanded(
                                              child: _buildDetail(
                                                  'Phone',
                                                  agent['phone'] ??
                                                      'N/A')),
                                          Expanded(
                                              child: _buildDetail('CNIC',
                                                  agent['cnic'] ?? 'N/A')),
                                          Expanded(
                                            child: _buildDetail(
                                              'License',
                                              agent['licenseNumber'] !=
                                                          null &&
                                                      agent['licenseNumber']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? agent['licenseNumber']
                                                  : 'Not provided',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _rejectAgent(
                                                      agent['_id'],
                                                      agent[
                                                          'businessName']),
                                              icon: const Icon(
                                                  Icons.close,
                                                  color: Colors.red,
                                                  size: 18),
                                              label: const Text('Reject'),
                                              style:
                                                  OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(
                                                    color: Colors.red),
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    vertical: 14),
                                                shape:
                                                    RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _verifyAgent(
                                                      agent['_id'],
                                                      agent[
                                                          'businessName']),
                                              icon: const Icon(Icons.check,
                                                  color: Colors.white,
                                                  size: 18),
                                              label:
                                                  const Text('Approve'),
                                              style:
                                                  ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.green,
                                                foregroundColor:
                                                    Colors.white,
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    vertical: 14),
                                                shape:
                                                    RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7D848D),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1B1E28),
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
