import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/state_manager.dart';
import 'state/group_provider.dart';
import 'screen/splash_screen.dart';
import 'screen/Dashboard/dashboard_screen.dart';
import 'screen/authentication/login_screen.dart';
import 'screen/groups/invite_link_handler.dart';
import 'theme/app_theme.dart';

void main() {
  final stateManager = StateManager();
  final groupProvider = GroupProvider()
    // Keep the legacy expense/settle-up screens pointed at the real groups.
    ..onGroupsChanged = stateManager.syncGroupsFromApi;

  // Signing out must not leave the next user looking at someone else's groups.
  stateManager.onSignedOut = groupProvider.reset;

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
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      // Show splash screen first while initializing session
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
