import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:splitwise_app/model/group_model.dart';
import 'package:splitwise_app/screen/groups/who_owes_whom_screen.dart';
import 'package:splitwise_app/state/group_provider.dart';
import 'package:splitwise_app/state/state_manager.dart';
import 'package:splitwise_app/theme/app_theme.dart';

/// "Settle up" means paying someone back, so it should only be offered to
/// whoever actually owes. Being owed money is squared up by the debtor, and a
/// creditor tapping "Settle up" would be recording a payment they never made.
class _StubGroupProvider extends GroupProvider {
  _StubGroupProvider(this._suggestions);

  final List<SettlementSuggestion> _suggestions;

  @override
  GroupBalances balancesFor(String groupId) => GroupBalances(
        balances: const [],
        suggestions: _suggestions,
        balanceLimit: 0,
        currency: 'INR',
      );

  // The screen refreshes on open; there is no server here to ask.
  @override
  Future<void> loadBalances(String groupId, {bool notify = true}) async {}
}

class _StubState extends StateManager {
  @override
  String get currentUserId => 'me';
}

Future<void> _pump(
  WidgetTester tester,
  List<SettlementSuggestion> suggestions,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<StateManager>(create: (_) => _StubState()),
        ChangeNotifierProvider<GroupProvider>(
          create: (_) => _StubGroupProvider(suggestions),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const WhoOwesWhomScreen(groupId: 'g1'),
      ),
    ),
  );
  await tester.pump();
}

const _iOweRahul = SettlementSuggestion(
  fromId: 'me',
  fromName: 'You',
  toId: 'rahul',
  toName: 'Rahul',
  amount: 1250,
);

const _priyaOwesMe = SettlementSuggestion(
  fromId: 'priya',
  fromName: 'Priya',
  toId: 'me',
  toName: 'You',
  amount: 800,
);

void main() {
  testWidgets('offers Settle up when the user owes someone', (tester) async {
    await _pump(tester, [_iOweRahul]);

    expect(find.widgetWithText(InkWell, 'Settle up'), findsWidgets);
    expect(find.text('You owe Rahul'), findsOneWidget);
  });

  testWidgets('hides Settle up when the user is only owed money',
      (tester) async {
    await _pump(tester, [_priyaOwesMe]);

    // The debt is still listed — it is just not the user's to settle.
    expect(find.text('Priya owes you'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Settle up'), findsNothing);
  });

  testWidgets('hides Settle up when everyone is square', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Everyone is settled up'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Settle up'), findsNothing);
  });

  testWidgets('still offers Settle up when the user both owes and is owed',
      (tester) async {
    await _pump(tester, [_priyaOwesMe, _iOweRahul]);

    expect(find.widgetWithText(InkWell, 'Settle up'), findsWidgets);
  });
}
