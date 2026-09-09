import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/state_manager.dart';
import '../../screen/Dashboard/dashboard_screen.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'auth_widgets.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isAuthenticating = false;
  bool _isGoogleAuthenticating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _handleGoogleLogin(StateManager state) async {
    setState(() {
      _isGoogleAuthenticating = true;
      _errorMessage = null;
    });

    final success = await state.signInWithGoogle();
    if (!mounted) return;

    setState(() => _isGoogleAuthenticating = false);

    if (success) {
      _goToDashboard();
    } else {
      setState(() => _errorMessage =
          state.authErrorMessage ?? 'Could not sign in with Google');
    }
  }

  Future<void> _handlePasswordLogin(StateManager state) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final success = await state.loginWithIdentifierAndPassword(
      identifier: _identifierController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;

    setState(() => _isAuthenticating = false);

    if (success) {
      _goToDashboard();
    } else {
      setState(() =>
          _errorMessage = state.authErrorMessage ?? 'Invalid credentials');
    }
  }

  /// Accepts either an email address or a 10-digit Indian mobile number.
  String? _validateIdentifier(String? val) {
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
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    final busy = _isAuthenticating || _isGoogleAuthenticating;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to keep your groups in sync.',
      footer: AuthFooterPrompt(
        question: "Don't have an account?",
        action: 'Sign up',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SignupScreen()),
        ),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) AuthErrorBanner(message: _errorMessage!),
              PSTextField(
                label: 'Email or phone',
                placeholder: 'you@example.com',
                controller: _identifierController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !busy,
                validator: _validateIdentifier,
              ),
              const SizedBox(height: AppSpacing.md),
              PSTextField(
                label: 'Password',
                placeholder: 'Enter your password',
                controller: _passwordController,
                obscureText: true,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter your password'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                // A tap target that shrink-wraps its label; the default
                // TextButton min-width overflows a 320px screen here.
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          ),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PSButton(
                label: 'Sign in',
                onPressed:
                    busy ? null : () => _handlePasswordLogin(state),
                isLoading: _isAuthenticating,
              ),
              const SizedBox(height: AppSpacing.md),
              const AuthDivider(),
              const SizedBox(height: AppSpacing.md),
              GoogleButton(
                isLoading: _isGoogleAuthenticating,
                onPressed: busy ? null : () => _handleGoogleLogin(state),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
