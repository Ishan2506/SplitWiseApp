/// Pulls the fields we need for an expense out of the raw text a receipt scan
/// produces.
///
/// OCR of a crumpled till receipt is never clean, so every field carries a
/// [FieldConfidence] rather than being presented as fact. The review screen
/// uses it to decide what to flag, which is why a wrong-but-confident answer is
/// worse here than an honest "low" — when a rule only half-matches we lower the
/// confidence instead of guessing harder.
library;

import 'receipt_geometry.dart';
import 'receipt_items.dart';

export 'receipt_items.dart' show ReceiptItem;

/// How much we trust one extracted field.
enum FieldConfidence { high, medium, low }

extension FieldConfidenceLabel on FieldConfidence {
  String get label => switch (this) {
        FieldConfidence.high => 'HIGH',
        FieldConfidence.medium => 'MED',
        FieldConfidence.low => 'LOW',
      };
}

/// One field lifted off the receipt, with how sure we are of it.
class ExtractedField<T> {
  final T? value;
  final FieldConfidence confidence;

  const ExtractedField(this.value, this.confidence);

  const ExtractedField.missing() : value = null, confidence = FieldConfidence.low;

  bool get isPresent => value != null;
}

/// Everything we managed to read off one receipt.
class ReceiptData {
  final ExtractedField<String> merchant;
  final ExtractedField<double> total;
  final ExtractedField<DateTime> date;
  final ExtractedField<String> category;

  /// The OCR text we parsed, kept so the review screen can offer a raw view
  /// when a field looks wrong.
  final String rawText;

  /// The individual lines of the bill, when the scan had position data and the
  /// receipt was laid out readably. Empty otherwise — plenty of receipts scan
  /// well enough for a total but not for a reliable item list, and an empty
  /// list says so honestly. Splitting by item is offered only when this is
  /// populated.
  final List<ReceiptItem> items;

  const ReceiptData({
    required this.merchant,
    required this.total,
    required this.date,
    required this.category,
    required this.rawText,
    this.items = const [],
  });

  const ReceiptData.empty()
      : merchant = const ExtractedField.missing(),
        total = const ExtractedField.missing(),
        date = const ExtractedField.missing(),
        category = const ExtractedField.missing(),
        rawText = '',
        items = const [];

  /// What the items add up to.
  double get itemsTotal =>
      items.fold<double>(0, (sum, i) => sum + i.lineTotal);

  /// Whether the items are worth offering as a split basis.
  ///
  /// They must exist, and they must roughly reconcile with the total the
  /// receipt printed. Items that do not add up mean rows were missed or
  /// double-read, and splitting by them would quietly misallocate money — so
  /// in that case we keep them visible for checking but do not treat them as
  /// a trustworthy basis for division.
  bool get itemsReconcile {
    if (items.isEmpty) return false;
    final printed = total.value;
    if (printed == null || printed <= 0) return false;
    // Items sum to at most the total: tax and charges are added after, so
    // items under the total is normal and items over it is a misread.
    // A fifth of the bill is about as much tax and service as any receipt
    // carries, so a shortfall beyond that means rows were missed.
    final ratio = itemsTotal / printed;
    return ratio > 0.8 && ratio <= 1.02;
  }

  /// How many of the four fields we actually found — the "We read N fields"
  /// line on the review screen.
  int get fieldsFound => [
        merchant.isPresent,
        total.isPresent,
        date.isPresent,
        category.isPresent,
      ].where((found) => found).length;

  /// True when anything needs a human eye before saving.
  bool get hasLowConfidence => [
        merchant.confidence,
        total.confidence,
        date.confidence,
        category.confidence,
      ].any((c) => c != FieldConfidence.high);
}

