import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final int starCount;
  final double size;
  final bool showRating;
  final int? reviewCount;

  const StarRating({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.size = 16,
    this.showRating = true,
    this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(starCount, (index) {
          if (index < rating.floor()) {
            return Icon(
              Icons.star,
              color: AppColors.star,
              size: size,
            );
          } else if (index < rating) {
            return Icon(
              Icons.star_half,
              color: AppColors.star,
              size: size,
            );
          } else {
            return Icon(
              Icons.star_border,
              color: AppColors.star,
              size: size,
            );
          }
        }),
        if (showRating) ...[
          const SizedBox(width: 4),
          Text(
            reviewCount != null ? '$rating($reviewCount)' : rating.toString(),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: size * 0.75,
            ),
          ),
        ],
      ],
    );
  }
}
