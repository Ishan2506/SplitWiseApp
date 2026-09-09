import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

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
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  Future<void> _navigateAfterSplash() async {
    final state = Provider.of<StateManager>(context, listen: false);

    // Hold the splash for the branding animation and for the restore of any
    // stored session. Routing on the timer alone would send an already
    // signed-in user to login whenever `/auth/me` was slow to answer.
    //
    // Every wait here is failure-proof on purpose: whatever goes wrong, we
    // must still navigate, or the user is stranded on the splash screen.
    await Future.delayed(const Duration(milliseconds: 1800));

    try {
      // Longer than the 10s bound on the /auth/me request itself, so the
      // normal slow-network path resolves cleanly; this is the last-resort
      // guard against a future await that never completes.
      await state.sessionRestored.timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Waiting for session restore failed: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      state.isLoggedIn ? '/dashboard' : '/login',
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppBreakpoints.pagePadding(context)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/paisasplit_icon.png',
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Share the bill,\nnot the stress',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      'Add an expense in seconds. PaisaSplit keeps track of who '
                      'paid, who owes, and how to square up.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
