import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_app/utils/receipt_geometry.dart';
import 'package:splitwise_app/utils/receipt_parser.dart';

/// The parser is the one part of the receipt flow with no UI, so it carries
/// the cases that are easy to get wrong: a subtotal sitting above the real
/// total, tax lines, ambiguous dates and OCR noise.
void main() {
  group('total', () {
    test('prefers the labelled total over subtotal and tax', () {
      const text = '''
Curry Grill
Subtotal        4,000.00
CGST 9%           400.00
SGST 9%           400.00
TOTAL           4,800.00
''';
      final result = ReceiptParser.parse(text);
      expect(result.total.value, 4800.00);
      expect(result.total.confidence, FieldConfidence.high);
    });

    test('never returns the subtotal even when it is the largest labelled row',
        () {
      const text = '''
Big Store
SUBTOTAL   9,999.00
DISCOUNT  -1,000.00
TOTAL      8,999.00
''';
      expect(ReceiptParser.parse(text).total.value, 8999.00);
    });

    test('takes the amount from the next line when the label wraps', () {
      const text = '''
Cafe Mocha
Grand Total
   ₹1,250.50
''';
      expect(ReceiptParser.parse(text).total.value, 1250.50);
    });

    test('ignores cash tendered and change given', () {
      const text = '''
Dhaba Express
TOTAL        450.00
CASH       1,000.00
CHANGE       550.00
''';
      expect(ReceiptParser.parse(text).total.value, 450.00);
    });

    test('falls back to the largest amount but flags it as low confidence', () {
      const text = '''
Corner Shop
Milk      45.00
Bread    120.50
''';
      final result = ReceiptParser.parse(text);
      expect(result.total.value, 120.50);
      expect(result.total.confidence, FieldConfidence.low);
    });

    test('skips small bare integers that are quantities, not money', () {
      const text = '''
Juice Bar
2 x Orange
TOTAL  260.00
''';
      expect(ReceiptParser.parse(text).total.value, 260.00);
    });

    test('reads the rightmost figure on a row', () {
      // "3" is a quantity, 90.00 the unit price, 270.00 the line total.
      const text = '''
Tea House
Total    3   90.00   270.00
''';
      expect(ReceiptParser.parse(text).total.value, 270.00);
    });
  });

  group('date', () {
    test('parses a named month as high confidence', () {
      final result = ReceiptParser.parse('Curry Grill\nDate: 12 Aug 2024');
      expect(result.date.value, DateTime(2024, 8, 12));
      expect(result.date.confidence, FieldConfidence.high);
    });

    test('reads an unambiguous numeric date day-first', () {
      // 25 cannot be a month, so this is 25 August.
      final result = ReceiptParser.parse('Shop\n25/08/2024');
      expect(result.date.value, DateTime(2024, 8, 25));
      expect(result.date.confidence, FieldConfidence.high);
    });

    test('flags an ambiguous numeric date for checking', () {
      final result = ReceiptParser.parse('Shop\n05/08/2024');
      expect(result.date.value, DateTime(2024, 8, 5));
      expect(result.date.confidence, FieldConfidence.medium);
    });

    test('falls back to month-first when the second number cannot be a month',
        () {
      final result = ReceiptParser.parse('Shop\n08/25/2024');
      expect(result.date.value, DateTime(2024, 8, 25));
    });

    test('rejects a future date rather than reporting a wrong one', () {
      final nextYear = DateTime.now().year + 2;
      final result = ReceiptParser.parse('Shop\n12 Aug $nextYear');
      expect(result.date.isPresent, isFalse);
    });

    test('rejects an impossible calendar date', () {
      final result = ReceiptParser.parse('Shop\n31/02/2024');
      expect(result.date.isPresent, isFalse);
    });
  });

  group('merchant', () {
    test('takes the first line and title-cases it', () {
      final result = ReceiptParser.parse('CURRY GRILL\nMG Road\nTOTAL 400.00');
      expect(result.merchant.value, 'Curry Grill');
      expect(result.merchant.confidence, FieldConfidence.high);
    });

    test('skips header noise to find the real name', () {
      final result = ReceiptParser.parse('TAX INVOICE\nBlue Tokai\nTOTAL 300.00');
      expect(result.merchant.value, 'Blue Tokai');
      // Not the first line, so we are less sure it is the name.
      expect(result.merchant.confidence, FieldConfidence.medium);
    });

    test('skips a phone number line', () {
      final result =
          ReceiptParser.parse('9876543210\nPizza Point\nTOTAL 500.00');
      expect(result.merchant.value, 'Pizza Point');
    });
  });

  group('category', () {
    test('infers food from the merchant name', () {
      final result = ReceiptParser.parse('Curry Grill\nTOTAL 400.00');
      expect(result.category.value, 'Food & drink');
    });

    test('infers travel from a cab receipt', () {
      final result = ReceiptParser.parse('Uber India\nTOTAL 340.00');
      expect(result.category.value, 'Travel');
    });

    test('infers accommodation from a hotel name', () {
      final result = ReceiptParser.parse('Sunrise Resort\nTOTAL 9,400.00');
      expect(result.category.value, 'Accommodation');
    });

    test('never claims high confidence, since it is always a guess', () {
      final result = ReceiptParser.parse('Curry Grill\nTOTAL 400.00');
      expect(result.category.confidence, isNot(FieldConfidence.high));
    });
  });

  group('whole receipt', () {
    test('reads all four fields off a realistic bill', () {
      const text = '''
CURRY GRILL
MG Road, Bengaluru
GSTIN: 29ABCDE1234F1Z5
Date: 12 Aug 2024    Time: 21:14
------------------------------
Paneer Tikka        1    420.00
Butter Naan         4    240.00
------------------------------
Subtotal               4,000.00
CGST 9%                  400.00
SGST 9%                  400.00
TOTAL                  4,800.00
Thank you, visit again!
''';
      final result = ReceiptParser.parse(text);

      expect(result.merchant.value, 'Curry Grill');
      expect(result.total.value, 4800.00);
      expect(result.date.value, DateTime(2024, 8, 12));
      expect(result.category.value, 'Food & drink');
      expect(result.fieldsFound, 4);
    });

    test('empty OCR output yields nothing found rather than throwing', () {
      final result = ReceiptParser.parse('');
      expect(result.fieldsFound, 0);
      expect(result.total.isPresent, isFalse);
    });
  });

  group('parseWithLayout', () {
    OcrToken tok(String text, double x, double y, {double w = 60, double h = 20}) =>
        OcrToken(text: text, x: x, y: y, width: w, height: h);

    test(
        'reads the true grand total instead of the first item, when the '
        'label and its amount land in different OCR blocks', () {
      // A hotel folio, 400px wide. ML Kit reads the labels as one block and
      // the amounts as a second block — its usual behaviour whenever a wide
      // gap separates a name column from a price column, and exactly what
      // real hotel/rent bills tend to do. Flattened to text this reads
      // "...Total\n3000.00...", so a purely text-based reading that falls
      // back to "the next line" for a bare label picks up Room Charge's
      // price instead of the real total.
      final tokens = [
        // labels block (token order, not visual order — mirrors block order)
        tok('Hotel Sunrise', 20, 10),
        tok('Room Charge', 20, 100),
        tok('Food Charge', 20, 130),
        tok('Laundry', 20, 160),
        tok('Total', 20, 210),
        // amounts block, far to the right, on the same visual rows
        tok('3000.00', 320, 100, w: 60),
        tok('1200.00', 320, 130, w: 60),
        tok('200.00', 320, 160, w: 60),
        tok('4400.00', 320, 210, w: 60),
      ];

      // recognized.text concatenates block by block — this is the actual
      // shape of the bug: "Total" is immediately followed by "3000.00"
      // (Room Charge's price), not "4400.00".
      const rawText = 'Hotel Sunrise\nRoom Charge\nFood Charge\nLaundry\n'
          'Total\n3000.00\n1200.00\n200.00\n4400.00';

      // Proves the bug exists in the text-only path this replaces...
      expect(ReceiptParser.parse(rawText).total.value, 3000.00);

      // ...and that reading the amount off the same visual row fixes it.
      final result = ReceiptParser.parseWithLayout(
        rawText: rawText,
        tokens: tokens,
        imageWidth: 400,
      );
      expect(result.total.value, 4400.00);
      expect(result.total.confidence, FieldConfidence.high);
    });
  });
}
