import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_app/utils/receipt_geometry.dart';
import 'package:splitwise_app/utils/receipt_items.dart';

/// Builds a token at a position, so tests can describe a receipt's layout the
/// way it is actually printed rather than as a flat string.
OcrToken tok(String text, double x, double y, {double w = 60, double h = 20}) =>
    OcrToken(text: text, x: x, y: y, width: w, height: h);

/// A typical thermal bill, 400px wide, with the amount column right-aligned
/// near x=360 and names starting at x=20.
///
/// The token order here is deliberately *not* reading order: names are listed
/// before prices, mimicking ML Kit returning one block of names and another of
/// prices. A parser that reads tokens in sequence gets this wrong; one that
/// reads positions gets it right.
List<OcrToken> spiceGardenTokens() => [
      // names block
      tok('SPICE GARDEN', 20, 10),
      tok('Paneer Tikka', 20, 100),
      tok('Butter Naan', 20, 130),
      tok('Dal Makhani', 20, 160),
      tok('Sub Total', 20, 210),
      tok('CGST 2.5%', 20, 240),
      tok('Grand Total', 20, 280),
      // amounts block, same rows, far to the right
      tok('320', 330, 100, w: 40),
      tok('180', 330, 130, w: 40),
      tok('260', 330, 160, w: 40),
      tok('760', 330, 210, w: 40),
      tok('19', 340, 240, w: 30),
      tok('798', 330, 280, w: 40),
    ];

