import 'package:flutter/material.dart';

/// Legacy screen — redirects to the main dashboard.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Immediately replace with the real dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/dashboard-packages');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
