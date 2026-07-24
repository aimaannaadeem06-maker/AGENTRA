import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../models/package.dart';
import '../../services/booking_service.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';
import '../../theme/app_theme.dart';

class CreateBookingScreen extends StatefulWidget {
  final Package package;
  const CreateBookingScreen({super.key, required this.package});

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  int _seats = 1;
  late DateTime _selectedDate;
  bool _isLoading = false;

  // ── Card details entered inline ──────────────────────────────────────────
  final _holderCtrl = TextEditingController();
  final _cardCtrl   = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl    = TextEditingController();

  // Saved cards from wallet (pre-fill if user has one)
  List<Map<String, dynamic>> _savedCards = [];
  String? _selectedSavedCardId;
  bool _useNewCard = true;
  bool _loadingCards = true;

  /// Build the set of valid departure dates:
  /// startDate + any availableDates, all normalised to midnight.
  /// endDate is intentionally excluded — it is the *return* date.
  List<DateTime> get _validDepartureDates {
    final Set<DateTime> dates = {};
    final pkg = widget.package;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    void addIfNotPast(DateTime? d) {
      if (d == null) return;
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isBefore(today)) dates.add(day);
    }

    addIfNotPast(pkg.startDate);
    if (pkg.availableDates != null) {
      for (final d in pkg.availableDates!) {
        addIfNotPast(d);
      }
    }

