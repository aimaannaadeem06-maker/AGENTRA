import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({Key? key}) : super(key: key);

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  int _selectedNavIndex = 10;
  bool _isLoading = false;

  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  // Attachment
  XFile? _attachment;
  Uint8List? _attachmentBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final agent = await AuthService.getCurrentAgent();
    if (agent != null && mounted) {
      _emailController.text = agent.email;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _attachment = file;
        _attachmentBytes = bytes;
      });
    }
  }

  Future<void> _submitComplaint() async {
    if (_subjectController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/complaints/agent'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'subject': _subjectController.text.trim(),
          'description': _descriptionController.text.trim(),
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) _showSuccessDialog();
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to submit complaint'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(40),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Green checkmark
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'Submitted Successfully',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1E28),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your complaint is submitted to the Owner. You will get an email response within 5-6 days.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7D848D),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Clear form
                    _subjectController.clear();
                    _descriptionController.clear();
                    setState(() {
                      _attachment = null;
                      _attachmentBytes = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Okay',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom:
                          BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('File a Complaint',
                          style: AppTextStyles.headingMedium),
                      const Spacer(),
                      Text(
                        'We will respond within 5-6 business days',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: Container(
                          padding: const EdgeInsets.all(40),
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
                              // Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.error
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.report_outlined,
                                        color: AppColors.error,
                                        size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'File your Complaint',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1B1E28),
                                        ),
                                      ),
                                      Text(
                                        'Tell us what went wrong and we\'ll look into it',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF7D848D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              const Divider(),
                              const SizedBox(height: 24),

                              // Subject
                              CustomInput(
                                label: 'Subject',
                                controller: _subjectController,
                                hint: 'e.g., Issue with booking payment',
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 20),

                              // Description
                              CustomInput(
                                label: 'Description',
                                controller: _descriptionController,
                                hint:
                                    'Describe your complaint in detail...',
                                maxLines: 5,
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 20),

                              // Attachment
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attachments (Optional)',
                                    style:
                                        AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _pickAttachment,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundLight,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppColors.border),
                                      ),
                                      child: _attachmentBytes != null
                                          ? Row(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(8),
                                                  child: Image.memory(
                                                    _attachmentBytes!,
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _attachment!.name,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(
                                                          0xFF4A4A4A),
                                                    ),
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.close,
                                                      color: Colors.red,
                                                      size: 20),
                                                  onPressed: () =>
                                                      setState(() {
                                                    _attachment = null;
                                                    _attachmentBytes =
                                                        null;
                                                  }),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .center,
                                              children: [
                                                const Icon(
                                                    Icons
                                                        .attach_file_outlined,
                                                    color: AppColors
                                                        .textTertiary),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Click to attach a file or screenshot',
                                                  style: AppTextStyles
                                                      .bodySmall
                                                      .copyWith(
                                                    color: AppColors
                                                        .textTertiary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Email
                              CustomInput(
                                label: 'Your Email ID',
                                controller: _emailController,
                                hint: 'e.g., agent@example.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 32),

                              // Submit button
                              SizedBox(
                                width: double.infinity,
                                child: CustomButton(
                                  text: 'Submit Complaint',
                                  onPressed: _submitComplaint,
                                  isLoading: _isLoading,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}
