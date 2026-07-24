import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/api_config.dart';
import '../packages/package_detail_screen.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<dynamic> promotions = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchPromotions();
  }

  Future<void> fetchPromotions() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.PROMOTIONS),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(response.body);
      setState(() {
        promotions = data['promotedPackages'];
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '🌍 Top Travel Deals',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black), // ← change to black so it's visible
        ),
        iconTheme:
            const IconThemeData(color: Colors.black), // ← change to black too
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Error: $error'))
              : promotions.isEmpty
                  ? const Center(
                      child: Text(
                        'No promotions available right now.\nCheck back later! 🌴',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchPromotions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: promotions.length,
                        itemBuilder: (context, index) {
                          return _buildPackageCard(promotions[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildPackageCard(dynamic pkg) {
    final bool isFeatured = pkg['isFeatured'] == true;
    final bool hasDiscount = pkg['hasDiscount'] == true;
    final int discountPercentage = pkg['discountPercentage'] ?? 0;
    final int price = pkg['price'] ?? 0;
    final int discountedPrice = hasDiscount
        ? (price - (price * discountPercentage / 100)).round()
        : price;
    final agent = pkg['agentId'];
    final agentName = agent != null
        ? (agent['businessName'] ?? agent['fullName'] ?? 'Travel Agency')
        : 'Travel Agency';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banners
            Row(
              children: [
                if (isFeatured)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFf7971e), Color(0xFFffd200)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '⭐ FEATURED',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (isFeatured && hasDiscount) const SizedBox(width: 8),
                if (hasDiscount)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFff416c), Color(0xFFff4b2b)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🔥 $discountPercentage% OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              '✈️ ${pkg['title'] ?? 'Amazing Package'}',
              style: const TextStyle(
                color: Color(0xFFffd200),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            // Agent
            Text(
              '🏢 $agentName',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 6),

            // Location
            Text(
              '📍 ${pkg['location'] ?? 'Beautiful Destination'}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),

            const SizedBox(height: 8),

            // Price
            if (hasDiscount) ...[
              Row(
                children: [
                  Text(
                    'PKR $price',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      decoration: TextDecoration.lineThrough,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PKR $discountedPrice',
                    style: const TextStyle(
                      color: Color(0xFFffd200),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFff416c),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Save $discountPercentage%',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                '💰 PKR $price',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Details
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('⏱️ ${pkg['duration'] ?? 'N/A'}'),
                _chip(
                    '🍽️ ${pkg['meals'] ?? ((pkg['includes']?['meals'] == true) ? 'Included' : 'Not Included')}'),
                _chip(
                    '🚗 ${pkg['transport'] ?? ((pkg['includes']?['transport'] == true) ? 'Included' : 'Not Included')}'),
                _chip(
                    '🏨 ${pkg['accommodation'] ?? ((pkg['includes']?['accommodation'] == true) ? 'Included' : 'Not Included')}'),
                _chip('💺 ${pkg['availableSeats'] ?? 0} seats left'),
              ],
            ),

            const SizedBox(height: 16),

            // Book Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PackageDetailScreen(packageId: pkg['_id'] ?? ''),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  backgroundColor: const Color(0xFF667eea),
                ),
                child: const Text(
                  '🏖️ Book Now →',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
