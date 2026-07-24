import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Mock card payment screen — Fiverr-style wallet deduction.
/// Shows wallet balance, saved cards, and allows adding a new card.
class CardPaymentScreen extends StatefulWidget {
  final String bookingId;
  final double amount;
  final String packageTitle;
  final VoidCallback onSuccess;

  const CardPaymentScreen({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.packageTitle,
    required this.onSuccess,
  });

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  bool _isLoading = true;
  bool _isPaying  = false;

  double _walletBalance = 0;
  List<Map<String, dynamic>> _cards = [];
  String? _selectedCardId;

  // New card form
  bool _showAddCard = false;
  final _cardHolderCtrl  = TextEditingController();
  final _cardNumberCtrl  = TextEditingController();
  final _expiryCtrl      = TextEditingController(); // MM/YY
  final _cvvCtrl         = TextEditingController();
  bool _setDefault       = true;
  bool _addingCard       = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _cardHolderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse(ApiConfig.WALLET),
        headers: {'x-auth-token': token},
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final w = data['wallet'];
        final cards = List<Map<String, dynamic>>.from(w['cards'] ?? []);
        setState(() {
          _walletBalance = (w['balance'] ?? 0).toDouble();
          _cards = cards;
          // Pre-select default card
          final def = cards.firstWhere(
            (c) => c['isDefault'] == true,
            orElse: () => cards.isNotEmpty ? cards.first : {},
          );
          _selectedCardId = def['_id'];
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _addCard() async {
    final holder = _cardHolderCtrl.text.trim();
    final number = _cardNumberCtrl.text.replaceAll(' ', '');
    final expiry = _expiryCtrl.text.trim();
    final cvv    = _cvvCtrl.text.trim();

    // ── Validation ────────────────────────────────────────────────────────────
    if (holder.isEmpty) {
      _snack('Card holder name is required', isError: true); return;
    }
    if (!RegExp(r'^[a-zA-Z\s]{2,50}$').hasMatch(holder)) {
      _snack('Card holder name: letters only (2–50 chars)', isError: true); return;
    }
    if (number.length < 13 || number.length > 19 || !RegExp(r'^\d+$').hasMatch(number)) {
      _snack('Card number must be 13–19 digits', isError: true); return;
    }
    if (expiry.length < 5) {
      _snack('Enter expiry as MM/YY', isError: true); return;
    }
    final parts = expiry.split('/');
    if (parts.length != 2) {
      _snack('Expiry must be MM/YY', isError: true); return;
    }
    final month = int.tryParse(parts[0]);
    final year  = int.tryParse('20${parts[1]}');
    if (month == null || month < 1 || month > 12) {
      _snack('Invalid expiry month (01–12)', isError: true); return;
    }
    if (year == null) {
      _snack('Invalid expiry year', isError: true); return;
    }
    final now = DateTime.now();
    if (DateTime(year, month).isBefore(DateTime(now.year, now.month))) {
      _snack('Card has expired', isError: true); return;
    }
    if (!RegExp(r'^\d{3,4}$').hasMatch(cvv)) {
      _snack('CVV must be 3 or 4 digits', isError: true); return;
    }

    setState(() => _addingCard = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final r = await http.post(
        Uri.parse(ApiConfig.WALLET_CARDS),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({
          'cardHolderName': holder,
          'cardNumber':     number,
          'expiryMonth':    parts[0],
          'expiryYear':     '20${parts[1]}',
          'cvv':            cvv,
          'setDefault':     _setDefault,
        }),
      );
      if (r.statusCode == 201) {
        _snack('Card added successfully');
        _cardHolderCtrl.clear();
        _cardNumberCtrl.clear();
        _expiryCtrl.clear();
        _cvvCtrl.clear();
        setState(() => _showAddCard = false);
        await _loadWallet();
      } else {
        final d = jsonDecode(r.body);
        _snack(d['message'] ?? 'Failed to add card', isError: true);
      }
    } catch (e) {
      _snack('Network error', isError: true);
    }
    setState(() => _addingCard = false);
  }

  Future<void> _pay() async {
    if (_selectedCardId == null && _cards.isNotEmpty) {
      _snack('Please select a card', isError: true);
      return;
    }
    if (_walletBalance < widget.amount) {
      _snack(
        'Insufficient balance. You have PKR ${_walletBalance.toStringAsFixed(0)} but need PKR ${widget.amount.toStringAsFixed(0)}',
        isError: true,
      );
      return;
    }

    setState(() => _isPaying = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final r = await http.post(
        Uri.parse(ApiConfig.WALLET_PAY),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({
          'bookingId': widget.bookingId,
          if (_selectedCardId != null) 'cardId': _selectedCardId,
        }),
      );
      if (r.statusCode == 200) {
        widget.onSuccess();
      } else {
        final d = jsonDecode(r.body);
        _snack(d['message'] ?? 'Payment failed', isError: true);
      }
    } catch (_) {
      _snack('Network error', isError: true);
    }
    setState(() => _isPaying = false);
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  // ── Card type icon ──────────────────────────────────────────────────────────
  Widget _cardTypeIcon(String? type) {
    if (type == 'VISA') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F71),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('VISA',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      );
    }
    if (type == 'MASTERCARD') {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 18, height: 18, decoration: const BoxDecoration(color: Color(0xFFEB001B), shape: BoxShape.circle)),
        Transform.translate(
          offset: const Offset(-6, 0),
          child: Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFFF79E1B).withOpacity(0.9), shape: BoxShape.circle)),
        ),
      ]);
    }
    return const Icon(Icons.credit_card, size: 20, color: Colors.grey);
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
        title: const Text('Secure Payment', style: AppTextStyles.headingSmall),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Order summary ─────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Summary',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(widget.packageTitle,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Amount Due',
                                style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Text('PKR ${widget.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Wallet balance ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _walletBalance >= widget.amount
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Wallet Balance',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('PKR ${_walletBalance.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: _walletBalance >= widget.amount
                                        ? Colors.green.shade700
                                        : Colors.red,
                                  )),
                            ],
                          ),
                        ),
                        if (_walletBalance < widget.amount)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Insufficient',
                                style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Saved cards ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Card',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      TextButton.icon(
                        onPressed: () => setState(() => _showAddCard = !_showAddCard),
                        icon: Icon(_showAddCard ? Icons.close : Icons.add, size: 16),
                        label: Text(_showAddCard ? 'Cancel' : 'Add Card'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_cards.isEmpty && !_showAddCard)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('No card saved. Add a card to pay.',
                                style: TextStyle(color: Colors.orange)),
                          ),
                        ],
                      ),
                    ),

                  // Card list
                  ..._cards.map((card) {
                    final isSelected = _selectedCardId == card['_id'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCardId = card['_id']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : const Color(0xFFEEEEEE),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            _cardTypeIcon(card['cardType']),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(card['cardHolderName'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('•••• •••• •••• ${card['last4']}',
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.grey, letterSpacing: 1)),
                                  Text('Expires ${card['expiryMonth']}/${card['expiryYear']}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            if (card['isDefault'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Default',
                                    style: TextStyle(
                                        color: Colors.green, fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            const SizedBox(width: 8),
                            Radio<String>(
                              value: card['_id'],
                              groupValue: _selectedCardId,
                              onChanged: (v) => setState(() => _selectedCardId = v),
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // ── Add card form ─────────────────────────────────────────
                  if (_showAddCard) ...[
                    const SizedBox(height: 8),
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
                          const Text('Add New Card',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 16),
                          _field('Card Holder Name', _cardHolderCtrl,
                              hint: 'John Doe',
                              inputType: TextInputType.name),
                          const SizedBox(height: 12),
                          _field('Card Number', _cardNumberCtrl,
                              hint: '1234 5678 9012 3456',
                              inputType: TextInputType.number,
                              formatter: _CardNumberFormatter()),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _field('Expiry (MM/YY)', _expiryCtrl,
                                    hint: '12/26',
                                    inputType: TextInputType.number,
                                    formatter: _ExpiryFormatter()),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field('CVV', _cvvCtrl,
                                    hint: '•••',
                                    inputType: TextInputType.number,
                                    obscure: true,
                                    maxLen: 4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: _setDefault,
                                onChanged: (v) => setState(() => _setDefault = v ?? true),
                                activeColor: AppColors.primary,
                              ),
                              const Text('Set as default card'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _addingCard ? null : _addCard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _addingCard
                                  ? const SizedBox(
                                      height: 20, width: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('Save Card',
                                      style: TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Pay button ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isPaying ||
                              _walletBalance < widget.amount ||
                              (_cards.isEmpty && !_showAddCard))
                          ? null
                          : _pay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isPaying
                          ? const SizedBox(
                              height: 22, width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              'Pay PKR ${widget.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Secured mock payment — no real money involved',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType inputType = TextInputType.text,
    TextInputFormatter? formatter,
    bool obscure = false,
    int? maxLen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: inputType,
          obscureText: obscure,
          maxLength: maxLen,
          inputFormatters: formatter != null ? [formatter] : null,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
      ],
    );
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
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 2) return next.copyWith(text: digits);
    final str = '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(0, 4))}';
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
