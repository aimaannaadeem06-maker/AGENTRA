import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../models/package.dart';

/// Shown after user selects seats/date but BEFORE payment.
/// Receives the package + booking details as arguments.
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Arguments: Map with package, seats, travelDate, paymentMethod
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final Package? package = args?['package'] as Package?;
    final int seats = args?['seats'] as int? ?? 1;
    final String travelDate = args?['travelDate'] as String? ?? '';
    final String paymentMethod = args?['paymentMethod'] as String? ?? 'CARD';

    final double pricePerPerson = package?.price ?? 0;
    final double discountPct = package?.discountPercentage ?? 0;
    final bool hasDiscount = package?.hasDiscount == true && discountPct > 0;
    final double effectivePrice = hasDiscount
        ? pricePerPerson * (1 - discountPct / 100)
        : pricePerPerson;
    final double total = effectivePrice * seats;

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
          'Confirm Booking',
          style: AppTextStyles.headingSmall,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Package Details Card
                    _card(
                      title: 'Package Details',
                      children: [
                        _row('Package', package?.title ?? 'N/A'),
                        _row('Location', package?.location ?? 'N/A'),
                        _row('Duration', package?.duration ?? 'N/A'),
                        _row('Travel Date', travelDate),
                        _row('Travelers', '$seats seat${seats > 1 ? 's' : ''}'),
                        _row('Payment Method', paymentMethod),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Pricing Card
                    _card(
                      title: 'Price Breakdown',
                      children: [
                        if (hasDiscount) ...[
                          _row('Original Price',
                              'PKR ${pricePerPerson.toStringAsFixed(0)} × $seats'),
                          _row('Discount',
                              '${discountPct.toInt()}% OFF',
                              valueColor: AppColors.error),
                          _row('Price after discount',
                              'PKR ${effectivePrice.toStringAsFixed(0)} × $seats'),
                        ] else
                          _row('Price per person',
                              'PKR ${pricePerPerson.toStringAsFixed(0)} × $seats'),
                        const Divider(height: 24),
                        _row(
                          'Total',
                          'PKR ${total.toStringAsFixed(0)}',
                          isBold: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Cancellation Policy
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cancellation Policy',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Refer to agent\'s terms and conditions for specific refund policies regarding this package.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Action
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: CustomButton(
                text: package?.isExpired == true
                    ? 'This package is no longer available'
                    : 'Proceed to Payment',
                onPressed: (package == null || package.isExpired)
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          '/booking-form',
                          arguments: package,
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.headingSmall.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
