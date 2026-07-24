import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/star_rating.dart';
import '../../models/package.dart';
import '../../services/package_service.dart';
import '../../config/api_config.dart';

class PackageDetailScreen extends StatefulWidget {
  final String packageId;

  const PackageDetailScreen({super.key, required this.packageId});

  @override
  State<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends State<PackageDetailScreen> {
  Package? _package;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackageDetail();
  }

  Future<void> _loadPackageDetail() async {
    setState(() => _isLoading = true);
    final package = await PackageService.getPackageDetail(widget.packageId);
    if (mounted) {
      setState(() {
        _package = package;
        _isLoading = false;
      });

      // Show discount pop-up if package has a discount
      if (package != null && package.hasDiscount == true && (package.discountPercentage ?? 0) > 0) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showDiscountDialog(package);
        });
      }
    }
  }

  void _showDiscountDialog(Package package) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFff416c), Color(0xFFff4b2b)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_offer, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              const Text(
                'EXCLUSIVE OFFER!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Get ${package.discountPercentage?.toInt() ?? 0}% OFF on this adventure',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFff416c),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  'WOW, SHOW ME!',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    }
    return date.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_package == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Package not found')),
      );
    }

    final pkg = _package!;
    final hasDiscount = pkg.hasDiscount == true;
    final discountPct = pkg.discountPercentage ?? 0;
    final originalPrice = pkg.price;
    final discountedPrice = hasDiscount
        ? (originalPrice - (originalPrice * discountPct / 100))
        : originalPrice;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Image ─────────────────────────────────────────
                Stack(
                  children: [
                    SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: ApiConfig.getImageUrl(
                          (pkg.image != null && pkg.image!.isNotEmpty)
                              ? pkg.image!
                              : (pkg.images != null && pkg.images!.isNotEmpty
                                  ? pkg.images![0]
                                  : null),
                        ),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.backgroundGray,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.backgroundGray,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.75),
                          ],
                        ),
                      ),
                    ),
                    // Badges
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      right: 16,
                      child: Row(
                        children: [
                          if (pkg.isFeatured == true)
                            _badge('⭐ FEATURED',
                                const Color(0xFFf7971e), const Color(0xFFffd200),
                                Colors.black),
                          if (pkg.isFeatured == true && hasDiscount)
                            const SizedBox(width: 8),
                          if (hasDiscount && discountPct > 0)
                            _badge('🔥 ${discountPct.toInt()}% OFF',
                                const Color(0xFFff416c), const Color(0xFFff4b2b),
                                Colors.white),
                        ],
                      ),
                    ),
                    // Title overlay
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.title,
                            style: AppTextStyles.headingMedium.copyWith(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                pkg.location,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                              if (pkg.province != null &&
                                  pkg.province!.isNotEmpty) ...[
                                const Text('  •  ',
                                    style: TextStyle(color: Colors.white54)),
                                Text(
                                  pkg.province!,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Quick Info Card ───────────────────────────────
                      _card(
                        child: Column(
                          children: [
                            // Agent + Price row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Travel Agent',
                                        style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textTertiary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      pkg.agentName,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Price/Person',
                                        style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textTertiary)),
                                    const SizedBox(height: 4),
                                    if (hasDiscount) ...[
                                      Text(
                                        'PKR ${originalPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: AppColors.textTertiary,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'PKR ${discountedPrice.toStringAsFixed(0)}',
                                        style:
                                            AppTextStyles.headingSmall.copyWith(
                                          color: AppColors.primary,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ] else
                                      Text(
                                        'PKR ${originalPrice.toStringAsFixed(0)}',
                                        style:
                                            AppTextStyles.headingSmall.copyWith(
                                          color: AppColors.primary,
                                          fontSize: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            // Stats row
                            Builder(
                              builder: (context) {
                                final statsItems = <Widget>[
                                  _infoItem(
                                    Icons.access_time_outlined,
                                    'Duration',
                                    pkg.duration,
                                  ),
                                  _infoItem(
                                    Icons.flight_takeoff_outlined,
                                    'Departure',
                                    pkg.departureCity ?? pkg.location,
                                  ),
                                  Column(
                                    children: [
                                      const Icon(Icons.star_outline,
                                          color: AppColors.primary, size: 20),
                                      const SizedBox(height: 4),
                                      Text('Ratings',
                                          style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.textTertiary)),
                                      const SizedBox(height: 2),
                                      StarRating(
                                          rating: pkg.rating ?? 4.5, size: 14),
                                    ],
                                  ),
                                ];

                                if (pkg.departureTime != null &&
                                    pkg.departureTime!.isNotEmpty) {
                                  statsItems.add(_infoItem(
                                    Icons.access_time,
                                    'Time',
                                    pkg.departureTime!,
                                  ));
                                }

                                if (pkg.departureLocation != null &&
                                    pkg.departureLocation!.isNotEmpty) {
                                  statsItems.add(_infoItem(
                                    Icons.pin_drop_outlined,
                                    'Location',
                                    pkg.departureLocation!,
                                  ));
                                }

                                if (statsItems.length <= 3) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: statsItems
                                        .map((w) => Expanded(child: w))
                                        .toList(),
                                  );
                                } else {
                                  final row1 = statsItems.sublist(0, 3);
                                  final row2 = statsItems.sublist(3);
                                  return Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: row1
                                            .map((w) => Expanded(child: w))
                                            .toList(),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ...row2.map((w) => Expanded(child: w)),
                                          ...List.generate(
                                            3 - row2.length,
                                            (index) => const Expanded(
                                                child: SizedBox.shrink()),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Description ───────────────────────────────────
                      if (pkg.description.isNotEmpty) ...[
                        _sectionTitle('About this Package'),
                        const SizedBox(height: 10),
                        _card(
                          child: Text(
                            pkg.description,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Dates ─────────────────────────────────────────
                      if (pkg.startDate != null || pkg.endDate != null) ...[
                        _sectionTitle('Trip Dates'),
                        const SizedBox(height: 10),
                        _card(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _dateItem('Departure Date',
                                        _formatDate(pkg.startDate)),
                                  ),
                                  Expanded(
                                    child: _dateItem('Return Date',
                                        _formatDate(pkg.endDate)),
                                  ),
                                ],
                              ),
                              if (pkg.isExpired) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          size: 16, color: Colors.red.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This package is no longer available',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (pkg.availableDates != null &&
                                  pkg.availableDates!.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Available Departure Dates',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textTertiary),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: pkg.availableDates!
                                      .map((d) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: AppColors.primary
                                                      .withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              _formatDate(d),
                                              style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── What's Included ───────────────────────────────
                      _sectionTitle('What\'s Included'),
                      const SizedBox(height: 10),
                      _card(
                        child: Column(
                          children: [
                            _includedRow(Icons.directions_bus_outlined,
                                'Transport', pkg.includesTransport == true),
                            const SizedBox(height: 12),
                            _includedRow(Icons.hotel_outlined, 'Accommodation',
                                pkg.includesAccommodation == true),
                            const SizedBox(height: 12),
                            _includedRow(Icons.restaurant_outlined, 'Meals',
                                pkg.includesMeals == true),
                            const SizedBox(height: 12),
                            _includedRow(Icons.camera_alt_outlined,
                                'Sightseeing', true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Not Included ──────────────────────────────────
                      _sectionTitle('Not Included'),
                      const SizedBox(height: 10),
                      _card(
                        child: Text(
                          pkg.notIncluded?.isNotEmpty == true
                              ? pkg.notIncluded!
                              : '• Personal expenses\n• Travel insurance\n• Additional activities',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Trip Highlights ───────────────────────────────
                      if (pkg.tripHighlights != null &&
                          pkg.tripHighlights!.isNotEmpty) ...[
                        _sectionTitle('Trip Highlights'),
                        const SizedBox(height: 10),
                        _card(
                          child: Text(
                            pkg.tripHighlights!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Daily Itinerary ───────────────────────────────
                      if (pkg.itinerary != null &&
                          pkg.itinerary!.isNotEmpty) ...[
                        _sectionTitle('Daily Itinerary'),
                        const SizedBox(height: 10),
                        ...pkg.itinerary!.asMap().entries.map((entry) {
                          final i = entry.key;
                          final day = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Day indicator
                                Column(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (i < pkg.itinerary!.length - 1)
                                      Container(
                                        width: 2,
                                        height: 60,
                                        color: AppColors.primary
                                            .withOpacity(0.2),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _card(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          day['title'] ?? 'Day ${i + 1}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (day['description'] != null &&
                                            day['description']
                                                .toString()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            day['description'],
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                              color: AppColors.textSecondary,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],

                      // ── Seats ─────────────────────────────────────────
                      if (pkg.availableSeats > 0) ...[
                        _card(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: pkg.availableSeats <= 5
                                      ? Colors.orange.withOpacity(0.1)
                                      : AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.airline_seat_recline_normal_outlined,
                                  color: pkg.availableSeats <= 5
                                      ? Colors.orange
                                      : AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Available Seats',
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textTertiary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    pkg.availableSeats <= 5
                                        ? 'Only ${pkg.availableSeats} seats left!'
                                        : '${pkg.availableSeats} seats available',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: pkg.availableSeats <= 5
                                          ? Colors.orange.shade700
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Bottom padding for the fixed button to allow scrolling all the way to the end
                      const SizedBox(height: 160),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Back Button ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // ── Book Now Button ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pkg.isExpired)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              'This package is no longer available',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (pkg.availableSeats == 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy,
                                size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              'Fully Booked',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (pkg.availableSeats <= 5)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Only ${pkg.availableSeats} seats left!',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    CustomButton(
                      text: pkg.isExpired
                          ? 'This package is no longer available'
                          : (pkg.availableSeats == 0
                              ? 'Fully Booked'
                              : 'Book Now'),
                      onPressed: (pkg.isExpired || pkg.availableSeats == 0)
                          ? null
                          : () {
                              // Track click event for analytics/performance screen
                              PackageService.trackClick(pkg.id);
                              Navigator.pushNamed(
                                context,
                                '/booking-form',
                                arguments: _package,
                              );
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────────

  Widget _badge(String text, Color c1, Color c2, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c1, c2]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: AppTextStyles.headingSmall);
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(label,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 2),
        Text(value,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _dateItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(value,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _includedRow(IconData icon, String label, bool included) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: included
                ? AppColors.primary.withOpacity(0.1)
                : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: included ? AppColors.primary : Colors.grey, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Text(label, style: AppTextStyles.bodyMedium),
        ),
        Icon(
          included ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: included ? Colors.green : Colors.grey.shade400,
          size: 20,
        ),
      ],
    );
  }
}