/// Parses OCR output into [ReceiptData]. Pure and synchronous so it can be
/// unit-tested against captured receipt text without a camera or ML Kit.
class ReceiptParser {
  /// Words that mark the line holding the amount we want. Ordered strongest
  /// first: "grand total" beats a bare "total", which beats "amount".
  static const _totalKeywords = <String>[
    'grand total',
    'total amount',
    'net payable',
    'amount payable',
    'net amount',
    'total',
    'amount due',
    'balance due',
    'amount',
  ];

  /// Lines that carry a number we must never mistake for the total.
  static const _excludedKeywords = <String>[
    'subtotal',
    'sub total',
    'sub-total',
    'tax',
    'gst',
    'cgst',
    'sgst',
    'igst',
    'vat',
    'service charge',
    'discount',
    'cash',
    'change',
    'tender',
    'tip',
    'round off',
    'rounding',
    'savings',
  ];

  /// Category guesses, keyed by the app's existing category names so the
  /// result can be handed straight to the expense form.
  static const _categoryHints = <String, List<String>>{
    'Food & drink': [
      'restaurant', 'cafe', 'coffee', 'pizza', 'burger', 'kitchen', 'grill',
      'bar', 'brew', 'bakery', 'food', 'dining', 'diner', 'eatery', 'biryani',
      'dhaba', 'canteen', 'juice', 'sweets', 'tea', 'chai', 'bistro',
    ],
    'Travel': [
      'uber', 'ola', 'taxi', 'cab', 'airlines', 'air', 'flight', 'railway',
      'irctc', 'metro', 'bus', 'travel', 'fuel', 'petrol', 'diesel', 'toll',
      'parking', 'indigo', 'spicejet', 'vistara',
    ],
    'Accommodation': [
      'hotel', 'resort', 'inn', 'lodge', 'stay', 'rooms', 'hostel', 'villa',
      'airbnb', 'oyo', 'guest house', 'suites',
    ],
    'Entertainment': [
      'cinema', 'movie', 'pvr', 'inox', 'theatre', 'theater', 'multiplex',
      'games', 'gaming', 'bowling', 'club', 'concert', 'tickets', 'park',
    ],
  };

  /// Reads [rawText] — the text ML Kit recognised, lines separated by `\n`.
  static ReceiptData parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return const ReceiptData.empty();

    final merchant = _extractMerchant(lines);
    final total = _extractTotal(lines);
    final date = _extractDate(lines);
    // The category is inferred from the merchant, so it can never be surer
    // than the name it was inferred from.
    final category = _inferCategory(merchant, rawText);

