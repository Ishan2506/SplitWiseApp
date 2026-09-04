import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/state_manager.dart';
import '../../screen/Dashboard/dashboard_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isAuthenticating = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin(StateManager state) async {
    setState(() {
      _isAuthenticating = true;
    });

    final success = await state.signInWithGoogle();

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryAccent,
            content: Text('Logged in with Google!'),
          ),
        );
        // Navigate to Dashboard after successful Google login
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
              (route) => false,
            );
          }
        });
      } else if (state.authErrorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(state.authErrorMessage!),
          ),
        );
      }
    }
  }

  Future<void> _handlePasswordLogin(StateManager state) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isAuthenticating = true;
    });

    final success = await state.loginWithIdentifierAndPassword(
      identifier: _identifierController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryAccent,
            content: Text('Logged in successfully!'),
          ),
        );
        // Navigate to Dashboard after successful login
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
              (route) => false,
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(state.authErrorMessage ?? 'Invalid credentials'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);

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
                    // Brand Logo
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A1512), // Your brand: #1A1512
                              AppColors.primaryAccent, // Your brand: #EE2B6C
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryAccent.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.currency_rupee,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Welcome Text
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Subtitle
                    Text(
                      'Sign in to keep your groups in sync.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Email/Mobile Input
                    PSTextField(
                      label: 'Email or Phone',
                      placeholder: 'Enter email or phone number',
                      controller: _identifierController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your email or mobile number';
                        }
                        final input = val.trim();
                        final emailRegex = RegExp(
                          r'^[a-zA-Z0-9][a-zA-Z0-9._%-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$',
                        );
                        final mobileRegex = RegExp(r'^[6-9]\d{9}$');

                        if (input.contains('@')) {
                          if (!emailRegex.hasMatch(input)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        }

                        if (input.length != 10) {
                          return 'Mobile number must be exactly 10 digits';
                        }
                        if (!mobileRegex.hasMatch(input)) {
                          return 'Mobile number must start with 6-9';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Password Input
                    PSTextField(
                      label: 'Password',
                      placeholder: 'Enter your password',
                      controller: _passwordController,
                      obscureText: true,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Sign In Button
                    PSButton(
                      label: 'Sign in',
                      onPressed: () => _handlePasswordLogin(state),
                      isLoading: _isAuthenticating,
                      isEnabled: !_isAuthenticating,
                      isPrimary: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Text(
                            'OR',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Google Sign-In Button
                    OutlinedButton.icon(
                      onPressed: _isAuthenticating ? null : () => _handleGoogleLogin(state),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                          horizontal: AppSpacing.lg,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(Icons.login, size: 20),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Sign Up Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Demo Mode
                    TextButton(
                      onPressed: () {
                        state.bypassLogin();
                      },
                      child: Text(
                        'Demo Mode (Mock Data)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.muted,
                              decoration: TextDecoration.underline,
                            ),
                      ),
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
