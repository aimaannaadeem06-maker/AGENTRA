import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryForeground = Color(0xFFFFFFFF);
  
  // Background
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundGray = Color(0xFFF8F9FA);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  
  // Text
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  
  // Accents
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color star = Color(0xFFFBBF24);
  static const Color orange = Color(0xFFFF6B35);
  
  // Border
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
}

class AppTextStyles {
  static const String fontFamily = 'Inter';
  
  // Headings
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
  );
  
  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
  );
  
  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontFamily: fontFamily,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    fontFamily: fontFamily,
  );
  
  // Button
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryForeground,
    fontFamily: fontFamily,
  );
}

class AppDimensions {
  // Border Radius
  static const double radiusSm = 8.0;
  static const double radius = 12.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  
  // Padding
  static const double paddingSm = 8.0;
  static const double padding = 16.0;
  static const double paddingLg = 24.0;
  static const double paddingXl = 32.0;
  
  // Button Padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 12.0,
  );
  
  // Input Padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );
  
  // Card Padding
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
}
