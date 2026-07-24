import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../models/agent.dart';
import '../services/auth_service.dart';
import '../services/package_service.dart';
import '../config/api_config.dart';

class EditAgentProfileScreen extends StatefulWidget {
  const EditAgentProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditAgentProfileScreen> createState() => _EditAgentProfileScreenState();
}

class _EditAgentProfileScreenState extends State<EditAgentProfileScreen> {
  int _selectedNavIndex = 7;
  Agent? _agent;
  bool _isLoading = true;
  bool _isSaving = false;

  // Image
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late TextEditingController _businessNameController;
  late TextEditingController _locationController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _refundPolicyController;
  late TextEditingController _cancellationPolicyController;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _locationController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _refundPolicyController = TextEditingController();
    _cancellationPolicyController = TextEditingController();
    _loadAgent();
  }

  Future<void> _loadAgent() async {
    setState(() => _isLoading = true);
    final agent = await AuthService.getCurrentAgent();
    if (mounted && agent != null) {
      setState(() {
        _agent = agent;
        _businessNameController.text = agent.businessName;
        _locationController.text = agent.location ?? '';
        _phoneController.text = agent.phone;
        _emailController.text = agent.email;
        _refundPolicyController.text = agent.refundPolicy ?? '';
        _cancellationPolicyController.text = agent.cancellationPolicy ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _refundPolicyController.dispose();
    _cancellationPolicyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      // 1. Upload image first if a new one was selected
      String? imageUrl = _agent?.profileImage;
      if (_selectedImage != null) {
        final uploaded = await PackageService.uploadImage(_selectedImage!);
        if (uploaded != null) {
          imageUrl = uploaded;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image upload failed. Please try again.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      // 2. Save profile data including the new image URL
      final result = await AuthService.updateProfile({
        'businessName': _businessNameController.text.trim(),
        'location': _locationController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'refundPolicy': _refundPolicyController.text.trim(),
        'cancellationPolicy': _cancellationPolicyController.text.trim(),
        if (imageUrl != null && imageUrl.isNotEmpty) 'profileImage': imageUrl,
      });

      if (mounted) {
        setState(() => _isSaving = false);
        if (result['success'] == true) {
          // 3. Force-refresh the cached agent so side nav shows new photo
          await AuthService.refreshCurrentAgent();
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update profile'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 16),
                      const Text('Edit Profile',
                          style: AppTextStyles.headingMedium),
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
                              constraints: const BoxConstraints(maxWidth: 700),
                              child: Column(
                                children: [
                                  // ── Profile Picture ─────────────────
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
                                      children: [
                                        // Avatar
                                        GestureDetector(
                                          onTap: _pickImage,
                                          child: Stack(
                                            children: [
                                              CircleAvatar(
                                                radius: 60,
                                                backgroundColor: AppColors
                                                    .primary
                                                    .withOpacity(0.1),
                                                backgroundImage: _imageBytes !=
                                                        null
                                                    ? MemoryImage(_imageBytes!)
                                                        as ImageProvider
                                                    : (_agent?.profileImage !=
                                                                null &&
                                                            _agent!
                                                                .profileImage!
                                                                .isNotEmpty)
                                                        ? NetworkImage(ApiConfig
                                                            .getImageUrl(_agent!
                                                                .profileImage!))
                                                        : null,
                                                onBackgroundImageError:
                                                    (_imageBytes == null &&
                                                            _agent?.profileImage !=
                                                                null &&
                                                            _agent!
                                                                .profileImage!
                                                                .isNotEmpty)
                                                        ? (_, __) {}
                                                        : null,
                                                child: _imageBytes == null &&
                                                        (_agent?.profileImage ==
                                                                null ||
                                                            _agent!
                                                                .profileImage!
                                                                .isEmpty)
                                                    ? Text(
                                                        _agent?.fullName[0]
                                                                .toUpperCase() ??
                                                            'A',
                                                        style: const TextStyle(
                                                          fontSize: 40,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                        color: Colors.white,
                                                        width: 2),
                                                  ),
                                                  child: const Icon(
                                                      Icons.camera_alt,
                                                      color: Colors.white,
                                                      size: 16),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: _pickImage,
                                          child: const Text(
                                            'Change Profile Picture',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Form Fields ─────────────────────
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Business Information',
                                          style: AppTextStyles.headingSmall
                                              .copyWith(fontSize: 18),
                                        ),
                                        const Divider(height: 32),
                                        CustomInput(
                                          label: 'Business Name',
                                          controller: _businessNameController,
                                          hint: 'e.g., Mind Travellers',
                                        ),
                                        const SizedBox(height: 20),
                                        CustomInput(
                                          label: 'Location',
                                          controller: _locationController,
                                          hint: 'e.g., Rawalpindi, Pakistan',
                                        ),
                                        const SizedBox(height: 20),
                                        CustomInput(
                                          label: 'Mobile Number',
                                          controller: _phoneController,
                                          hint: 'e.g., 03001234567',
                                          keyboardType: TextInputType.phone,
                                        ),
                                        const SizedBox(height: 20),
                                        CustomInput(
                                          label: 'Email',
                                          controller: _emailController,
                                          hint: 'e.g., agent@example.com',
                                          keyboardType:
                                              TextInputType.emailAddress,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Policies ────────────────────────
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Policies',
                                          style: AppTextStyles.headingSmall
                                              .copyWith(fontSize: 18),
                                        ),
                                        const Divider(height: 32),
                                        CustomInput(
                                          label: 'Refund Policy',
                                          controller: _refundPolicyController,
                                          hint:
                                              'Describe your refund policy...',
                                          maxLines: 4,
                                        ),
                                        const SizedBox(height: 20),
                                        CustomInput(
                                          label: 'Cancellation Policy',
                                          controller:
                                              _cancellationPolicyController,
                                          hint:
                                              'Describe your cancellation policy...',
                                          maxLines: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // ── Save Button ──────────────────────
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            side: const BorderSide(
                                                color: AppColors.border),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppDimensions.radius),
                                            ),
                                          ),
                                          child: const Text('Cancel',
                                              style: TextStyle(
                                                  color:
                                                      AppColors.textPrimary)),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: CustomButton(
                                          text: 'Save Changes',
                                          onPressed: _handleSave,
                                          isLoading: _isSaving,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
