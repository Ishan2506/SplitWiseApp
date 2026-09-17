/// Reads the line items off a receipt, given its rows rebuilt by
/// [buildRows] and the amount column found by [detectAmountColumn].
///
/// The four-field parse in [ReceiptParser] answers "what did this bill come
/// to". This answers "what was on it", which is what splitting by item needs.
/// The two are independent on purpose: items are much harder to read reliably,
/// so a receipt whose items come out badly should still yield a usable total.
library;

import 'receipt_geometry.dart';

/// One line of the bill: a thing that was bought, and what it cost.
class ReceiptItem {
  final String name;
  final int quantity;

  /// What this line contributes to the bill — quantity included. A row reading
  /// "2 x Naan 90" has a [lineTotal] of 90, not 45.
  final double lineTotal;

  /// Why this row might be wrong, empty when nothing looked off. The review
  /// screen tints flagged rows so a misread is cheap to catch.
  final List<String> flags;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.lineTotal,
    this.flags = const [],
  });

  /// Price per unit, derived rather than read — receipts do not always print
  /// a rate column.
  double get unitPrice => quantity > 0 ? lineTotal / quantity : lineTotal;

  ReceiptItem copyWith({String? name, int? quantity, double? lineTotal}) =>
      ReceiptItem(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        lineTotal: lineTotal ?? this.lineTotal,
        flags: flags,
      );
}

/// The items read off a receipt, with a note on how well they add up.
class ItemisedReceipt {
  final List<ReceiptItem> items;

  /// The items summed. Kept separate from the receipt's printed total: when
  /// the two disagree, that disagreement is the signal worth showing.
  final double itemsTotal;

  const ItemisedReceipt({required this.items, required this.itemsTotal});

  const ItemisedReceipt.empty()
      : items = const [],
        itemsTotal = 0;

  bool get isEmpty => items.isEmpty;
}

/// Rows whose text marks the end of the item list. Everything from the first
/// of these downward is summary, not food.
final _summaryMarkers = RegExp(
  r'sub\s*-?\s*total|grand\s*total|net\s*(?:payable|amount|total)'
  r'|amount\s*payable|total\s*payable|bill\s*(?:amount|total)'
  r'|\bcgst\b|\bsgst\b|\bigst\b|\bgst\b|\bvat\b|service\s*(?:charge|tax)'
  r'|round\s*(?:off|ing)|\btotal\b',
  caseSensitive: false,
);

/// Rows that are never an item even when they sit in the item region and carry
/// a number: headers, identifiers, table captions and footer text.
final _neverItem = RegExp(
  r'gstin|fssai|\btin\b|\bpan\b|invoice|bill\s*(?:no|#)|receipt\s*no'
  r'|order\s*(?:no|id)|token|table\s*(?:no|#)?|steward|waiter|cashier'
  r'|captain|server|\bpax\b|thank\s*you|visit\s*again|come\s*again'
  r'|phone|mobile|\btel\b|www\.|@|terms|condition'
  r'|^\s*(?:date|time)\b|^\s*qty\b|^\s*(?:item|particular|description)s?\b'
  r'|\bcash\b|\bcard\b|\bupi\b|\bchange\b|tendered|paytm|gpay|phonepe',
  caseSensitive: false,
);

/// A row that is only punctuation or rules, e.g. "-------".
final _separatorOnly = RegExp(r'^[\s\-=_*.|]+$');

/// Quantity written into the name, most specific pattern first.
final _qtyPatterns = <RegExp>[
  RegExp(r'^(\d{1,3})\s*[x×*]\s*(.+)$', caseSensitive: false), // 2 x Naan
  RegExp(r'^(.+?)\s*[x×*]\s*(\d{1,3})$', caseSensitive: false), // Naan x 2
];

/// Whether the quantity is the first or second capture in the pattern above.
const _qtyIsFirstGroup = [true, false];

