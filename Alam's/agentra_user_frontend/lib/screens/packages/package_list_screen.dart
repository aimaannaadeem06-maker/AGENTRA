// File: lib/screens/packages/package_list_screen.dart
import 'package:flutter/material.dart';

class PackageListScreen extends StatelessWidget {
  const PackageListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Packages'),
      ),
      body: const Center(
        child: Text('Package List'),
      ),
    );
  }
}