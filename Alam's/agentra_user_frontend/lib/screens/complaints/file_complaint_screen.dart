import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';
import '../../config/api_config.dart';

class FileComplaintScreen extends StatefulWidget {
  const FileComplaintScreen({super.key});
  @override
  State<FileComplaintScreen> createState() => _FileComplaintScreenState();
}

class _FileComplaintScreenState extends State<FileComplaintScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();

  List<Booking> _bookings    = [];
  String? _selectedBookingId;
  bool _isLoading    = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    final bookings = await BookingService.getMyBookings();
    if (mounted) {
      setState(() {
        _bookings = bookings
            .where((b) =>
                b.status.toLowerCase() == 'confirmed' ||
                b.status.toLowerCase() == 'completed' ||
                b.status.toLowerCase() == 'cancelled')
            .toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBookingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a booking')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final r = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/users/complaints'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'bookingId':   _selectedBookingId,
          'subject':     _subjectCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
        }),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (r.statusCode == 200 || r.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Complaint submitted. Admin will review and forward it to the travel agent.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.pop(context, true);
        } else {
          final d = jsonDecode(r.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(d['message'] ?? 'Failed to submit complaint'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Network error. Please try again.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
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
        title: const Text('File a Complaint', style: AppTextStyles.headingSmall),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Info note — no icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFCFFF)),
                    ),
                    child: const Text(
                      'Your complaint will be sent to the admin. The admin will review it and forward it to the travel agent. You will be notified once it is resolved.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF3B5BDB),
                          height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Booking selector
                  const Text('Select Booking',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_bookings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'No bookings found. You need at least one booking to file a complaint.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBookingId,
                      isExpanded: true,
                      decoration: _inputDec('Select a booking'),
                      items: _bookings.map((b) {
                        final title =
                            (b.packageTitle.isNotEmpty &&
                                    b.packageTitle != 'Unknown Package')
                                ? b.packageTitle
                                : 'Booking — PKR ${b.totalPrice.toStringAsFixed(0)}';
                        return DropdownMenuItem<String>(
                          value: b.id,
                          child: Text(
                            '$title  (${b.status})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedBookingId = v),
                      validator: (v) =>
                          v == null ? 'Please select a booking' : null,
                    ),
                  const SizedBox(height: 20),

                  // Subject
                  const Text('Subject',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _subjectCtrl,
                    decoration: _inputDec(
                        'e.g., Poor service, Misleading package details'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Subject is required'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // Description
                  const Text('Description',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 5,
                    decoration:
                        _inputDec('Describe your issue in detail...'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Description is required'
                        : null,
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || _bookings.isEmpty)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('Submit Complaint',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
