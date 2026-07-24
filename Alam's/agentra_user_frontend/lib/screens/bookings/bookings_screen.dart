import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../config/api_config.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';
import '../reviews/rate_trip_screen.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  int _currentIndex = 1;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Booking> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    final bookings = await BookingService.getMyBookings();
    if (mounted) {
      setState(() {
        _bookings = bookings;
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
          'My Bookings',
          style: AppTextStyles.headingSmall,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookings,
              child: Column(
                children: [
                  // Calendar
                  Container(
                    margin: const EdgeInsets.all(16),
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
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                                setState(() {
                                  _focusedMonth = DateTime(
                                    _focusedMonth.year,
                                    _focusedMonth.month - 1,
                                  );
                                });
                              },
                            ),
                            Text(
                              '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}',
                              style: AppTextStyles.headingSmall
                                  .copyWith(fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                setState(() {
                                  _focusedMonth = DateTime(
                                    _focusedMonth.year,
                                    _focusedMonth.month + 1,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Weekday labels
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(child: Center(child: Text('S', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTertiary, fontSize: 13)))),
                              Expanded(child: Center(child: Text('M', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTertiary, fontSize: 13)))),
                              Expanded(child: Center(child: Text('T', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTertiary, fontSize: 13)))),
                              Expanded(child: Center(child: Text('W', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTertiary, fontSize: 13)))),
                              Expanded(child: Center(child: Text('T', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTertiary, fontSize: 13)))),
                              Expanded(child: Center(child: Text('F', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTertiary, fontSize: 13)))),
                              Expanded(child: Center(child: Text('S', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTertiary, fontSize: 13)))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Calendar Grid
                        Builder(
                          builder: (context) {
                            final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
                            final padding = firstDayOfMonth.weekday % 7;
                            final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
                            final totalCells = padding + daysInMonth;

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                              itemCount: totalCells,
                              itemBuilder: (context, index) {
                                if (index < padding) {
                                  return const SizedBox.shrink();
                                }

                                final day = index - padding + 1;
                                final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                                
                                final isToday = day == DateTime.now().day &&
                                    _focusedMonth.month == DateTime.now().month &&
                                    _focusedMonth.year == DateTime.now().year;

                                final isSelected = _selectedDate != null &&
                                    _selectedDate!.day == day &&
                                    _selectedDate!.month == _focusedMonth.month &&
                                    _selectedDate!.year == _focusedMonth.year;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedDate = null; // deselect
                                      } else {
                                        _selectedDate = cellDate;
                                      }
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isToday
                                              ? AppColors.primary.withOpacity(0.12)
                                              : Colors.transparent),
                                      borderRadius: BorderRadius.circular(8),
                                      border: isToday && !isSelected
                                          ? Border.all(
                                              color: AppColors.primary.withOpacity(0.5),
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      day.toString(),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : (isToday
                                                ? AppColors.primary
                                                : AppColors.textPrimary),
                                        fontWeight: (isToday || isSelected)
                                            ? FontWeight.bold
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Confirmed Bookings Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _selectedDate == null
                            ? 'All Bookings'
                            : 'Bookings on ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}',
                        style: AppTextStyles.headingSmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final filteredBookings = _selectedDate == null
                            ? _bookings
                            : _bookings
                                .where((b) => _isSameDay(b.travelDate, _selectedDate!))
                                .toList();

                        if (filteredBookings.isEmpty) {
                          return Center(
                            child: Text(
                              _selectedDate == null
                                  ? 'No bookings found.'
                                  : 'No bookings on this date.',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textTertiary),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredBookings.length,
                          itemBuilder: (context, index) {
                            final booking = filteredBookings[index];
                            return _buildBookingCard(booking);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) return;

          setState(() => _currentIndex = index);

          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/home');
              break;
            case 2:
              Navigator.pushNamed(context, '/chat');
              break;
            case 3:
              Navigator.pushNamed(context, '/search');
              break;
            case 4:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return GestureDetector(
      onTap: () {
        if (booking.status.toLowerCase() == 'completed') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RateTripScreen(packageId: booking.packageId),
            ),
          ).then((_) => _loadBookings());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailScreen(booking: booking),
            ),
          ).then((result) {
            if (result == true) _loadBookings();
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                image: (booking.packageImage != null &&
                        booking.packageImage!.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(
                            ApiConfig.getImageUrl(booking.packageImage!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (booking.packageImage == null ||
                      booking.packageImage!.isEmpty)
                  ? const Icon(Icons.image, color: AppColors.textTertiary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.packageTitle,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDate(booking.travelDate),
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              _getStatusColor(booking.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          booking.status.toUpperCase(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _getStatusColor(booking.status),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (booking.status.toLowerCase() == 'completed')
              const Icon(
                Icons.rate_review,
                color: AppColors.primary,
                size: 20,
              )
            else
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'No Date';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  bool _isSameDay(String bookingDateStr, DateTime filterDate) {
    if (bookingDateStr.isEmpty) return false;
    try {
      final date = DateTime.parse(bookingDateStr);
      return date.year == filterDate.year &&
          date.month == filterDate.month &&
          date.day == filterDate.day;
    } catch (_) {
      return false;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.orange;
      case 'cancelled':
        return AppColors.error;
      case 'completed':
        return AppColors.primary;
      default:
        return AppColors.textTertiary;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
