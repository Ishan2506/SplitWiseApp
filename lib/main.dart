import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/state_manager.dart';
import 'screen/Dashboard/dashboard_screen.dart';
import 'screen/authentication/login_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => StateManager(),
      child: const SplitWiseApp(),
    ),
  );
}

class SplitWiseApp extends StatelessWidget {
  const SplitWiseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    return MaterialApp(
      title: 'Splitwise App Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF0D9488),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0D9488),
          secondary: Color(0xFF14B8A6),
          background: Color(0xFF0F172A),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: state.isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}

