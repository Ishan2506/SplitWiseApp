import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:splitwise_app/models/models.dart';
import 'package:splitwise_app/screen/receipt/receipt_review_screen.dart';
import 'package:splitwise_app/state/group_provider.dart';
import 'package:splitwise_app/state/state_manager.dart';
import 'package:splitwise_app/utils/receipt_parser.dart';

/// Drives the review screen far enough to exercise the split arithmetic.
///
/// The sums here are the ones that reach the ledger, so they are checked to
/// the paisa: a split that is a paisa short looks harmless on one bill and
/// turns into a balance nobody can reconcile over a few months.
ReceiptData dataWith({
  required List<ReceiptItem> items,
  required double total,
}) =>
    ReceiptData(
      merchant: const ExtractedField('Spice Garden', FieldConfidence.high),
      total: ExtractedField(total, FieldConfidence.high),
      date: ExtractedField(DateTime(2026, 9, 1), FieldConfidence.high),
      category: const ExtractedField('Food & drink', FieldConfidence.medium),
      rawText: '',
      items: items,
    );

ReceiptItem item(String name, double price, {int qty = 1}) =>
    ReceiptItem(name: name, quantity: qty, lineTotal: price);

void main() {
  group('itemsReconcile', () {
    test('accepts items that make up most of the bill', () {
      // 760 of an 798 bill: the rest is tax, which is normal.
      final data = dataWith(
        items: [item('Paneer', 320), item('Naan', 180), item('Dal', 260)],
        total: 798,
      );

      expect(data.itemsTotal, 760);
      expect(data.itemsReconcile, isTrue);
    });

    test('rejects items that fall well short of the bill', () {
      // Only one row of three was read — the original bug. The shortfall is
      // what gives it away, and it must not be offered as a split basis.
      final data = dataWith(items: [item('Paneer', 320)], total: 798);

      expect(data.itemsReconcile, isFalse);
    });

    test('rejects items that exceed the bill', () {
      // A summary row read as an item double-counts the food.
      final data = dataWith(
        items: [item('Paneer', 320), item('Sub Total', 760)],
        total: 798,
      );

      expect(data.itemsReconcile, isFalse);
    });

    test('rejects an empty item list', () {
      expect(dataWith(items: [], total: 798).itemsReconcile, isFalse);
    });

    test('rejects items when no total was read', () {
      final data = ReceiptData(
        merchant: const ExtractedField.missing(),
        total: const ExtractedField.missing(),
        date: const ExtractedField.missing(),
        category: const ExtractedField.missing(),
        rawText: '',
        items: [item('Paneer', 320)],
      );

      expect(data.itemsReconcile, isFalse);
    });
  });

  group('split by item', () {
    late StateManager state;

    /// Builds the review screen with three members and the given receipt.
    Future<void> pump(WidgetTester tester, ReceiptData data) async {
      state = StateManager();
      state.members
        ..clear()
        ..addAll([
          Member(id: 'a', name: 'Asha', email: 'a@x.com', avatarUrl: ''),
          Member(id: 'b', name: 'Bilal', email: 'b@x.com', avatarUrl: ''),
          Member(id: 'c', name: 'Chen', email: 'c@x.com', avatarUrl: ''),
        ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            ChangeNotifierProvider(create: (_) => GroupProvider()),
          ],
          child: MaterialApp(
            home: ReceiptReviewScreen(
              groupId: 'g1',
              data: data,
              imagePath: 'nonexistent.jpg',
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('offers split by item when the items add up', (tester) async {
      await pump(
        tester,
        dataWith(
          items: [item('Paneer', 320), item('Naan', 180), item('Dal', 260)],
          total: 760,
        ),
      );

      expect(find.text('Split by item'), findsOneWidget);
    });

    testWidgets('does not offer split by item when items fall short',
        (tester) async {
      await pump(tester, dataWith(items: [item('Paneer', 320)], total: 798));

      expect(find.text('Split by item'), findsNothing);
    });

    testWidgets('shows every item read off the bill', (tester) async {
      await pump(
        tester,
        dataWith(
          items: [item('Paneer', 320), item('Naan', 180), item('Dal', 260)],
          total: 760,
        ),
      );

      expect(find.text('Paneer'), findsOneWidget);
      expect(find.text('Naan'), findsOneWidget);
      expect(find.text('Dal'), findsOneWidget);
      expect(find.text('Items on the bill (3)'), findsOneWidget);
    });

    testWidgets('unassigned items are shared, so shares stay even',
        (tester) async {
      await pump(
        tester,
        dataWith(
          items: [item('Paneer', 300), item('Naan', 300), item('Dal', 300)],
          total: 900,
        ),
      );
      await _chooseSplitByItem(tester);

      // Nothing assigned: 900 across three is 300 each.
      expect(find.text('Each person owes'), findsOneWidget);

      // Three people, three 300 items, nothing assigned: 300 each. Asserted
      // against the per-person summary rather than the whole screen, since the
      // item rows show the same figures and would mask a wrong split.
      expect(_owedAmounts(tester), ['₹300.00', '₹300.00', '₹300.00']);
    });

    testWidgets('assigning an item moves its cost to that person',
        (tester) async {
      await pump(
        tester,
        dataWith(
          items: [item('Paneer', 300), item('Naan', 300), item('Dal', 300)],
          total: 900,
        ),
      );
      await _chooseSplitByItem(tester);

      // Give the first item to Asha alone. She now owes all 300 of it plus a
      // third of the two shared items: 300 + 100 + 100 = 500, and the other
      // two owe 100 + 100 = 200 each.
      final ashaChip = find.descendant(
        of: find.byType(_assignmentChipType),
        matching: find.text('Asha'),
      );
      await _scrollTo(tester, ashaChip.last);
      await tester.tap(ashaChip.last);
      await tester.pumpAndSettle();

      // 500 + 200 + 200 = 900, the whole bill and not a paisa more.
      expect(_owedAmounts(tester), ['₹500.00', '₹200.00', '₹200.00']);
    });
  });

  group('split arithmetic edge cases', () {
    /// Reads the per-person shares for a receipt, exercising _itemSplits
    /// through the screen exactly as a save would.
    Future<List<String>> shares(
      WidgetTester tester,
      List<ReceiptItem> items,
      double total,
    ) async {
      final state = StateManager();
      state.members
        ..clear()
        ..addAll([
          Member(id: 'a', name: 'Asha', email: 'a@x.com', avatarUrl: ''),
          Member(id: 'b', name: 'Bilal', email: 'b@x.com', avatarUrl: ''),
          Member(id: 'c', name: 'Chen', email: 'c@x.com', avatarUrl: ''),
        ]);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            ChangeNotifierProvider(create: (_) => GroupProvider()),
          ],
          child: MaterialApp(
            home: ReceiptReviewScreen(
              groupId: 'g1',
              data: dataWith(items: items, total: total),
              imagePath: 'x.jpg',
            ),
          ),
        ),
      );
      await tester.pump();
      await _chooseSplitByItem(tester);
      return _owedAmounts(tester);
    }

    testWidgets('a bill that does not divide evenly still adds up',
        (tester) async {
      // 100 across three: 33.34 + 33.33 + 33.33, never 99.99.
      final owed = await shares(
        tester,
        [item('Chai', 100)],
        100,
      );

      expect(owed.length, 3);
      final sum = owed
          .map((s) => double.parse(s.replaceAll(RegExp(r'[^0-9.]'), '')))
          .fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(100, 0.001));
    });

    testWidgets('tax on top of the items is shared out and still adds up',
        (tester) async {
      // Items come to 900, bill is 990: the 90 of tax must land somewhere.
      final owed = await shares(
        tester,
        [item('Paneer', 300), item('Naan', 300), item('Dal', 300)],
        990,
      );

      final sum = owed
          .map((s) => double.parse(s.replaceAll(RegExp(r'[^0-9.]'), '')))
          .fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(990, 0.001));
    });
  });
}

/// The assignment chips are the only InkWells inside the per-item cards.
final _assignmentChipType = InkWell;

/// The amounts in the "Each person owes" card, in the order shown.
///
/// Reading them from that card alone is deliberate: the same figures appear on
/// the item rows above, so a screen-wide search would pass even if the split
/// itself were wrong.
List<String> _owedAmounts(WidgetTester tester) {
  final card = find.ancestor(
    of: find.text('Each person owes'),
    matching: find.byType(Column),
  );
  return tester
      .widgetList<Text>(find.descendant(of: card.first, matching: find.byType(Text)))
      .map((t) => t.data ?? '')
      .where((s) => s.startsWith('₹'))
      .toList();
}

/// Switches the screen to split-by-item.
///
/// The toggle sits below the fold on a test-sized screen, so it has to be
/// scrolled to before it can be tapped — a tap that misses silently leaves the
/// screen in even-split mode and makes the assertions that follow meaningless.
Future<void> _chooseSplitByItem(WidgetTester tester) async {
  final toggle = find.text('Split by item');
  await _scrollTo(tester, toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

/// Brings [target] into view within the screen's main scroll view.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
