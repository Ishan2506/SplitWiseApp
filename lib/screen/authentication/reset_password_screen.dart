import 'package:flutter/material.dart';
import '../../network/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.resetPassword(
      email: widget.email,
      token: _tokenController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      showAppSnack(context, 'Password reset — please sign in');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else {
      setState(() =>
          _errorMessage = result['message'] ?? 'Failed to reset password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Set a new password',
      subtitle: 'Enter the code we sent and choose a new password.',
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  size: 17, color: AppColors.muted),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                AuthErrorBanner(message: _errorMessage!),
              PSTextField(
                label: 'Reset code',
                placeholder: 'Paste the code from your email',
                controller: _tokenController,
                enabled: !_isLoading,
                autofocus: true,
                textInputAction: TextInputAction.next,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter the reset code'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              PSTextField(
                label: 'New password',
                placeholder: 'Create a strong password',
                controller: _passwordController,
                obscureText: true,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter your new password';
                  }
                  if (val.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  final reg = RegExp(
                    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#])[A-Za-z\d@$!%*?&#]{8,}$',
                  );
                  if (!reg.hasMatch(val)) {
                    return 'Must contain 1 uppercase, 1 lowercase, 1 digit & 1 special char';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              PSTextField(
                label: 'Confirm password',
                placeholder: 'Re-enter your new password',
                controller: _confirmPasswordController,
                obscureText: true,
                enabled: !_isLoading,
                textInputAction: TextInputAction.done,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (val != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              PSButton(
                label: 'Reset password',
                onPressed: _isLoading ? null : _handleResetPassword,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