    return ReceiptData(
      merchant: merchant,
      total: total,
      date: date,
      category: category,
      rawText: rawText,
    );
  }

  /// Reads a receipt using the position of each piece of text as well as its
  /// content.
  ///
  /// The four headline fields are read exactly as [parse] reads them — from
  /// the text, which is what they respond to. The positions add the one thing
  /// text alone cannot give: which name belongs to which price, and therefore
  /// the item list.
  ///
  /// [tokens] are the recognised words with their boxes, and [imageWidth] the
  /// width of the image they were measured in. When the layout cannot be read
  /// this degrades to exactly the [parse] result rather than failing.
  static ReceiptData parseWithLayout({
    required String rawText,
    required List<OcrToken> tokens,
    required double imageWidth,
  }) {
    final base = parse(rawText);
    if (tokens.isEmpty || imageWidth <= 0) return base;

    final rows = buildRows(tokens);
    final itemised = extractItems(rows, imageWidth);

    // Re-read the total from the same VISUAL ROW as its keyword, instead of
    // the text-based reading above, which walks the flattened OCR string —
    // ML Kit's block order, not the page's visual order. On a bill whose
    // "Total" label and its amount land in different OCR blocks (common on
    // hotel folios and other tabular bills), the text version falls back to
    // "whatever line comes next in the flat text", which is really the start
    // of the next block — typically the first item's price. Reading the same
    // row's amount column instead fixes that regardless of block order.
    final geometryTotal = _extractTotalFromRows(rows, imageWidth);

    if (itemised.isEmpty && geometryTotal == null) return base;

    return ReceiptData(
      merchant: base.merchant,
      total: geometryTotal ?? base.total,
      date: base.date,
      category: base.category,
      rawText: base.rawText,
      items: itemised.items,
    );
  }

  /// Finds the payable total by reading the amount column on the same visual
  /// row as a total keyword, rather than guessing at nearby lines of flat
  /// text. See [parseWithLayout] for why that distinction matters.
  ///
  /// Returns null when there is no usable amount column, or no keyword row
  /// yields a number — callers should fall back to [_extractTotal] then.
  static ExtractedField<double>? _extractTotalFromRows(
    List<OcrRow> rows,
    double imageWidth,
  ) {
    if (rows.isEmpty) return null;
    final amountColumn = detectAmountColumn(rows, imageWidth);
    if (amountColumn == null) return null;

    final slack = imageWidth * 0.05;

    double? amountInRow(OcrRow row) {
      for (var t = row.tokens.length - 1; t >= 0; t--) {
        final value = parseAmountToken(row.tokens[t].text);
        if (value == null) continue;
        if (row.tokens[t].right < amountColumn - slack) continue;
        return value;
      }
      return null;
    }

    for (final keyword in _totalKeywords) {
      // Walk bottom-up: the payable total sits near the foot of the bill.
      for (var i = rows.length - 1; i >= 0; i--) {
        final lower = rows[i].text.toLowerCase();
        if (!lower.contains(keyword)) continue;
        if (_excludedKeywords.any(lower.contains)) continue;

        // The label and its amount are usually the same printed row. A folio
        // line that wrapped can still split them one row apart, so check the
        // row directly below before moving on to a weaker keyword.
        final amount = amountInRow(rows[i]) ??
            (i + 1 < rows.length ? amountInRow(rows[i + 1]) : null);
        if (amount == null || amount <= 0) continue;

        final strong = keyword.contains('total') || keyword.contains('payable');
        return ExtractedField(
          amount,
          strong ? FieldConfidence.high : FieldConfidence.medium,
        );
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Merchant
  // ---------------------------------------------------------------------------

  /// The shop name is nearly always the first real line of a receipt, above
  /// the address and the item table. We scan the top few lines and take the
  /// first that looks like a name rather than an address or a phone number.
  static ExtractedField<String> _extractMerchant(List<String> lines) {
    for (var i = 0; i < lines.length && i < 6; i++) {
      final line = lines[i];
      if (!_looksLikeMerchantName(line)) continue;

      final cleaned = _titleCase(line.replaceAll(RegExp(r'[*_=|]+'), ' ').trim());
      if (cleaned.isEmpty) continue;

      // The very first line is the usual spot; further down we are guessing
      // more, so say so rather than overstating it.
      return ExtractedField(
        cleaned,
        i == 0 ? FieldConfidence.high : FieldConfidence.medium,
      );
    }
    return const ExtractedField.missing();
  }

  static bool _looksLikeMerchantName(String line) {
    if (line.length < 3 || line.length > 40) return false;

    // Mostly digits: an address, a phone number, a GST number or a total.
    final digits = RegExp(r'\d').allMatches(line).length;
    if (digits > line.length / 3) return false;

    // An actual address, e.g. "user@domain.com" — never a shop's name.
    if (line.contains('@')) return false;

    final lower = line.toLowerCase();
    const skip = [
      'invoice', 'receipt', 'bill', 'tax', 'gst', 'phone', 'tel', 'www',
      'http', 'welcome', 'thank', 'order', 'table', 'date', 'time', 'cashier',
      'email', 'e-mail', 'contact', 'mobile', 'address',
    ];
    if (skip.any(lower.contains)) return false;

    // Needs at least a couple of letters to be a name at all.
    return RegExp(r'[A-Za-z]{2,}').hasMatch(line);
  }

  // ---------------------------------------------------------------------------
  // Total
  // ---------------------------------------------------------------------------

  /// Finds the amount actually payable.
  ///
  /// Keyword lines are searched first, strongest keyword first. Only if none
  /// matches do we fall back to the largest number on the receipt, which is a
  /// guess and is marked as one.
  static ExtractedField<double> _extractTotal(List<String> lines) {
    for (final keyword in _totalKeywords) {
      // Walk bottom-up: the payable total sits near the foot of the receipt,
      // and a keyword reappearing there is the one that counts.
      for (var i = lines.length - 1; i >= 0; i--) {
        final lower = lines[i].toLowerCase();
        if (!lower.contains(keyword)) continue;
        if (_excludedKeywords.any(lower.contains)) continue;

        // The amount usually trails the label on the same line; if that line
        // has no number, receipts often wrap it onto the next one.
        final amount = _lastAmountIn(lines[i]) ??
            (i + 1 < lines.length ? _lastAmountIn(lines[i + 1]) : null);
        if (amount == null || amount <= 0) continue;

        // An explicit "grand total" is as good as this gets; a bare "amount"
        // is a weaker signal and should still be checked.
        final strong = keyword.contains('total') || keyword.contains('payable');
        return ExtractedField(
          amount,
          strong ? FieldConfidence.high : FieldConfidence.medium,
        );
      }
    }

    // Nothing labelled — fall back to the biggest figure we can see.
    final all = <double>[];
    for (final line in lines) {
      if (_excludedKeywords.any(line.toLowerCase().contains)) continue;
      all.addAll(_amountsIn(line));
    }
    if (all.isEmpty) return const ExtractedField.missing();

    all.sort();
    return ExtractedField(all.last, FieldConfidence.low);
  }

  /// Every number in [line] that could be a money amount.
  static List<double> _amountsIn(String line) {
    // Optional currency mark, thousands separators, optional decimals.
    //
    // The comma-grouped branch requires AT LEAST ONE comma group (`+`, not
    // `*`): with `*` it also matched zero groups, so it "succeeded" after
    // just the first 1-3 digits of any longer comma-less number and never
    // fell through to try the plain-digits branch — "4400.00" silently read
    // as 440.0. Bills that print totals without a thousands separator (or
    // where a thin comma glyph just got missed by OCR) are common, so this
    // is not a rare edge case.
    final pattern = RegExp(
      r'(?:₹|rs\.?|inr|\$)?\s*((?:\d{1,3}(?:,\d{2,3})+|\d+)(?:\.\d{1,2})?)',
      caseSensitive: false,
    );

    final out = <double>[];
    for (final match in pattern.allMatches(line)) {
      final raw = match.group(1)?.replaceAll(',', '');
      if (raw == null) continue;
      final value = double.tryParse(raw);
      if (value == null) continue;

      // Bare small integers on a receipt are usually quantities, item counts
      // or a line number rather than money.
      final hasDecimal = raw.contains('.');
      final hasSymbol = match.group(0)!.contains(RegExp(r'[₹$]|rs|inr', caseSensitive: false));
      if (!hasDecimal && !hasSymbol && value < 10) continue;

      // Guard against a date or a phone number being read as money.
      if (value > 10000000) continue;

      out.add(value);
    }
    return out;
  }

  /// The rightmost amount on a line — on a receipt row the figure that matters
  /// is the one in the right-hand column.
  static double? _lastAmountIn(String line) {
    final amounts = _amountsIn(line);
    return amounts.isEmpty ? null : amounts.last;
  }

  // ---------------------------------------------------------------------------
  // Date
  // ---------------------------------------------------------------------------

  static const _monthNames = <String, int>{
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Looks for a date in the common receipt formats. A future date or one
  /// absurdly far back means we misread it, so those are rejected outright.
  static ExtractedField<DateTime> _extractDate(List<String> lines) {
    final text = lines.join('\n');

    // "12 Aug 2026" / "Aug 12, 2026" — unambiguous, so trusted most.
    final named = RegExp(
      r'(\d{1,2})\s*[-/ ]\s*([A-Za-z]{3,9})\s*[-/, ]\s*(\d{2,4})'
      r'|([A-Za-z]{3,9})\s+(\d{1,2})\s*,?\s*(\d{4})',
    ).firstMatch(text);
    if (named != null) {
      final DateTime? parsed;
      if (named.group(1) != null) {
        parsed = _build(
          int.tryParse(named.group(1)!),
          _monthNames[named.group(2)!.toLowerCase().substring(0, 3)],
          int.tryParse(named.group(3)!),
        );
      } else {
        parsed = _build(
          int.tryParse(named.group(5)!),
          _monthNames[named.group(4)!.toLowerCase().substring(0, 3)],
          int.tryParse(named.group(6)!),
        );
      }
      if (parsed != null) return ExtractedField(parsed, FieldConfidence.high);
    }

    // All-numeric: 12/08/2026. Day-first and month-first are impossible to
    // tell apart when both are <= 12, so that case is only ever "medium".
    final numeric =
        RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(text);
    if (numeric != null) {
      final a = int.tryParse(numeric.group(1)!);
      final b = int.tryParse(numeric.group(2)!);
      final year = int.tryParse(numeric.group(3)!);

      // Read as day/month (the Indian convention this app targets) unless the
      // second number cannot be a month, which forces the US month/day order.
      final monthFirst = (b ?? 0) > 12;
      final parsed = monthFirst
          ? _build(b, a, year)
          : _build(a, b, year);

      if (parsed != null) {
        // When both numbers could be a month, the order is genuinely unknown
        // and the user should confirm it.
        final ambiguous = (a ?? 0) <= 12 && (b ?? 0) <= 12;
        return ExtractedField(
          parsed,
          ambiguous ? FieldConfidence.medium : FieldConfidence.high,
        );
      }
    }

    return const ExtractedField.missing();
  }

  /// Builds a date, rejecting anything that cannot be a receipt's date.
  static DateTime? _build(int? day, int? month, int? year) {
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final fullYear = year < 100 ? 2000 + year : year;
    if (fullYear < 2000 || fullYear > 2100) return null;

    final date = DateTime(fullYear, month, day);
    // Round-tripping catches 31 February and friends.
    if (date.month != month || date.day != day) return null;

    // A receipt cannot be from tomorrow; allow a day's slack for time zones.
    if (date.isAfter(DateTime.now().add(const Duration(days: 1)))) return null;
    if (date.isBefore(DateTime(2000))) return null;

    return date;
  }

  // ---------------------------------------------------------------------------
  // Category
  // ---------------------------------------------------------------------------

  /// Guesses a category from the merchant name, falling back to the body text.
  /// This is always a guess, so it never claims high confidence.
  static ExtractedField<String> _inferCategory(
    ExtractedField<String> merchant,
    String rawText,
  ) {
    final name = (merchant.value ?? '').toLowerCase();
    for (final entry in _categoryHints.entries) {
      if (entry.value.any(name.contains)) {
        return ExtractedField(entry.key, FieldConfidence.medium);
      }
    }

    // Nothing in the name: the body may still mention what was bought.
    final body = rawText.toLowerCase();
    for (final entry in _categoryHints.entries) {
      if (entry.value.any(body.contains)) {
        return ExtractedField(entry.key, FieldConfidence.low);
      }
    }

    // Most shared receipts are meals, so that is the useful default — but it
    // is a default, not a reading, and is flagged for checking.
    return const ExtractedField('Food & drink', FieldConfidence.low);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// SHOUTED receipt headers become "Curry Grill" rather than "CURRY GRILL".
  static String _titleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.length == 1
            ? w.toUpperCase()
            : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}
