import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../config/api_config.dart';
import '../../models/booking.dart';
import '../../models/package.dart';
import '../../services/booking_service.dart';
import '../../services/package_service.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _isCancelling = false;
  Package? _package;
  bool _isLoadingPackage = true;
  String? _packageError;

  @override
  void initState() {
    super.initState();
    _loadPackage();
  }

  Future<void> _loadPackage() async {
    if (widget.booking.packageId.isEmpty) {
      setState(() {
        _isLoadingPackage = false;
        _packageError = 'Package details are unavailable.';
      });
      return;
    }

    final package =
        await PackageService.getPackageDetail(widget.booking.packageId);
    if (mounted) {
      setState(() {
        _package = package;
        _isLoadingPackage = false;
        if (package == null) {
          _packageError = 'Unable to load package details.';
        }
      });
    }
  }

  Future<void> _cancelBooking() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cancel Booking?',
                textAlign: TextAlign.center,
                style: AppTextStyles.headingSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Booking for ${widget.booking.packageTitle}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Reason for cancellation (optional)',
                  hintStyle: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radius),
                        ),
                      ),
                      child: Text(
                        'Keep',
                        style: AppTextStyles.button
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radius),
                        ),
                      ),
                      child: const Text('Cancel Booking'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final reason = reasonController.text.trim();
    setState(() => _isCancelling = true);
    final success = await BookingService.cancelBooking(widget.booking.id, reason: reason);
    if (mounted) {
      setState(() => _isCancelling = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Booking cancelled. Refund request submitted to agent.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // signal refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel booking. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final bool canCancel = booking.status.toLowerCase() == 'confirmed' ||
        booking.status.toLowerCase() == 'pending';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  innerBoxIsScrolled ? booking.packageTitle : "",
                  style: AppTextStyles.headingSmall.copyWith(color: Colors.white),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (booking.packageImage != null && booking.packageImage!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: ApiConfig.getImageUrl(booking.packageImage!),
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        color: AppColors.backgroundLight,
                        child: const Icon(Icons.landscape, size: 80, color: Colors.white54),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(booking.status).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              booking.status.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            booking.packageTitle,
                            style: AppTextStyles.headingMedium.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              _buildBookingInfo(booking),
              if (_isLoadingPackage)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )
              else if (_package != null) ...[
                _buildPackageInfo(_package!),
                _buildPricingInfo(_package!),
                _buildInclusions(_package!),
                _buildItinerary(_package!),
                _buildPolicy(_package),
              ] else if (_packageError != null)
                _buildErrorCard(_packageError!),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: canCancel ? _buildCancelButton() : null,
    );
  }

  Widget _buildBookingInfo(Booking booking) {
    return _modernSection(
      title: 'Booking Information',
      icon: Icons.receipt_long_rounded,
      children: [
        _rowItem(Icons.tag, 'Booking ID', '#${booking.id.length > 8 ? booking.id.substring(booking.id.length - 8) : booking.id}'),
        _rowItem(Icons.calendar_today_rounded, 'Travel Date', booking.travelDate),
        _rowItem(Icons.people_alt_rounded, 'Total Seats', '${booking.seats} Adults'),
        _rowItem(Icons.payments_rounded, 'Total Paid', 'PKR ${booking.totalPrice.toStringAsFixed(0)}', isPrimary: true),
        _rowItem(Icons.payment_rounded, 'Method', booking.paymentMethod),
      ],
    );
  }

  Widget _buildPackageInfo(Package pkg) {
    return _modernSection(
      title: 'Package Overview',
      icon: Icons.info_outline_rounded,
      children: [
        if (pkg.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(pkg.description, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5)),
          ),
        _rowItem(Icons.location_on_rounded, 'Destination', '${pkg.location}${pkg.province != null ? ", ${pkg.province}" : ""}'),
        _rowItem(Icons.departure_board_rounded, 'Departure', pkg.departureCity ?? 'N/A'),
        _rowItem(Icons.timer_rounded, 'Duration', pkg.duration),
        _rowItem(Icons.business_rounded, 'Travel Agent', pkg.agentName),
      ],
    );
  }

  Widget _buildPricingInfo(Package pkg) {
    return _modernSection(
      title: 'Pricing Details',
      icon: Icons.sell_rounded,
      children: [
        _rowItem(Icons.money, 'Base Price', 'PKR ${pkg.price.toStringAsFixed(0)}'),
        if (pkg.hasDiscount == true)
          _rowItem(Icons.discount_rounded, 'Discount', '${pkg.discountPercentage?.toStringAsFixed(0)}%', valueColor: Colors.green),
        _rowItem(Icons.event_seat_rounded, 'Availability', '${pkg.availableSeats} seats left'),
      ],
    );
  }

  Widget _buildInclusions(Package pkg) {
    final hasInclusions = (pkg.includesTransport == true) || (pkg.includesAccommodation == true) || (pkg.includesMeals == true);
    if (!hasInclusions && (pkg.notIncluded == null || pkg.notIncluded!.isEmpty)) return const SizedBox();

    return _modernSection(
      title: 'Inclusions & Exclusions',
      icon: Icons.list_alt_rounded,
      children: [
        if (hasInclusions)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pkg.includesTransport == true) _tag('Transport', Icons.directions_bus_rounded),
              if (pkg.includesAccommodation == true) _tag('Hotel', Icons.hotel_rounded),
              if (pkg.includesMeals == true) _tag('Meals', Icons.restaurant_rounded),
            ],
          ),
        if (hasInclusions && pkg.notIncluded != null && pkg.notIncluded!.isNotEmpty) const SizedBox(height: 16),
        if (pkg.notIncluded != null && pkg.notIncluded!.isNotEmpty)
          _detailBlock('Not Included', pkg.notIncluded!),
      ],
    );
  }

  Widget _buildItinerary(Package pkg) {
    if (pkg.itinerary == null || pkg.itinerary!.isEmpty) return const SizedBox();
    return _modernSection(
      title: 'Trip Itinerary',
      icon: Icons.map_rounded,
      children: pkg.itinerary!.map((item) {
        final day = item['day']?.toString() ?? '?';
        final detail = item['details'] ?? item['description'] ?? 'No details';
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Day $day', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(detail.toString(), style: AppTextStyles.bodyMedium.copyWith(height: 1.4)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPolicy(Package? pkg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.policy_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text('Cancellation Policy', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (pkg?.cancellationPolicy != null && pkg!.cancellationPolicy!.isNotEmpty)
                ? pkg.cancellationPolicy!
                : 'Refer to agent\'s terms and conditions for specific refund policies regarding this package.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: CustomButton(
          text: 'Cancel Booking',
          backgroundColor: AppColors.error,
          isLoading: _isCancelling,
          onPressed: _isCancelling ? null : _cancelBooking,
        ),
      ),
    );
  }

  Widget _modernSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(title, style: AppTextStyles.headingSmall.copyWith(fontSize: 17)),
            ],
          ),
          const Divider(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _rowItem(IconData icon, String label, String value, {bool isPrimary = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? (isPrimary ? AppColors.primary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Text(error, style: const TextStyle(color: Colors.orange)),
    );
  }

  Widget _detailBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      case 'completed': return AppColors.primary;
      default: return AppColors.orange;
    }
  }
}
