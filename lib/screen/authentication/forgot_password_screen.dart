import 'package:flutter/material.dart';
import '../../network/api_service.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'auth_widgets.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final result = await ApiService.forgotPassword(email: email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      showAppSnack(context, 'Reset code sent to $email');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(email: email),
        ),
      );
    } else {
      setState(() =>
          _errorMessage = result['message'] ?? 'Failed to send reset link');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Reset your password',
      subtitle:
          'Enter the email on your account and we will send you a code to set '
          'a new password.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                AuthErrorBanner(message: _errorMessage!),
              PSTextField(
                label: 'Email',
                placeholder: 'you@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                autofocus: true,
                textInputAction: TextInputAction.done,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  final emailRegex = RegExp(
                    r'^[a-zA-Z0-9][a-zA-Z0-9._%-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$',
                  );
                  if (!emailRegex.hasMatch(val.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              PSButton(
                label: 'Send reset code',
                onPressed: _isLoading ? null : _handleForgotPassword,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
