import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import 'authentication/login_screen.dart';
import 'Dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _navigateAfterSplash();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final state = Provider.of<StateManager>(context, listen: false);

    if (state.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
              Color(0xFFFFE3EC), // Soft pink
              Color(0xFFFDF1F4), // Light pink
              Color(0xFFFFFFFF), // White
            ],
            stops: [0.0, 0.42, 1.0],
          ),
        ),
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Icon
                      Container(
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
                      const SizedBox(height: 32),

                      // App Name
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.02,
                          ),
                          children: [
                            TextSpan(
                              text: 'Paisa',
                              style: TextStyle(color: Color(0xFF1A1512)), // Your brand: #1A1512
                            ),
                            TextSpan(
                              text: 'Split',
                              style:
                                  TextStyle(color: AppColors.primaryAccent), // Your brand: #EE2B6C
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tagline
                      const Text(
                        'Share the bill,\nnot the stress',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1512), // Your brand: #1A1512
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subtitle
                      const Text(
                        'Add an expense in seconds. PaisaSplit keeps track of who paid, who owes, and how to square up.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B5F56), // Your brand: #6B5F56
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Loading indicator
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryAccent,
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Loading text
                      const Text(
                        'Setting up your session...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B5F56), // Your brand: #6B5F56
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
