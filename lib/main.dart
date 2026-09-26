import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/state_manager.dart';
import 'state/group_provider.dart';
import 'screen/splash_screen.dart';
import 'screen/Dashboard/dashboard_screen.dart';
import 'screen/authentication/login_screen.dart';
import 'screen/groups/invite_link_handler.dart';
import 'theme/app_theme.dart';
import 'utils/notification_service.dart';

void main() async {
  // Required: StateManager reads the saved auth token from SharedPreferences
  // in its constructor, and that platform channel is unusable until the
  // binding exists. Without this the read throws and the stored session is
  // silently discarded, sending signed-in users back to the login screen.
  WidgetsFlutterBinding.ensureInitialized();

  // Push notifications. Absent native config (no google-services.json /
  // GoogleService-Info.plist dropped in yet) throws here rather than
  // crashing the app — every push feature is then simply unavailable.
  try {
    await Firebase.initializeApp();
    await NotificationService.instance.initialize();
  } catch (e) {
    if (kDebugMode) print('[push] Firebase initialization failed: $e');
  }

  final stateManager = StateManager();
  final groupProvider = GroupProvider()
    // Keep the legacy expense/settle-up screens pointed at the real groups.
    ..onGroupsChanged = stateManager.syncGroupsFromApi;

  // Signing out must not leave the next user looking at someone else's groups.
  stateManager.onSignedOut = groupProvider.reset;

  // Keeps this device's push-topic subscription in step with whoever is
  // signed in — fires on every StateManager change, but syncSubscription()
  // is a no-op unless the signed-in user actually changed.
  stateManager.addListener(() {
    NotificationService.instance.syncSubscription(
      stateManager.isLoggedIn ? stateManager.currentUserId : null,
    );
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: stateManager),
        ChangeNotifierProvider.value(value: groupProvider),
      ],
      child: const SplitWiseApp(),
    ),
  );
}

/// Lets the deep-link handler push the join screen from anywhere in the app.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class SplitWiseApp extends StatelessWidget {
  const SplitWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'PaisaSplit',
      debugShowCheckedModeBanner: false,
      // Light theme only — the app has no dark mode.
      theme: AppTheme.lightTheme(),
      themeMode: ThemeMode.light,
      // The invite listener goes above the Navigator, not inside `home`:
      // the splash screen leaves via pushReplacement, which would dispose a
      // handler mounted as a route and take the link subscription with it.
      // Here it outlives every route and pushes via [appNavigatorKey].
      builder: (context, child) =>
          InviteLinkHandler(child: child ?? const SizedBox.shrink()),
      // Show splash screen first while initializing session
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