    final list = dates.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _initSelectedDate();
    _loadSavedCards();
  }

  void _initSelectedDate() {
    final valid = _validDepartureDates;
    if (valid.isNotEmpty) {
      _selectedDate = valid.first;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCards() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse(ApiConfig.WALLET),
        headers: {'x-auth-token': token},
      );
      if (r.statusCode == 200 && mounted) {
        final cards = List<Map<String, dynamic>>.from(
            jsonDecode(r.body)['wallet']['cards'] ?? []);
        setState(() {
          _savedCards = cards;
          if (cards.isNotEmpty) {
            // Pre-select default card and switch to saved card mode
            final def = cards.firstWhere(
              (c) => c['isDefault'] == true,
              orElse: () => cards.first,
            );
            _selectedSavedCardId = def['_id'];
            _useNewCard = false;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCards = false);
  }

  double get _totalPrice {
    final price = (widget.package.hasDiscount == true)
        ? widget.package.price *
            (1 - (widget.package.discountPercentage ?? 0) / 100)
        : widget.package.price;
    return price * _seats;
  }

  Future<void> _selectDate() async {
    if (widget.package.isExpired) {
      _snack('This package is no longer available', isError: true);
      return;
    }

    final validDates = _validDepartureDates;
    if (validDates.isEmpty) {
      _snack('No departure dates available for this package', isError: true);
      return;
    }

    final firstDate = validDates.first;
    final lastDate  = validDates.last;

    // Make sure the initial date shown in the picker is valid
    DateTime initial = _selectedDate;
    final initialDay = DateTime(initial.year, initial.month, initial.day);
    if (!validDates.contains(initialDay)) initial = firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select a departure date',
      // Only allow the explicitly valid departure dates
      selectableDayPredicate: (day) {
        final d = DateTime(day.year, day.month, day.day);
        return validDates.contains(d);
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _confirmBooking() async {
    if (widget.package.isExpired) {
      _snack('This package is no longer available', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        _snack('Please log in first', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      String? cardId = _useNewCard ? null : _selectedSavedCardId;

      // If user entered a new card, save it to wallet first
      if (_useNewCard) {
        final holder = _holderCtrl.text.trim();
        final number = _cardCtrl.text.replaceAll(' ', '');
        final expiry = _expiryCtrl.text.trim();
        final cvv    = _cvvCtrl.text.trim();
        final parts  = expiry.split('/');

        final cardResp = await http.post(
          Uri.parse(ApiConfig.WALLET_CARDS),
          headers: {'Content-Type': 'application/json', 'x-auth-token': token},
          body: jsonEncode({
            'cardHolderName': holder,
            'cardNumber':     number,
            'expiryMonth':    parts[0],
            'expiryYear':     '20${parts[1]}',
            'cvv':            cvv,
            'setDefault':     _savedCards.isEmpty,
          }),
        );

        if (cardResp.statusCode != 201) {
          final d = jsonDecode(cardResp.body);
          _snack(d['message'] ?? 'Invalid card details', isError: true);
          setState(() => _isLoading = false);
          return;
        }

        // Get the new card's ID
        final newCardData = jsonDecode(cardResp.body);
        // Reload wallet to get the card _id
        final walletResp = await http.get(
          Uri.parse(ApiConfig.WALLET),
          headers: {'x-auth-token': token},
        );
        if (walletResp.statusCode == 200) {
          final cards = List<Map<String, dynamic>>.from(
              jsonDecode(walletResp.body)['wallet']['cards'] ?? []);
          if (cards.isNotEmpty) {
            cardId = cards.last['_id'];
          }
        }
      }

      // Create booking — backend deducts from user wallet and credits agent
      final result = await BookingService.createBooking(
        packageId:     widget.package.id,
        seats:         _seats,
        travelDate:    _selectedDate.toIso8601String().split('T')[0],
        paymentMethod: 'CARD',
        cardId:        cardId,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/payment-success',
          (route) => route.settings.name == '/home' || route.isFirst,
        );
      } else {
        _snack(result['message'] ?? 'Booking failed', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _snack('Network error. Please try again.', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
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
        title: const Text('Book Package', style: AppTextStyles.headingSmall),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── Package summary ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radius),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.package.title, style: AppTextStyles.headingSmall),
                const SizedBox(height: 4),
                Text(widget.package.location,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                if (widget.package.hasDiscount == true &&
                    (widget.package.discountPercentage ?? 0) > 0) ...[
                  Text(
                    'PKR ${widget.package.price.toStringAsFixed(0)} per person',
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey, fontSize: 13),
                  ),
                  Text(
                    'PKR ${(widget.package.price * (1 - (widget.package.discountPercentage ?? 0) / 100)).toStringAsFixed(0)} per person',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ] else
                  Text(
                    'PKR ${widget.package.price.toStringAsFixed(0)} per person',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Seats ─────────────────────────────────────────────────────
            const Text('Number of Seats',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              IconButton(
                onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 32, color: AppColors.primary,
              ),
              Expanded(
                child: Center(
                  child: Text('$_seats',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w900)),
                ),
              ),
              IconButton(
                onPressed: _seats < widget.package.availableSeats
                    ? () => setState(() => _seats++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 32, color: AppColors.primary,
              ),
            ]),
            Center(
              child: Text('${widget.package.availableSeats} seats available',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 24),

            // ── Travel date ───────────────────────────────────────────────
            const Text('Travel Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Tap a date chip below or use the calendar to pick a departure date.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),

            // ── Available departure date chips ────────────────────────────
            Builder(builder: (context) {
              final dates = _validDepartureDates;
              if (dates.isEmpty) {
                return Text(
                  'No upcoming departure dates available.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.red.shade400),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: dates.map((d) {
                  final isSelected =
                      DateTime(_selectedDate.year, _selectedDate.month,
                              _selectedDate.day) ==
                          d;
                  final label =
                      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                  return ChoiceChip(
                    label: Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary)),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border),
                    onSelected: widget.package.isExpired
                        ? null
                        : (_) => setState(() => _selectedDate = d),
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 12),

            // ── Calendar tap to pick ──────────────────────────────────────
            InkWell(
              onTap: widget.package.isExpired ? null : _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.package.isExpired
                      ? Colors.grey.shade100
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today,
                      color: widget.package.isExpired
                          ? Colors.grey
                          : AppColors.primary,
                      size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.package.isExpired
                            ? Colors.grey
                            : AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Text('Open calendar',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(height: 28),

            // ── Payment section ───────────────────────────────────────────
            const Text('Payment Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            if (_loadingCards)
              const Center(child: CircularProgressIndicator())
            else ...[

              // If user has saved cards, show option to use one
              if (_savedCards.isNotEmpty) ...[
                // Toggle: saved card vs new card
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useNewCard = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_useNewCard
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(10)),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Center(
                          child: Text('Saved Card',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: !_useNewCard
                                      ? Colors.white
                                      : AppColors.primary)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useNewCard = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _useNewCard
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(10)),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Center(
                          child: Text('New Card',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _useNewCard
                                      ? Colors.white
                                      : AppColors.primary)),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
              ],

              // Saved card selector
              if (!_useNewCard && _savedCards.isNotEmpty) ...[
                ..._savedCards.map((card) {
                  final isSelected = _selectedSavedCardId == card['_id'];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedSavedCardId = card['_id']),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFEEEEEE),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(children: [
                        const Icon(Icons.credit_card,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(card['cardHolderName'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(
                                    '•••• •••• •••• ${card['last4']}  |  ${card['cardType']}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                Text(
                                    'Expires ${card['expiryMonth']}/${card['expiryYear']}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ]),
                        ),
                        Radio<String>(
                          value: card['_id'],
                          groupValue: _selectedSavedCardId,
                          onChanged: (v) =>
                              setState(() => _selectedSavedCardId = v),
                          activeColor: AppColors.primary,
                        ),
                      ]),
                    ),
                  );
                }),
              ],

              // New card form
              if (_useNewCard) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.lock_outline,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('Secure Card Payment',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ]),
                      const SizedBox(height: 16),

                      // Card holder
                      _cardField(
                        label: 'Card Holder Name',
                        controller: _holderCtrl,
                        hint: 'John Doe',
                        inputType: TextInputType.name,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Card holder name is required';
                          }
                          if (!RegExp(r'^[a-zA-Z\s]{2,50}$')
                              .hasMatch(v.trim())) {
                            return 'Letters only (2–50 chars)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Card number
                      _cardField(
                        label: 'Card Number',
                        controller: _cardCtrl,
                        hint: '1234 5678 9012 3456',
                        inputType: TextInputType.number,
                        formatter: _CardNumberFormatter(),
                        validator: (v) {
                          final n = (v ?? '').replaceAll(' ', '');
                          if (n.isEmpty) return 'Card number is required';
                          if (n.length < 13 || n.length > 19) {
                            return 'Must be 13–19 digits';
                          }
                          if (!RegExp(r'^\d+$').hasMatch(n)) {
                            return 'Digits only';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Expiry + CVV
                      Row(children: [
                        Expanded(
                          child: _cardField(
                            label: 'Expiry (MM/YY)',
                            controller: _expiryCtrl,
                            hint: '12/26',
                            inputType: TextInputType.number,
                            formatter: _ExpiryFormatter(),
                            validator: (v) {
                              if (v == null || v.trim().length < 5) {
                                return 'Enter MM/YY';
                              }
                              final parts = v.split('/');
                              if (parts.length != 2) return 'Format: MM/YY';
                              final m = int.tryParse(parts[0]);
                              final y = int.tryParse('20${parts[1]}');
                              if (m == null || m < 1 || m > 12) {
                                return 'Invalid month';
                              }
                              if (y == null) return 'Invalid year';
                              final now = DateTime.now();
                              if (DateTime(y, m)
                                  .isBefore(DateTime(now.year, now.month))) {
                                return 'Card expired';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _cardField(
                            label: 'CVV',
                            controller: _cvvCtrl,
                            hint: '•••',
                            inputType: TextInputType.number,
                            obscure: true,
                            maxLen: 4,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'CVV required';
                              }
                              if (!RegExp(r'^\d{3,4}$').hasMatch(v.trim())) {
                                return '3 or 4 digits';
                              }
                              return null;
                            },
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),

            // ── Total ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(
                    'PKR ${_totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '💳 Amount will be charged from your card and credited to the agent.',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: 24),

            // ── Expired / Fully booked warning ────────────────────────────
            if (widget.package.isExpired)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This package is no longer available.',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              )
            else if (widget.package.availableSeats == 0)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('This package is fully booked.')),
                ]),
              ),

            // ── Confirm & Pay button ──────────────────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: (_isLoading ||
                        widget.package.availableSeats == 0 ||
                        widget.package.isExpired ||
                        _loadingCards)
                    ? null
                    : _confirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.package.isExpired
                            ? 'THIS PACKAGE IS NO LONGER AVAILABLE'
                            : (widget.package.availableSeats == 0
                                ? 'FULLY BOOKED'
                                : 'CONFIRM & PAY PKR ${_totalPrice.toStringAsFixed(0)}'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _cardField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType inputType = TextInputType.text,
    TextInputFormatter? formatter,
    bool obscure = false,
    int? maxLen,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7D848D))),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: inputType,
        obscureText: obscure,
        maxLength: maxLen,
        inputFormatters: formatter != null ? [formatter] : null,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red)),
        ),
      ),
    ]);
  }
}

// ── Input formatters ──────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return TextEditingValue(
        text: str, selection: TextSelection.collapsed(offset: str.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 2) return next.copyWith(text: digits);
    final str =
        '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(0, 4))}';
    return TextEditingValue(
        text: str, selection: TextSelection.collapsed(offset: str.length));
  }
}
