import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../network/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

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
  String? _errorMessage;
  String _password = '';

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
      _errorMessage = null;
    });

    final result = await ApiService.register(
      name: _nameController.text.trim(),
      email: email.isNotEmpty ? email : null,
      mobileNumber: mobile.isNotEmpty ? mobile : null,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isAuthenticating = false);

    if (result['success'] == true) {
      showAppSnack(context, 'Account created — please sign in');
      Navigator.pop(context);
    } else {
      setState(() =>
          _errorMessage = result['message'] ?? 'Registration failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Create your account',
      subtitle: 'Join PaisaSplit and start splitting bills.',
      footer: AuthFooterPrompt(
        question: 'Already have an account?',
        action: 'Sign in',
        onTap: () => Navigator.pop(context),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                AuthErrorBanner(message: _errorMessage!),
              PSTextField(
                label: 'Full name',
                placeholder: 'Enter your name',
                controller: _nameController,
                enabled: !_isAuthenticating,
                textInputAction: TextInputAction.next,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              PSTextField(
                label: 'Email',
                placeholder: 'you@example.com',
                helperText: 'Email or mobile — at least one is required',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isAuthenticating,
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: AppSpacing.md),
              PSTextField(
                label: 'Mobile',
                placeholder: '9876543210',
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                enabled: !_isAuthenticating,
                maxLength: 10,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    final reg = RegExp(r'^[6-9]\d{9}$');
                    if (val.length != 10) {
                      return 'Mobile number must be exactly 10 digits';
                    }
                    if (!reg.hasMatch(val.trim())) {
                      return 'Mobile number must start with 6-9';
                    }
                  } else if (_emailController.text.trim().isEmpty) {
                    return 'Please provide email or mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              PSTextField(
                label: 'Password',
                placeholder: 'Create a strong password',
                controller: _passwordController,
                obscureText: true,
                enabled: !_isAuthenticating,
                textInputAction: TextInputAction.done,
                onChanged: (v) => setState(() => _password = v),
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
              const SizedBox(height: AppSpacing.sm),
              _PasswordChecklist(password: _password),
              const SizedBox(height: AppSpacing.lg),
              PSButton(
                label: 'Create account',
                onPressed: _isAuthenticating ? null : _handleSignup,
                isLoading: _isAuthenticating,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows the password rules as they are met, so the requirements are visible
/// before the user submits rather than only in an error message afterwards.
class _PasswordChecklist extends StatelessWidget {
  final String password;

  const _PasswordChecklist({required this.password});

  @override
  Widget build(BuildContext context) {
    final rules = <String, bool>{
      'At least 8 characters': password.length >= 8,
      'Upper & lowercase letter':
          RegExp(r'[a-z]').hasMatch(password) &&
              RegExp(r'[A-Z]').hasMatch(password),
      'A number': RegExp(r'\d').hasMatch(password),
      'A special character (@\$!%*?&#)':
          RegExp(r'[@$!%*?&#]').hasMatch(password),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in rules.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    entry.value
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 14,
                    color: entry.value ? AppColors.success : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: entry.value
                            ? AppColors.success
                            : AppColors.textTertiary,
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
