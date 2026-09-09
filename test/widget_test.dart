import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:splitwise_app/state/state_manager.dart';
import 'package:splitwise_app/state/group_provider.dart';
import 'package:splitwise_app/theme/app_theme.dart';
import 'package:splitwise_app/widgets/common_widgets.dart';
import 'package:splitwise_app/screen/dashboard_tab.dart';
import 'package:splitwise_app/screen/history_tab.dart';
import 'package:splitwise_app/screen/activity_tab.dart';
import 'package:splitwise_app/screen/authentication/login_screen.dart';

/// Wraps a screen in the providers and theme it expects.
Widget _host(Widget child, {Size size = const Size(390, 844)}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => StateManager()),
      ChangeNotifierProvider(create: (_) => GroupProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('formatMoney', () {
    test('groups digits the Indian way', () {
      expect(formatMoney(0), '₹0');
      expect(formatMoney(999), '₹999');
      expect(formatMoney(1000), '₹1,000');
      expect(formatMoney(27250), '₹27,250');
      expect(formatMoney(123456), '₹1,23,456');
      expect(formatMoney(10000000), '₹1,00,00,000');
    });

    test('handles decimals and negatives', () {
      expect(formatMoney(1234.5, decimals: true), '₹1,234.50');
      expect(formatMoney(-500), '-₹500');
      expect(formatMoney(500, withSymbol: false), '500');
    });
  });

  group('initialsOf', () {
    test('derives one or two letters', () {
      expect(initialsOf('Meera Nair'), 'MN');
      expect(initialsOf('Rahul'), 'RA');
      expect(initialsOf('a'), 'A');
      expect(initialsOf('   '), '?');
      expect(initialsOf('Anita Rani Desai'), 'AD');
    });
  });

  group('theme', () {
    test('is light only', () {
      final theme = AppTheme.lightTheme();
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
    });
  });

  testWidgets('dashboard renders balance summary without overflow',
      (tester) async {
    await tester.pumpWidget(_host(const DashboardTab()));
    await tester.pump();

    expect(find.text('Your balance'), findsOneWidget);
    // OverlineLabel uppercases its text.
    expect(find.text('YOU OWE'), findsOneWidget);
    expect(find.text("YOU'RE OWED"), findsOneWidget);
  });

  testWidgets('history tab shows an empty state when there is nothing',
      (tester) async {
    await tester.pumpWidget(_host(const HistoryTab()));
    await tester.pump();

    expect(find.text('Expenses'), findsOneWidget);
  });

  testWidgets('activity tab lists notifications', (tester) async {
    await tester.pumpWidget(_host(const ActivityTab()));
    await tester.pump();

    expect(find.text('Activity'), findsOneWidget);
  });

  testWidgets('login screen renders its form', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StateManager()),
          ChangeNotifierProvider(create: (_) => GroupProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('dashboard survives a narrow phone and a wide desktop',
      (tester) async {
    for (final size in const [Size(320, 640), Size(1280, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_host(const DashboardTab(), size: size));
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.reset);
  });
}
