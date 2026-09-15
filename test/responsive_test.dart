import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:splitwise_app/state/state_manager.dart';
import 'package:splitwise_app/state/group_provider.dart';
import 'package:splitwise_app/theme/app_theme.dart';
import 'package:splitwise_app/screen/dashboard_tab.dart';
import 'package:splitwise_app/screen/history_tab.dart';
import 'package:splitwise_app/screen/activity_tab.dart';
import 'package:splitwise_app/screen/add_expense_screen.dart';
import 'package:splitwise_app/screen/profile/profile_screen.dart';
import 'package:splitwise_app/screen/profile/edit_profile_screen.dart';
import 'package:splitwise_app/screen/settle_up_dialog.dart';
import 'package:splitwise_app/screen/authentication/login_screen.dart';
import 'package:splitwise_app/screen/authentication/signup_screen.dart';
import 'package:splitwise_app/screen/authentication/forgot_password_screen.dart';
import 'package:splitwise_app/screen/groups/create_group_screen.dart';
import 'package:splitwise_app/screen/groups/settle_up_screen.dart';
import 'package:splitwise_app/screen/groups/who_owes_whom_screen.dart';
import 'package:splitwise_app/screen/receipt/receipt_review_screen.dart';
import 'package:splitwise_app/utils/receipt_parser.dart';

/// Widths worth guarding: a small phone, a common phone, a tablet, a desktop.
const _widths = [
  Size(320, 700),
  Size(390, 844),
  Size(768, 1024),
  Size(1440, 900),
];

/// Reports any Row/Column whose children are wider than the space it was
/// given. This catches the "RenderFlex overflowed" yellow stripes before they
/// reach a real device.
List<String> _overflows(WidgetTester tester) {
  final found = <String>[];

  void walk(RenderObject o) {
    if (o is RenderFlex) {
      var children = 0.0;
      o.visitChildren((c) {
        if (c is RenderBox) {
          children +=
              o.direction == Axis.horizontal ? c.size.width : c.size.height;
        }
      });
      final available =
          o.direction == Axis.horizontal ? o.size.width : o.size.height;
      if (children - available > 0.5) {
        found.add('${o.direction.name} overflow of '
            '${(children - available).toStringAsFixed(1)}px '
            '(available ${available.toStringAsFixed(0)}px)');
      }
    }
    o.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  return found;
}

Future<void> _pumpAt(WidgetTester tester, Widget screen, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StateManager()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme(), home: screen),
    ),
  );
  await tester.pump();
}

void main() {
  final screens = <String, Widget Function()>{
    'dashboard': () => const Scaffold(body: DashboardTab()),
    'history': () => const Scaffold(body: HistoryTab()),
    'activity': () => const Scaffold(body: ActivityTab()),
    // No groups are seeded, so this renders the not-yet-loaded fallback:
    // an unknown group id still has to lay out without overflowing.
    'add expense': () => const AddExpenseScreen(groupId: 'g-test'),
    'profile': () => const ProfileScreen(),
    'edit profile': () => const EditProfileScreen(),
    'settle up': () => const Scaffold(body: SettleUpDialog()),
    'login': () => const LoginScreen(),
    'signup': () => const SignupScreen(),
    'forgot password': () => const ForgotPasswordScreen(),
    'create group': () => const CreateGroupScreen(),
    // The receipt flow's review step, given a scan with a mix of confidences —
    // the badges and the long "low confidence" note are what crowd the rows.
    'receipt review': () => ReceiptReviewScreen(
          groupId: 'g-test',
          imagePath: 'test/does-not-exist.jpg',
          data: ReceiptParser.parse(
            'CURRY GRILL\nDate: 12 Aug 2024\nTOTAL 4,800.00',
          ),
        ),
    // Balances are empty here, so both of these render their settled states.
    'who owes whom': () => const WhoOwesWhomScreen(groupId: 'g-test'),
    'settle up screen': () => const SettleUpScreen(groupId: 'g-test'),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} lays out without overflow at every width',
        (tester) async {
      addTearDown(tester.view.reset);

      for (final size in _widths) {
        await _pumpAt(tester, entry.value(), size);
        // Screens that fetch on load can surface network errors here; the
        // layout is what this test is about.
        tester.takeException();

        expect(
          _overflows(tester),
          isEmpty,
          reason: '${entry.key} at ${size.width.toInt()}px wide',
        );
      }
    });
  }
}