void main() {
  group('buildRows', () {
    test('groups a name and its far-right price into one row', () {
      final rows = buildRows(spiceGardenTokens());
      final paneer = rows.firstWhere((r) => r.text.contains('Paneer'));

      expect(paneer.tokens.length, 2);
      expect(paneer.text, 'Paneer Tikka 320');
    });

    test('orders rows top to bottom regardless of token order', () {
      final rows = buildRows(spiceGardenTokens());

      expect(rows.first.text, contains('SPICE GARDEN'));
      expect(rows.last.text, contains('Grand Total'));
    });

    test('orders tokens within a row left to right', () {
      final rows = buildRows([
        tok('900', 330, 50, w: 40),
        tok('Biryani', 20, 50),
      ]);

      expect(rows.single.text, 'Biryani 900');
    });

    test('keeps separate lines apart rather than merging them', () {
      final rows = buildRows(spiceGardenTokens());
      final itemRows =
          rows.where((r) => RegExp(r'Paneer|Naan|Dal').hasMatch(r.text));

      expect(itemRows.length, 3);
    });

    test('ignores blank tokens', () {
      final rows = buildRows([tok('   ', 20, 50), tok('Tea', 20, 52)]);

      expect(rows.single.text, 'Tea');
    });

    test('returns nothing for no tokens', () {
      expect(buildRows([]), isEmpty);
    });
  });

  group('detectAmountColumn', () {
    test('finds the right-aligned column of prices', () {
      final column = detectAmountColumn(buildRows(spiceGardenTokens()), 400);

      // Right edges of the amounts sit at 370; the cluster centre should be
      // there, not at the left-hand names.
      expect(column, isNotNull);
      expect(column, closeTo(370, 5));
    });

    test('returns null when there are too few numbers to form a column', () {
      final rows = buildRows([
        tok('Thanks for visiting', 20, 10),
        tok('Come again', 20, 40),
      ]);

      expect(detectAmountColumn(rows, 400), isNull);
    });
  });

  group('parseAmountToken', () {
    test('reads plain and decimal amounts', () {
      expect(parseAmountToken('320'), 320);
      expect(parseAmountToken('320.50'), 320.50);
    });

    test('reads grouped amounts in both conventions', () {
      expect(parseAmountToken('1,240'), 1240);
      expect(parseAmountToken('1,23,456'), 123456);
    });

    test('reads a currency-marked amount', () {
      expect(parseAmountToken('Rs.120'), 120);
      expect(parseAmountToken('₹99.99'), 99.99);
    });

    test('rejects text that merely contains a number', () {
      expect(parseAmountToken('2x'), isNull);
      expect(parseAmountToken('GST18%'), isNull);
      expect(parseAmountToken('Table4'), isNull);
    });

    test('rejects a figure too large to be a line on a bill', () {
      expect(parseAmountToken('9876543210'), isNull);
    });
  });

  group('extractItems', () {
    test('reads every item, not just the first', () {
      final result = extractItems(buildRows(spiceGardenTokens()), 400);

      expect(result.items.map((i) => i.name),
          ['Paneer Tikka', 'Butter Naan', 'Dal Makhani']);
      expect(result.itemsTotal, 760);
    });

    test('stops at the summary, so totals are not counted as items', () {
      final result = extractItems(buildRows(spiceGardenTokens()), 400);

      expect(result.items.any((i) => i.name.contains('Total')), isFalse);
      expect(result.items.any((i) => i.name.contains('CGST')), isFalse);
    });

    test('reads a quantity written before the name', () {
      final rows = buildRows([
        tok('2 x Butter Naan', 20, 50, w: 150),
        tok('180', 330, 50, w: 40),
        tok('Dal Makhani', 20, 80),
        tok('260', 330, 80, w: 40),
        tok('Total', 20, 140),
        tok('440', 330, 140, w: 40),
      ]);
      final result = extractItems(rows, 400);

      expect(result.items.first.name, 'Butter Naan');
      expect(result.items.first.quantity, 2);
      // The line cost 180 in total; the unit price is derived from it.
      expect(result.items.first.lineTotal, 180);
      expect(result.items.first.unitPrice, 90);
    });

    test('reads a quantity written after the name', () {
      final rows = buildRows([
        tok('Masala Chai x 3', 20, 50, w: 150),
        tok('90', 330, 50, w: 40),
        tok('Samosa', 20, 80),
        tok('40', 330, 80, w: 40),
        tok('Total', 20, 140),
        tok('130', 330, 140, w: 40),
      ]);
      final result = extractItems(rows, 400);

      expect(result.items.first.name, 'Masala Chai');
      expect(result.items.first.quantity, 3);
    });

    test('takes the rightmost figure when a rate column is printed', () {
      // "Paneer Tikka | qty 2 | rate 160 | amount 320"
      final rows = buildRows([
        tok('Paneer Tikka', 20, 50),
        tok('2', 200, 50, w: 20),
        tok('160', 260, 50, w: 40),
        tok('320', 330, 50, w: 40),
        tok('Total', 20, 120),
        tok('320', 330, 120, w: 40),
      ]);
      final result = extractItems(rows, 400);

      expect(result.items.single.lineTotal, 320);
      expect(result.items.single.name, isNot(contains('160')));
    });

    test('skips header and footer rows that carry numbers', () {
      final rows = buildRows([
        tok('GSTIN 27AABCU9603R1ZX', 20, 10, w: 200),
        tok('Bill No 4521', 20, 40, w: 120),
        tok('Table 7', 20, 70, w: 80),
        tok('Veg Pulao', 20, 110),
        tok('240', 330, 110, w: 40),
        tok('Total', 20, 170),
        tok('240', 330, 170, w: 40),
      ]);
      final result = extractItems(rows, 400);

      expect(result.items.map((i) => i.name), ['Veg Pulao']);
    });

    test('strips leading serial numbers from names', () {
      final rows = buildRows([
        tok('1. Veg Pulao', 20, 50, w: 120),
        tok('240', 330, 50, w: 40),
        tok('Total', 20, 110),
        tok('240', 330, 110, w: 40),
      ]);
      final result = extractItems(rows, 400);

      expect(result.items.single.name, 'Veg Pulao');
    });

    test('ignores a row whose only number is outside the amount column', () {
      final rows = buildRows([
        tok('Paneer Tikka', 20, 50),
        tok('320', 330, 50, w: 40),
        tok('Dal Makhani', 20, 80),
        tok('260', 330, 80, w: 40),
        tok('Naan', 20, 110),
        tok('180', 330, 110, w: 40),
        // A stray mid-page number, e.g. a table or cover count.
        tok('Covers 4', 20, 140, w: 90),
        tok('Total', 20, 200),
        tok('760', 330, 200, w: 40),
      ]);
      final result = extractItems(rows, 400);

      expect(result.items.length, 3);
      expect(result.items.any((i) => i.name.contains('Covers')), isFalse);
    });

    test('returns nothing when the receipt has no amount column', () {
      final rows = buildRows([
        tok('Thank you for dining', 20, 10, w: 200),
        tok('Please visit again', 20, 40, w: 200),
      ]);

      expect(extractItems(rows, 400).isEmpty, isTrue);
    });

    test('returns nothing rather than throwing on an empty receipt', () {
      expect(extractItems(const [], 400).isEmpty, isTrue);
      expect(extractItems(buildRows(spiceGardenTokens()), 0).isEmpty, isTrue);
    });
  });
}
