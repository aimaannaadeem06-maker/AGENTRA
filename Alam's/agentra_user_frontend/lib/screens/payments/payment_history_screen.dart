import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/payment_service.dart';
import '../../models/payment.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Payment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    final payments = await PaymentService.getPaymentHistory();
    if (mounted) {
      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    }
  }

  double get _totalPaid => _payments
      .where((p) => p.status.toUpperCase() != 'REFUNDED')
      .fold(0.0, (sum, p) => sum + p.amount);

  double get _totalRefunded => _payments
      .where((p) => p.status.toUpperCase() == 'REFUNDED')
      .fold(0.0, (sum, p) => sum + p.amount);

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
          'Payment History',
          style: AppTextStyles.headingSmall,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPayments,
              child: _payments.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 64, color: Colors.black26),
                          SizedBox(height: 16),
                          Text('No payment history yet',
                              style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        // Summary cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                  'Total Paid',
                                  'PKR ${_totalPaid.toStringAsFixed(0)}',
                                  AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                  'Refunded',
                                  'PKR ${_totalRefunded.toStringAsFixed(0)}',
                                  AppColors.success),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Transactions',
                            style: AppTextStyles.headingSmall),
                        const SizedBox(height: 12),
                        ..._payments.map((p) => _buildPaymentTile(p)),
                      ],
                    ),
            ),
    );
  }

  Widget _buildSummaryCard(String label, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(amount,
              style: AppTextStyles.headingSmall.copyWith(
                color: color,
                fontSize: 20,
              )),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(Payment payment) {
    final isRefunded = payment.status.toUpperCase() == 'REFUNDED';
    final isPaid = payment.status.toUpperCase() == 'PAID' ||
        payment.status.toUpperCase() == 'PENDING';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isRefunded
                  ? Colors.green.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                payment.getMethodIcon(),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.paymentMethod,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (payment.transactionId != null &&
                    payment.transactionId!.isNotEmpty)
                  Text(
                    'TX: ${payment.transactionId}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                Text(
                  '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${payment.amount.toStringAsFixed(0)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isRefunded ? Colors.green : AppColors.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRefunded
                      ? Colors.green.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isRefunded ? 'Refunded' : 'Paid',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isRefunded ? Colors.green : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
