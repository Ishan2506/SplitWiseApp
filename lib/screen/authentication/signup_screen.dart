import 'package:flutter/material.dart';
import '../../network/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isAuthenticating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();

    setState(() {
      _isAuthenticating = true;
    });

    final result = await ApiService.register(
      name: _nameController.text.trim(),
      email: email.isNotEmpty ? email : null,
      mobileNumber: mobile.isNotEmpty ? mobile : null,
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please login.'),
            backgroundColor: AppColors.primaryAccent,
          ),
        );
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.0, -0.5),
            end: Alignment(0.0, 1.0),
            colors: [
              Color(0xFFFFE3EC), // Your HTML: #ffe3ec
              Color(0xFFFDF1F4), // Your HTML: #fdf1f4
              Color(0xFFFFFFFF), // Your HTML: #ffffff
            ],
            stops: [0.0, 0.42, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Title
                    Text(
                      'Create your account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Subtitle
                    Text(
                      'Join PaisaSplit and start splitting bills.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Name Input
                    PSTextField(
                      label: 'Full Name',
                      placeholder: 'Enter your name',
                      controller: _nameController,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Email Input
                    PSTextField(
                      label: 'Email (Optional)',
                      placeholder: 'Enter your email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final emailRegex = RegExp(
                            r'^[a-zA-Z0-9][a-zA-Z0-9._%-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$',
                          );
                          if (!emailRegex.hasMatch(val.trim())) {
                            return 'Enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Mobile Input
                    PSTextField(
                      label: 'Mobile (Optional)',
                      placeholder: '10 digits, e.g. 9876543210',
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final reg = RegExp(r'^[6-9]\d{9}$');
                          if (val.length != 10) {
                            return 'Mobile number must be exactly 10 digits';
                          }
                          if (!reg.hasMatch(val.trim())) {
                            return 'Mobile number must start with 6-9';
                          }
                        } else {
                          final email = _emailController.text.trim();
                          if (email.isEmpty) {
                            return 'Please provide email or mobile number';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Password Input
                    PSTextField(
                      label: 'Password',
                      placeholder: 'Create a strong password',
                      controller: _passwordController,
                      obscureText: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (val.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        final reg = RegExp(
                          r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#])[A-Za-z\d@$!%*?&#]{8,}$',
                        );
                        if (!reg.hasMatch(val)) {
                          return 'Must contain uppercase, lowercase, digit & special char';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Sign Up Button
                    PSButton(
                      label: 'Create Account',
                      onPressed: _handleSignup,
                      isLoading: _isAuthenticating,
                      isEnabled: !_isAuthenticating,
                      isPrimary: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Login Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryAccent,
                            ),
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
      ),
    );
  }
}
