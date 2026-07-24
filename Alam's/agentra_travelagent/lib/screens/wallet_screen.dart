import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _selectedNavIndex = 8;
  bool _isLoading = true;

  double _balance = 0;
  double _totalEarned = 0;
  double _totalWithdrawn = 0;
  double _totalEarnings = 0;     // gross (net + commission)
  double _totalCommission = 0;   // platform 5% deducted
  double _netEarnings = 0;       // agent keeps 95%
  double _pendingPayouts = 0;    // earnings not yet paid out
  List<Map<String, dynamic>> _cards = [];

  // Withdraw
  final _withdrawCtrl = TextEditingController();
  bool _withdrawing = false;

  // Add card form
  bool _showCardForm = false;
  final _holderCtrl  = TextEditingController();
  final _cardNumCtrl = TextEditingController();
  final _expiryCtrl  = TextEditingController();
  final _cvvCtrl     = TextEditingController();
  bool _addingCard   = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _withdrawCtrl.dispose();
    _holderCtrl.dispose();
    _cardNumCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  // -- Load wallet -----------------------------------------------------------
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/wallet'),
        headers: {'x-auth-token': token},
      );
      if (r.statusCode == 200) {
        final w = jsonDecode(r.body)['wallet'];
        setState(() {
          _balance        = (w['balance']        ?? 0).toDouble();
          _totalEarned    = (w['totalEarned']    ?? 0).toDouble();
          _totalWithdrawn = (w['totalWithdrawn'] ?? 0).toDouble();
          _totalEarnings  = (w['totalEarnings']  ?? 0).toDouble();
          _totalCommission= (w['totalCommission']?? 0).toDouble();
          _netEarnings    = (w['netEarnings']    ?? 0).toDouble();
          _pendingPayouts = (w['pendingPayouts'] ?? 0).toDouble();
          _cards          = List<Map<String, dynamic>>.from(w['cards'] ?? []);
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  // -- Withdraw --------------------------------------------------------------
  Future<void> _withdraw() async {
    final amt = double.tryParse(_withdrawCtrl.text.trim());
    if (amt == null || amt <= 0) {
      _snack('Enter a valid amount', err: true); return;
    }
    if (amt > _balance) {
      _snack('Insufficient balance', err: true); return;
    }
    if (_cards.isEmpty) {
      _snack('Add a card first to enable withdrawals', err: true); return;
    }
    setState(() => _withdrawing = true);
    try {
      final token = await AuthService.getToken();
      final r = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/wallet/withdraw'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token!},
        body: jsonEncode({'amount': amt}),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode == 200) {
        _withdrawCtrl.clear();
        _snack('PKR ${amt.toStringAsFixed(0)} withdrawn successfully');
        await _load();
      } else {
        _snack(d['message'] ?? 'Withdrawal failed', err: true);
      }
    } catch (_) {
      _snack('Network error', err: true);
    }
    setState(() => _withdrawing = false);
  }

  // -- Add card --------------------------------------------------------------
  Future<void> _addCard() async {
    final holder = _holderCtrl.text.trim();
    final number = _cardNumCtrl.text.replaceAll(' ', '');
    final expiry = _expiryCtrl.text.trim();
    final cvv    = _cvvCtrl.text.trim();

    if (holder.isEmpty) {
      _snack('Card holder name is required', err: true); return;
    }
    if (!RegExp(r'^[a-zA-Z\s]{2,50}$').hasMatch(holder)) {
      _snack('Card holder name: letters only (2�50 chars)', err: true); return;
    }
    if (number.length < 13 || number.length > 19 || !RegExp(r'^\d+$').hasMatch(number)) {
      _snack('Card number must be 13�19 digits', err: true); return;
    }
    if (expiry.length < 5) {
      _snack('Enter expiry as MM/YY', err: true); return;
    }
    final parts = expiry.split('/');
    if (parts.length != 2) {
      _snack('Expiry must be MM/YY', err: true); return;
    }
    final month = int.tryParse(parts[0]);
    final year  = int.tryParse('20${parts[1]}');
    if (month == null || month < 1 || month > 12) {
      _snack('Invalid expiry month (01�12)', err: true); return;
    }
    if (year == null) {
      _snack('Invalid expiry year', err: true); return;
    }
    final now = DateTime.now();
    if (DateTime(year, month).isBefore(DateTime(now.year, now.month))) {
      _snack('Card has expired', err: true); return;
    }
    if (!RegExp(r'^\d{3,4}$').hasMatch(cvv)) {
      _snack('CVV must be 3 or 4 digits', err: true); return;
    }

    setState(() => _addingCard = true);
    try {
      final token = await AuthService.getToken();
      final r = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/wallet/cards'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token!},
        body: jsonEncode({
          'cardHolderName': holder,
          'cardNumber':     number,
          'expiryMonth':    parts[0],
          'expiryYear':     '20${parts[1]}',
          'cvv':            cvv,
          'setDefault':     _cards.isEmpty,
        }),
      );
      if (r.statusCode == 201) {
        _snack('Card added successfully');
        _holderCtrl.clear();
        _cardNumCtrl.clear();
        _expiryCtrl.clear();
        _cvvCtrl.clear();
        setState(() => _showCardForm = false);
        await _load();
      } else {
        _snack(jsonDecode(r.body)['message'] ?? 'Failed to add card', err: true);
      }
    } catch (_) {
      _snack('Network error', err: true);
    }
    setState(() => _addingCard = false);
  }

  Future<void> _removeCard(String cardId) async {
    try {
      final token = await AuthService.getToken();
      await http.delete(
        Uri.parse('${ApiConfig.BASE_URL}/wallet/cards/$cardId'),
        headers: {'x-auth-token': token!},
      );
      await _load();
    } catch (_) {}
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? Colors.red : Colors.green,
    ));
  }

  // -- Build -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          SideNavigation(
            selectedIndex: _selectedNavIndex,
            onItemSelected: (i) => setState(() => _selectedNavIndex = i),
          ),
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('My Wallet', style: AppTextStyles.headingMedium),
                        Text('Manage earnings & withdrawals',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textTertiary)),
                      ]),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildBalanceCards(),
                                const SizedBox(height: 32),
                                _buildWithdrawSection(),
                                const SizedBox(height: 32),
                                _buildCardsSection(),
                              ],
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

  // -- Balance stat cards ----------------------------------------------------
  Widget _buildBalanceCards() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.8,
      children: [
        _statCard('Available Balance',
            'PKR ${_balance.toStringAsFixed(0)}',
            Icons.account_balance_wallet_outlined, Colors.green),
        _statCard('Gross Earnings',
            'PKR ${_totalEarnings.toStringAsFixed(0)}',
            Icons.trending_up, Colors.blue),
        _statCard('Platform Commission (5%)',
            'PKR ${_totalCommission.toStringAsFixed(0)}',
            Icons.percent_outlined, Colors.red),
        _statCard('Net Earnings (95%)',
            'PKR ${_netEarnings.toStringAsFixed(0)}',
            Icons.monetization_on_outlined, AppColors.primary),
        _statCard('Pending Payouts',
            'PKR ${_pendingPayouts.toStringAsFixed(0)}',
            Icons.hourglass_empty_outlined, Colors.orange),
        _statCard('Total Withdrawn',
            'PKR ${_totalWithdrawn.toStringAsFixed(0)}',
            Icons.arrow_upward, Colors.teal),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7D848D))),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
          ]),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  // -- Withdraw section ------------------------------------------------------
  Widget _buildWithdrawSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Withdraw Funds',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B1E28))),
        const SizedBox(height: 4),
        Text('Transfer your earnings to your card',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _withdrawCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter amount (PKR)',
                prefixText: 'PKR ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFEEEEEE))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFEEEEEE))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _withdrawing ? null : _withdraw,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _withdrawing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Withdraw',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
        ]),
        const SizedBox(height: 12),
        // Quick amount chips
        Wrap(
          spacing: 8,
          children: [5000, 10000, 25000, 50000]
              .map((amt) => ActionChip(
                    label: Text('PKR $amt'),
                    onPressed: () =>
                        setState(() => _withdrawCtrl.text = amt.toString()),
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                    labelStyle: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  // -- Cards section ---------------------------------------------------------
  Widget _buildCardsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Saved Cards',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1E28))),
          TextButton.icon(
            onPressed: () =>
                setState(() => _showCardForm = !_showCardForm),
            icon: Icon(_showCardForm ? Icons.close : Icons.add, size: 16),
            label: Text(_showCardForm ? 'Cancel' : 'Add Card'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ]),
        const SizedBox(height: 12),

        // Empty state
        if (_cards.isEmpty && !_showCardForm)
          Text('No cards saved. Add a card to enable withdrawals.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),

        // Card list
        ...List<Widget>.from(
          _cards.map(
            (c) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(children: [
                const Icon(Icons.credit_card, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['cardHolderName'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(
                            '���� ���� ���� ${c['last4']}  |  ${c['cardType']}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        Text(
                            'Expires ${c['expiryMonth']}/${c['expiryYear']}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ]),
                ),
                if (c['isDefault'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Default',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => _removeCard(c['_id']),
                ),
              ]),
            )),

        // Add card form
        if (_showCardForm) ...[
          const SizedBox(height: 8),
          _inputField('Card Holder Name', _holderCtrl, hint: 'John Doe'),
          const SizedBox(height: 12),
          _inputField('Card Number', _cardNumCtrl,
              hint: '1234 5678 9012 3456',
              type: TextInputType.number,
              formatter: _CardNumberFormatter()),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _inputField('Expiry MM/YY', _expiryCtrl,
                  hint: '12/26',
                  type: TextInputType.number,
                  formatter: _ExpiryFormatter()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField('CVV', _cvvCtrl,
                  hint: '���',
                  type: TextInputType.number,
                  obscure: true,
                  maxLen: 4),
            ),
          ]),
          const SizedBox(height: 16),
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
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Card',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    );
  }

  // -- Input field helper ----------------------------------------------------
  Widget _inputField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType type = TextInputType.text,
    TextInputFormatter? formatter,
    bool obscure = false,
    int? maxLen,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
        maxLength: maxLen,
        inputFormatters: formatter != null ? [formatter] : null,
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
        ),
      ),
    ]);
  }
}

// -- Formatters ----------------------------------------------------------------

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue o, TextEditingValue n) {
    final d = n.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < d.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(d[i]);
    }
    final s = buf.toString();
    return TextEditingValue(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue o, TextEditingValue n) {
    final d = n.text.replaceAll(RegExp(r'\D'), '');
    if (d.length <= 2) return n.copyWith(text: d);
    final s =
        '${d.substring(0, 2)}/${d.substring(2, d.length.clamp(0, 4))}';
    return TextEditingValue(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
