import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../widgets/custom_input.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../config/api_config.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _contactController;
  bool _isLoading = true;
  bool _isSaving = false;
  User? _currentUser;
  String? _newProfileImageUrl; // holds URL after upload

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _locationController = TextEditingController();
    _contactController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        if (user != null) {
          _nameController.text = user.fullName;
          _contactController.text = user.phone ?? '';
          // Location isn't in User model yet, using placeholder or could add to model
          _locationController.text = 'Pakistan';
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      // Build update body — include profileImage if changed
      final updateBody = <String, dynamic>{
        'fullName': _nameController.text.trim(),
        'phone': _contactController.text.trim(),
      };
      if (_newProfileImageUrl != null) {
        updateBody['profileImage'] = _newProfileImageUrl;
      }

      // Call updateProfile with extended body via direct HTTP
      final token = await AuthService.getToken();
      bool success = false;
      if (token != null) {
        try {
          final response = await http.put(
            Uri.parse(ApiConfig.UPDATE_PROFILE),
            headers: {
              'Content-Type': 'application/json',
              'x-auth-token': token,
            },
            body: jsonEncode(updateBody),
          );
          if (response.statusCode == 200) {
            // Clear cached user so it reloads fresh
            AuthService.clearCache();
            success = true;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update profile'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isSaving = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      // Read bytes — works on all platforms (Web, Windows, Android, iOS)
      // fromPath() uses dart:io which is not available on Flutter Web
      final bytes = await picked.readAsBytes();
      final filename = picked.name.isNotEmpty ? picked.name : 'profile.jpg';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.UPLOAD_IMAGE),
      );
      request.headers['x-auth-token'] = token;
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: filename,
        ),
      );

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      final data = jsonDecode(body);

      if (streamed.statusCode == 200 && data['success'] == true) {
        setState(() {
          _newProfileImageUrl = data['url'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded. Tap Done to save.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Image upload failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.backgroundLight,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 18, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Edit Profile',
          style:
              AppTextStyles.headingSmall.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text(
                    'Done',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFD5C0),
                          image: DecorationImage(
                            image: (_newProfileImageUrl != null &&
                                    _newProfileImageUrl!.isNotEmpty)
                                ? NetworkImage(ApiConfig.getImageUrl(
                                    _newProfileImageUrl!)) as ImageProvider
                                : (_currentUser?.profileImage != null &&
                                        _currentUser!.profileImage!.isNotEmpty)
                                    ? NetworkImage(ApiConfig.getImageUrl(
                                            _currentUser!.profileImage!))
                                        as ImageProvider
                                    : const NetworkImage(
                                        'https://api.dicebear.com/7.x/avataaars/png?seed=Aiman'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUser?.fullName ?? 'User',
                        style: AppTextStyles.headingMedium.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: const Text(
                          'Change Profile Picture',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _buildFieldLabel('Name'),
                CustomInput(
                  controller: _nameController,
                  suffixIcon: _buildCheckIcon(),
                  validator: (val) => val == null || val.isEmpty
                      ? 'Name cannot be empty'
                      : null,
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Location'),
                CustomInput(
                  controller: _locationController,
                  suffixIcon: _buildCheckIcon(),
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Mobile Number'),
                CustomInput(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 20),
                        Text(
                          '+',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ),
                  ),
                  suffixIcon: _buildCheckIcon(),
                  validator: (val) => val == null || val.isEmpty
                      ? 'Phone cannot be empty'
                      : null,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildCheckIcon() {
    return const Icon(
      Icons.check,
      color: AppColors.primary,
      size: 20,
    );
  }
}
