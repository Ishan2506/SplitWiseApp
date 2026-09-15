import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:splitwise_app/screen/receipt/receipt_review_screen.dart';
import 'package:splitwise_app/state/group_provider.dart';
import 'package:splitwise_app/state/state_manager.dart';
import 'package:splitwise_app/theme/app_theme.dart';
import 'package:splitwise_app/utils/receipt_parser.dart';

/// The review screen's whole job is to stop a misread figure being saved
/// without anyone looking at it, so these cover what it shows and when.
Future<void> _pump(WidgetTester tester, ReceiptData data) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StateManager()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: ReceiptReviewScreen(
          groupId: 'g-test',
          imagePath: 'test/no-such-file.jpg',
          data: data,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a clean scan reports every field it read', (tester) async {
    await _pump(
      tester,
      ReceiptParser.parse('CURRY GRILL\nDate: 12 Aug 2024\nTOTAL 4,800.00'),
    );

    expect(find.text('We read 4 fields'), findsOneWidget);
    // The parsed values reach the form rather than sitting in the model.
    expect(find.text('4800.00'), findsOneWidget);
    expect(find.text('Curry Grill'), findsOneWidget);
  });

  testWidgets('a guessed total is flagged for checking', (tester) async {
    // No "total" keyword, so the parser falls back to the largest number and
    // marks it low confidence.
    await _pump(tester, ReceiptParser.parse('Corner Shop\nMilk 45.00\n120.50'));

    expect(find.text('LOW'), findsWidgets);
    expect(
      find.text('Check anything marked low confidence before saving.'),
      findsOneWidget,
    );
  });

  testWidgets('editing a flagged field clears its warning', (tester) async {
    await _pump(tester, ReceiptParser.parse('Corner Shop\nMilk 45.00\n120.50'));

    final lowBefore = tester.widgetList(find.text('LOW')).length;

    // Correcting the amount is the user confirming it — the badge should
    // stop shouting about a field they have just looked at.
    await tester.enterText(
      find.byType(TextField).at(1),
      '500.00',
    );
    await tester.pump();

    expect(tester.widgetList(find.text('LOW')).length, lessThan(lowBefore));
  });

  testWidgets('a receipt with no readable date falls back to today',
      (tester) async {
    await _pump(tester, ReceiptParser.parse('Curry Grill\nTOTAL 400.00'));

    // Better than an empty field the user has to fill in by hand.
    expect(find.text('Today'), findsOneWidget);
  });
}