/// Pulls the item lines out of a receipt.
///
/// [imageWidth] is the width of the image the boxes were measured in, used to
/// turn absolute positions into proportions so the same logic works at any
/// resolution.
///
/// Returns an empty result rather than guessing when the receipt has no
/// readable amount column — a bill photographed at an angle, or one with no
/// item table at all.
ItemisedReceipt extractItems(List<OcrRow> rows, double imageWidth) {
  if (rows.isEmpty || imageWidth <= 0) return const ItemisedReceipt.empty();

  final amountColumn = detectAmountColumn(rows, imageWidth);
  if (amountColumn == null) return const ItemisedReceipt.empty();

  // Items live between the header and the first summary row. Scanning the
  // whole page instead would pull "Grand Total 1302" in as an item, which is
  // both wrong and doubles the apparent bill.
  final end = rows.indexWhere((r) => _summaryMarkers.hasMatch(r.text));
  final itemRows = end >= 0 ? rows.sublist(0, end) : rows;

  final items = <ReceiptItem>[];
  for (final row in itemRows) {
    final item = _itemFromRow(row, amountColumn, imageWidth);
    if (item != null) items.add(item);
  }

  final total = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
  return ItemisedReceipt(items: items, itemsTotal: total);
}

/// Reads one row as an item, or returns null if it is not one.
ReceiptItem? _itemFromRow(OcrRow row, double amountColumn, double imageWidth) {
  final text = row.text;
  if (text.isEmpty || _separatorOnly.hasMatch(text)) return null;
  if (_neverItem.hasMatch(text)) return null;

  // Tokens may be measured slightly off the column centre, so allow a margin
  // proportional to the page rather than an absolute pixel count.
  final slack = imageWidth * 0.05;

  // The amount is the rightmost number sitting in the amount column. Taking
  // the rightmost, rather than the first number on the row, is what stops a
  // quantity or a rate being read as the line's cost.
  var amountIndex = -1;
  double? lineTotal;
  for (var i = row.tokens.length - 1; i >= 0; i--) {
    final value = parseAmountToken(row.tokens[i].text);
    if (value == null) continue;
    if (row.tokens[i].right < amountColumn - slack) continue;
    amountIndex = i;
    lineTotal = value;
    break;
  }

  // No figure in the amount column: a note, an address line, a row of the
  // header. Not an item.
  if (lineTotal == null) return null;

  final left = row.tokens.sublist(0, amountIndex);
  if (left.isEmpty) return null;

  var name = left.map((t) => t.text).join(' ');
  var quantity = 1;
  final flags = <String>[];

  // A trailing number just before the amount is a unit rate, printed by tills
  // that carry a rate column. Only treat it as one when real words remain to
  // its left, otherwise it is the item's own price on a two-column bill.
  if (left.length > 1) {
    final asRate = parseAmountToken(left.last.text);
    final restHasWords =
        left.sublist(0, left.length - 1).any((t) => _hasWords(t.text));
    if (asRate != null && restHasWords) {
      name = left.sublist(0, left.length - 1).map((t) => t.text).join(' ');
    }
  }

  // Quantity written into the name: "2 x Paneer Tikka".
  for (var i = 0; i < _qtyPatterns.length; i++) {
    final match = _qtyPatterns[i].firstMatch(name.trim());
    if (match == null) continue;
    final qtyGroup = _qtyIsFirstGroup[i] ? 1 : 2;
    final nameGroup = _qtyIsFirstGroup[i] ? 2 : 1;
    final parsedQty = int.tryParse(match.group(qtyGroup)!.trim());
    final parsedName = match.group(nameGroup)!.trim();
    if (parsedQty != null &&
        parsedQty > 0 &&
        parsedQty <= 99 &&
        parsedName.length >= 2) {
      quantity = parsedQty;
      name = parsedName;
    }
    break;
  }

  name = _cleanName(name);

  // A name needs real words. This is the last guard against a row of stray
  // numbers — a date, a bill reference — being recorded as something eaten.
  if (name.length < 2 || !_hasWords(name)) return null;

  if (lineTotal <= 0) flags.add('zero_amount');

  return ReceiptItem(
    name: name,
    quantity: quantity,
    lineTotal: lineTotal,
    flags: flags,
  );
}

/// Strips the decoration around an item name: leading serial numbers, trailing
/// punctuation, and the doubled spaces left behind by joining tokens.
String _cleanName(String raw) => raw
    .replaceAll(RegExp(r'^[\s\d.)\-|:]+'), '')
    .replaceAll(RegExp(r'[\s|:;,.]+$'), '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

/// Whether this text contains an actual word, as opposed to digits, currency
/// marks and punctuation.
bool _hasWords(String text) => RegExp(r'[A-Za-z]{2,}').hasMatch(text);
