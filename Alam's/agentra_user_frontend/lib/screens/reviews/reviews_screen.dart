import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/star_rating.dart';
import '../../services/review_service.dart';
import '../../config/api_config.dart';
import '../../models/review.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _packageId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _packageId == null) {
      _packageId = args;
      _loadReviews();
    } else if (_packageId == null) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    if (_packageId == null) return;
    setState(() => _isLoading = true);
    final reviews = await ReviewService.getPackageReviews(_packageId!);
    if (mounted) {
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reviews',
          style: AppTextStyles.headingSmall,
        ),
        actions: [
          if (_packageId != null)
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/write-review',
                  arguments: {
                    'packageId': _packageId,
                    'packageTitle': 'This Package',
                  },
                );
                if (result == true) _loadReviews();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Write'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_border,
                          size: 64, color: Colors.black26),
                      const SizedBox(height: 16),
                      const Text('No reviews yet',
                          style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 8),
                      if (_packageId != null)
                        ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/write-review',
                              arguments: {
                                'packageId': _packageId,
                                'packageTitle': 'This Package',
                              },
                            );
                            if (result == true) _loadReviews();
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          child: const Text('Be the first to review',
                              style: TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReviews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) {
                      return _buildReviewCard(_reviews[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final name = review.userName.isNotEmpty ? review.userName : 'Anonymous';
    final timeAgo = _formatDate(review.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage:
                    (review.userImage != null && review.userImage!.isNotEmpty)
                        ? NetworkImage(ApiConfig.getImageUrl(review.userImage!))
                        : null,
                child: (review.userImage == null || review.userImage!.isEmpty)
                    ? Text(
                        name[0].toUpperCase(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    StarRating(
                        rating: review.rating.toDouble(),
                        size: 14,
                        showRating: false),
                  ],
                ),
              ),
              Text(
                timeAgo,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return 'Just now';
    }
  }
}
