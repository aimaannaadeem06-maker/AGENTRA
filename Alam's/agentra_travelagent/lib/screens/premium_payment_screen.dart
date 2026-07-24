import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../widgets/custom_input.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class PremiumPaymentScreen extends StatefulWidget {
  const PremiumPaymentScreen({Key? key}) : super(key: key);

  @override
  State<PremiumPaymentScreen> createState() => _PremiumPaymentScreenState();
}

class _PremiumPaymentScreenState extends State<PremiumPaymentScreen> {
  int _selectedNavIndex = 6;
  final String _selectedPaymentMethod = 'CARD';
  int _selectedPlan = 0;
  int _currentStep = 0; // 0 = Select Plan, 1 = Payment
  bool _isLoading = true;
  bool _isAlreadyPro = false;
  String _currentPlan = '';

  // Card controllers
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentSubscription();
  }

  Future<void> _loadCurrentSubscription() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/subscription/current'),
        headers: {'x-auth-token': token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sub = data['subscription'];
        if (mounted) {
          setState(() {
            _isAlreadyPro = sub['isActive'] ?? false;
            _currentPlan = sub['plan'] ?? '';
          });
        }
      }
      // 404 = no subscription yet → stays FREE, not an error
    } catch (_) {
      // Network error — silently stay on FREE plan UI
    }
    if (mounted) setState(() => _isLoading = false);
  }

  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'Monthly',
      'price': 1000,
      'period': 'month',
      'saving': null,
      'features': [
        'Promote your packages to users',
        'Email + in-app promotions',
        'AI Chatbot for customer inquiries',
        'Full AI Sales Agent access',
        '24/7 automated support',
      ],
    },
  ];

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  bool _isValidCardHolder(String name) {
    final clean = name.trim();
    if (clean.length < 2) return false;
    return RegExp(r'^[a-zA-Z\s]+$').hasMatch(clean);
  }

  bool _isValidLuhn(String cardNumber) {
    final clean = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (clean.length != 16 || !RegExp(r'^\d+$').hasMatch(clean)) {
      return false;
    }
    int sum = 0;
    bool alternate = false;
    for (int i = clean.length - 1; i >= 0; i--) {
      int digit = int.parse(clean[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  bool _isValidExpiry(String expiry) {
    final clean = expiry.trim();
    final regex = RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$');
    if (!regex.hasMatch(clean)) return false;
    final parts = clean.split('/');
    final month = int.parse(parts[0]);
    final year = int.parse('20${parts[1]}');

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    if (year < currentYear) return false;
    if (year == currentYear && month < currentMonth) return false;
    return true;
  }

  bool _isValidCvv(String cvv) {
    final clean = cvv.trim();
    return RegExp(r'^[0-9]{3,4}$').hasMatch(clean);
  }

  void _handlePayNow() async {
    final holder = _cardHolderController.text.trim();
    final number = _cardNumberController.text.trim();
    final expiry = _cardExpiryController.text.trim();
    final cvv = _cardCvvController.text.trim();

    if (holder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Card Holder Name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isValidCardHolder(holder)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cardholder name must contain letters and spaces only (min 2 chars)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter 16-digit Card Number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isValidLuhn(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid 16-digit card number. Please verify your card.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (expiry.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Expiry Date (MM/YY)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isValidExpiry(expiry)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid or expired card date. Use MM/YY format with future date.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (cvv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter CVV'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isValidCvv(cvv)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CVV must be 3 or 4 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Simulate payment (2s delay)
      await Future.delayed(const Duration(seconds: 2));
      final result = {
        'success': true,
        'reference': 'REF-${DateTime.now().millisecondsSinceEpoch}'
      };

      // Step 2: Save subscription to backend
      final planName = _plans[0]['name'].toString().toUpperCase();
      final token = await AuthService.getToken();

      if (token == null) {
        if (mounted) setState(() => _isLoading = false);
        _showFailureDialog(
            'AUTH_ERROR', 'Session expired. Please log in again.');
        return;
      }

      final subResponse = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/subscription/subscribe'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'plan': planName,
          'paymentMethod': _selectedPaymentMethod,
        }),
      );

      if (mounted) setState(() => _isLoading = false);

      if (subResponse.statusCode == 201 || subResponse.statusCode == 200) {
        _showSuccessDialog(result['reference'] as String);
      } else {
        final errData = jsonDecode(subResponse.body);
        _showFailureDialog(
          'SERVER_ERROR',
          errData['message'] ??
              'Subscription activation failed. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showFailureDialog(
        'NETWORK_ERROR',
        'Cannot connect to server. Make sure backend is running.',
      );
    }
  }

  void _showSuccessDialog(String bookingReference) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(40),
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1E28),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are now on the ${_plans[_selectedPlan]['name']} Premium Plan',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7D848D),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Booking Reference: $bookingReference',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7D848D),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/subscription');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go to Subscription',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFailureDialog(String errorCode, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(40),
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Failed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1E28),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7D848D),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Error Code: $errorCode',
                style: const TextStyle(
                  color: Color(0xFF7D848D),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          SideNavigation(
            selectedIndex: _selectedNavIndex,
            onItemSelected: (index) =>
                setState(() => _selectedNavIndex = index),
          ),
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          if (_currentStep == 1) {
                            setState(() => _currentStep = 0);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _currentStep == 0 ? 'Premium Subscription' : 'Payment',
                        style: AppTextStyles.headingMedium,
                      ),
                      const Spacer(),
                      // Step indicator
                      Row(
                        children: [
                          _buildStepIndicator(
                              1, 'Select Plan', _currentStep >= 0),
                          Container(
                            width: 40,
                            height: 2,
                            color: _currentStep >= 1
                                ? AppColors.primary
                                : const Color(0xFFEEEEEE),
                          ),
                          _buildStepIndicator(2, 'Payment', _currentStep >= 1),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: _isAlreadyPro
                                  ? _buildAlreadyProStatus()
                                  : (_currentStep == 0
                                      ? _buildSelectPlanStep()
                                      : _buildPaymentStep()),
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

  Widget _buildSelectPlanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subscription Plan',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1B1E28),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Unlock AI Sales Agent and 24/7 customer support chatbot',
          style: TextStyle(color: Color(0xFF7D848D), fontSize: 16),
        ),
        const SizedBox(height: 32),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _buildPlanCard(0),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue to Payment',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(int index) {
    final plan = _plans[index];

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan['name'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Text(
                  '${plan['price']}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  ' PKR/${plan['period']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            ...(plan['features'] as List<String>).map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedPlan = index;
                    _currentStep = 1;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Subscribe',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStep() {
    final plan = _plans[0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order summary
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium,
                  color: AppColors.primary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plan['name']} Premium Plan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1B1E28),
                      ),
                    ),
                    Text(
                      'PKR ${plan['price']} / ${plan['period']}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Change'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Payment form
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.credit_card, color: AppColors.primary, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Card Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CustomInput(
                label: 'Card Holder Name',
                controller: _cardHolderController,
                hint: 'JOHN DOE',
              ),
              const SizedBox(height: 20),
              CustomInput(
                label: 'Card Number',
                controller: _cardNumberController,
                hint: 'XXXX XXXX XXXX XXXX',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CustomInput(
                      label: 'Expiry Date',
                      controller: _cardExpiryController,
                      hint: 'MM/YY',
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomInput(
                      label: 'CVV',
                      controller: _cardCvvController,
                      hint: '123',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '🔐 Your payment is secured with 256-bit SSL encryption',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7D848D),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePayNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Pay PKR ${plan['price']} Now',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlreadyProStatus() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 2),
          ),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade700, Colors.orange.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.workspace_premium,
                    color: Colors.white, size: 60),
              ),
              const SizedBox(height: 32),
              const Text(
                'Pro Premium Status',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1E28),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'ACTIVE: ${_currentPlan == 'YEARLY' ? 'Annual Plan' : 'Monthly Plan'}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'You have full access to all AI tools and premium features. Your subscription is active and working perfectly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7D848D),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/subscription'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Manage Subscription',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : const Color(0xFFEEEEEE),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF7D848D),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppColors.primary : const Color(0xFF7D848D),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
