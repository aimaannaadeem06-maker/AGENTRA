import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cnicController = TextEditingController();
  final _licenseController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _emailController.dispose();
    _cnicController.dispose();
    _licenseController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF7F8F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 18, color: Color(0xFF1B1E28)),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Title
                const Text(
                  'Sign up now',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B1E28),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please fill the details and create account',
                  style: TextStyle(
                    color: Color(0xFF7D848D),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Fields
                CustomInput(
                  controller: _nameController,
                  hint: 'Name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _businessNameController,
                  hint: 'Business Name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Business name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _emailController,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    // Email regex validation
                    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _cnicController,
                  hint: 'CNIC (XXXXX-XXXXXXX-X)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'CNIC is required';
                    }
                    // Pakistani CNIC format: XXXXX-XXXXXXX-X
                    final cnicRegex = RegExp(r'^\d{5}-\d{7}-\d$');
                    if (!cnicRegex.hasMatch(value.trim())) {
                      return 'Invalid CNIC. Use format: XXXXX-XXXXXXX-X';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _licenseController,
                  hint: 'Licence number',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'License number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _contactController,
                  hint: 'Contact Number (03XX-XXXXXXX)',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Contact number is required';
                    }
                    // Pakistani phone format: 03XX-XXXXXXX or +923XX-XXXXXXX
                    final phoneRegex = RegExp(r'^(\+92|0)?3\d{2}-?\d{7}$');
                    if (!phoneRegex
                        .hasMatch(value.trim().replaceAll(' ', ''))) {
                      return 'Invalid phone. Use format: 03XX-XXXXXXX';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _passwordController,
                  hint: '**********',
                  isPassword: true,
                  validator: validateStrongPassword,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 10, left: 4),
                  child: Text(
                    'Password must be at least 8 characters long and include uppercase, lowercase, number, and special character.',
                    style: TextStyle(
                      color: Color(0xFF7D848D),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Sign Up Button
                SizedBox(
                  height: 64,
                  child: CustomButton(
                    text: 'Sign Up',
                    onPressed: _handleSignup,
                    isLoading: _isLoading,
                  ),
                ),
                const SizedBox(height: 32),
                // Sign in link
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Color(0xFF7D848D),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        // Navigate to Owner Login Screen
                        Navigator.pushNamed(context, '/owner-login');
                      },
                      child: const Text(
                        'SIGN IN AS AN OWNER',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final result = await AuthService.register(
        fullName: _nameController.text.trim(),
        businessName: _businessNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _contactController.text.trim(),
        cnic: _cnicController.text.trim(),
        password: _passwordController.text,
        licenseNumber: _licenseController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          // Show success message for pending approval
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Account Created Successfully'),
              content: const Text('Your account request has been submitted. '
                  'Please wait for Owner approval. This may take up to 24 hours.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );

          // Navigate back to login screen (don't auto-login)
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Registration failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
