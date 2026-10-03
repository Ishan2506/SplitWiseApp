import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:splitwise_app/model/group_model.dart';
import 'package:splitwise_app/screen/balances/people_balances_screen.dart';
import 'package:splitwise_app/screen/balances/person_balance_screen.dart';
import 'package:splitwise_app/screen/groups/budgets_screen.dart';
import 'package:splitwise_app/state/group_provider.dart';
import 'package:splitwise_app/state/state_manager.dart';
import 'package:splitwise_app/theme/app_theme.dart';

const _widths = [Size(320, 900), Size(390, 900), Size(1440, 900)];

/// Same check as responsive_test.dart: any Row/Column whose children don't
/// fit the space it was given.
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
            '${(children - available).toStringAsFixed(1)}px');
      }
    }
    o.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  return found;
}

const _longName = 'Alexandria Venkataraman-Fitzgerald';

final _group = GroupModel(
  id: 'g1',
  name: 'Flatmates with a rather long group name',
  description: '',
  type: GroupType.family,
  photoUrl: '',
  balanceLimit: 0,
  currency: 'INR',
  createdById: '',
  createdByName: '',
  members: const [
    GroupMember(id: 'alex', name: _longName, upiId: 'alexandria.v@okaxis'),
  ],
);

final _net = NetBalances.fromJson({
  'currency': 'INR',
  'totals': {'owed': 123456, 'owe': 98765},
  'people': [
    {
      'user': {'id': 'alex', 'name': _longName, 'upiId': 'alexandria.v@okaxis', 'paypalMe': 'alexv'},
      'net': -98765.5,
      'netByCurrency': {'INR': -98765.5},
      'groups': [
        {'groupId': 'g1', 'groupName': _group.name, 'currency': 'INR', 'amount': -150000},
        {'groupId': 'g2', 'groupName': 'Goa trip 2026 with everyone', 'currency': 'INR', 'amount': 51234.5},
      ],
    },
    {
      'user': {'id': 'sam', 'name': 'Sam', 'upiId': ''},
      'net': null,
      'netByCurrency': {'INR': 123456, 'USD': -1999},
      'groups': [
        {'groupId': 'g1', 'groupName': 'Flatmates', 'currency': 'INR', 'amount': 123456},
        {'groupId': 'g3', 'groupName': 'NYC', 'currency': 'USD', 'amount': -1999},
      ],
    },
  ],
});

final _budgets = GroupBudgets.fromJson({
  'month': '2026-10',
  'currency': 'INR',
  'budgets': [
    {'category': 'All', 'amount': 1000000, 'spent': 1234567, 'percent': 123.46},
    {'category': 'Food & drink', 'amount': 5000, 'spent': 4100, 'percent': 82},
    {'category': 'Entertainment', 'amount': 3000, 'spent': 300, 'percent': 10},
  ],
  'spend': {'All': 1234567, 'Food & drink': 4100},
});

Future<void> _pumpAt(WidgetTester tester, Widget screen, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final groups = GroupProvider()
    ..debugSeed(
      groups: [_group],
      netBalances: _net,
      budgets: {'g1': _budgets},
    );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StateManager()),
        ChangeNotifierProvider.value(value: groups),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme(), home: screen),
    ),
  );
  await tester.pump();
}

void main() {
  final screens = <String, Widget Function()>{
    'people balances': () => const PeopleBalancesScreen(),
    'person balance (you owe, single currency)': () =>
        const PersonBalanceScreen(userId: 'alex'),
    'person balance (mixed currency)': () =>
        const PersonBalanceScreen(userId: 'sam'),
    'budgets': () => const BudgetsScreen(groupId: 'g1'),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} lays out without overflow', (tester) async {
      addTearDown(tester.view.reset);
      for (final size in _widths) {
        await _pumpAt(tester, entry.value(), size);
        // Load-on-open network calls fail in tests; layout is what matters.
        tester.takeException();
        expect(_overflows(tester), isEmpty,
            reason: '${entry.key} at ${size.width.toInt()}px');
      }
    });
  }

  testWidgets('person screen offers UPI and PayPal when you owe', (tester) async {
    addTearDown(tester.view.reset);
    await _pumpAt(tester, const PersonBalanceScreen(userId: 'alex'), const Size(390, 1400));
    tester.takeException();
    expect(find.text('Pay via UPI app'), findsOneWidget);
    expect(find.text('Pay via PayPal'), findsOneWidget);
    expect(find.text('alexandria.v@okaxis'), findsOneWidget);
  });

  testWidgets('mixed-currency person cannot be settled at once', (tester) async {
    addTearDown(tester.view.reset);
    await _pumpAt(tester, const PersonBalanceScreen(userId: 'sam'), const Size(390, 1400));
    tester.takeException();
    expect(find.textContaining('different currencies'), findsOneWidget);
    expect(find.text('Pay via UPI app'), findsNothing);
  });
}
