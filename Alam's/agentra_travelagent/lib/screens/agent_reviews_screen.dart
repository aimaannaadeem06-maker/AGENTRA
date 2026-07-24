import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/package.dart';
import '../widgets/side_navigation.dart';

class AgentReviewsScreen extends StatelessWidget {
  final Package package;
  const AgentReviewsScreen({Key? key, required this.package}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Dummy reviews for now — connect to backend later
    final List<Map<String, dynamic>> reviews = [
      {
        'name': 'Ahmed Khan',
        'rating': 5.0,
        'comment': 'Amazing trip! Everything was well organized.',
        'date': '12 Mar 2026',
      },
      {
        'name': 'Sara Ali',
        'rating': 4.0,
        'comment': 'Great experience, food could be better.',
        'date': '10 Mar 2026',
      },
      {
        'name': 'Usman Tariq',
        'rating': 4.5,
        'comment': 'Loved the scenery and the guide was very helpful.',
        'date': '8 Mar 2026',
      },
    ];

    final double avgRating = reviews.isEmpty
        ? 0
        : reviews.map((r) => r['rating'] as double).reduce((a, b) => a + b) /
            reviews.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          SideNavigation(
            selectedIndex: 0,
            onItemSelected: (_) {},
          ),
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reviews & Ratings',
                              style: AppTextStyles.headingMedium,
                            ),
                            Text(
                              package.title,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── Rating Summary ─────────────────────────
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
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
                                  // Big rating number
                                  Column(
                                    children: [
                                      Text(
                                        avgRating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 64,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1B1E28),
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(5, (i) {
                                          return Icon(
                                            i < avgRating.round()
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 20,
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${reviews.length} reviews',
                                        style: const TextStyle(
                                          color: Color(0xFF7D848D),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 48),
                                  // Rating bars
                                  Expanded(
                                    child: Column(
                                      children: List.generate(5, (i) {
                                        final star = 5 - i;
                                        final count = reviews
                                            .where((r) =>
                                                (r['rating'] as double).round() == star)
                                            .length;
                                        final percent = reviews.isEmpty
                                            ? 0.0
                                            : count / reviews.length;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              Text(
                                                '$star',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.star, color: Colors.amber, size: 14),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: percent,
                                                    backgroundColor: const Color(0xFFF0F0F0),
                                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                                                    minHeight: 8,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$count',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF7D848D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── Reviews List ───────────────────────────
                            const Text(
                              'All Reviews',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B1E28),
                              ),
                            ),
                            const SizedBox(height: 16),
                            reviews.isEmpty
                                ? const Center(
                                    child: Column(
                                      children: [
                                        SizedBox(height: 40),
                                        Icon(Icons.star_border,
                                            size: 64, color: Colors.black12),
                                        SizedBox(height: 16),
                                        Text(
                                          'No reviews yet',
                                          style: TextStyle(
                                            color: Color(0xFF7D848D),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: reviews
                                        .map((review) => _buildReviewCard(review))
                                        .toList(),
                                  ),
                          ],
                        ),
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

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final double rating = review['rating'] as double;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
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
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  (review['name'] as String)[0],
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name and stars
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1B1E28),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              // Date
              Text(
                review['date'],
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7D848D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            review['comment'],
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF4A4A4A),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
