/// The positional half of receipt reading: where each piece of text sits on
/// the page, and how to rebuild the bill's visual table from that.
///
/// ML Kit hands back text as blocks → lines → elements, each with a bounding
/// box, and the order it returns them in is block order, not reading order.
/// On a receipt an item's name and its price are separated by a wide gap, so
/// they routinely land in different blocks. Anything that reads the flattened
/// `.text` string has already lost the fact that they belong to the same row,
/// which is why item extraction needs the boxes and the four-field parse does
/// not.
library;

/// One horizontal slice of the receipt, and the text sitting in it.
///
/// [x] and [y] are the top-left corner, matching ML Kit's own convention, so
/// boxes can be handed over without translation.
class OcrToken {
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;

  const OcrToken({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Where the token ends horizontally. This is the edge that matters for
  /// column detection: receipt amounts are right-aligned, so "9" and "1,240"
  /// share a right edge while their left edges are nowhere near each other.
  double get right => x + width;

  /// The vertical middle, used to decide which row a token belongs to. More
  /// stable than the top edge, which shifts with font size within a row.
  double get centerY => y + height / 2;
}

/// A single visual row of the receipt: the tokens that sit on one line of the
/// printed page, ordered left to right.
class OcrRow {
  final List<OcrToken> tokens;

  const OcrRow(this.tokens);

  /// The row's text with single spaces between tokens — what a human would
  /// read off that line of the bill.
  String get text => tokens.map((t) => t.text).join(' ').trim();

  double get centerY => tokens.isEmpty
      ? 0
      : tokens.map((t) => t.centerY).reduce((a, b) => a + b) / tokens.length;
}

/// Rebuilds the receipt's rows from loose, arbitrarily ordered tokens.
///
/// Tokens are grouped by vertical position: two tokens whose centres are
/// closer together than a tolerance are on the same printed line. The
/// tolerance is derived from the *median* token height rather than the mean,
/// because a large merchant name in the header would drag a mean upward far
/// enough to start merging genuine item rows together.
///
/// Returns rows top-to-bottom, each ordered left-to-right.
List<OcrRow> buildRows(List<OcrToken> tokens) {
  final usable = tokens.where((t) => t.text.trim().isNotEmpty).toList();
  if (usable.isEmpty) return const [];

  final heights = usable.map((t) => t.height).where((h) => h > 0).toList()
    ..sort();
  final medianHeight =
      heights.isEmpty ? 10.0 : heights[heights.length ~/ 2];
  // Six tenths of a line height: loose enough to hold a row together when the
  // photo is slightly skewed, tight enough not to swallow the next row.
  final tolerance = medianHeight * 0.6;

  final sorted = [...usable]..sort((a, b) => a.centerY.compareTo(b.centerY));

  final rows = <List<OcrToken>>[];
  for (final token in sorted) {
    final current = rows.isEmpty ? null : rows.last;
    if (current != null) {
      // Compare against the row's running centre, not its last token, so one
      // outlier cannot drag the row's baseline down the page.
      final rowCenter =
          current.map((t) => t.centerY).reduce((a, b) => a + b) / current.length;
      if ((token.centerY - rowCenter).abs() < tolerance) {
        current.add(token);
        continue;
      }
    }
    rows.add([token]);
  }

  return rows
      .map((r) => OcrRow(r..sort((a, b) => a.x.compareTo(b.x))))
      .toList();
}

/// Finds the horizontal position of the amount column.
///
/// Amounts on a receipt are right-aligned into a narrow band, so the right
/// edges of the numeric tokens cluster tightly around one x position. We take
/// the densest such cluster in the right-hand part of the page.
///
/// Returns null when there is nothing to cluster — too few numbers, or none of
/// them on the right. A null result means "this does not look like a table",
/// and callers should not try to read items from it; that is a better outcome
/// than inventing a column position and confidently misreading every row.
double? detectAmountColumn(List<OcrRow> rows, double imageWidth) {
  if (imageWidth <= 0) return null;

  final rightEdges = <double>[];
  for (final row in rows) {
    for (final token in row.tokens) {
      if (parseAmountToken(token.text) == null) continue;
      // Only the right-hand side of the page can hold the amount column;
      // numbers further left are quantities, rates or part of an address.
      if (token.right < imageWidth * 0.5) continue;
      rightEdges.add(token.right);
    }
  }

  // A single number on the right is not a column — it is a date, a phone
  // number, or one stray figure. Two is the fewest that can establish
  // alignment, which a short bill (one item and a total) genuinely has.
  if (rightEdges.length < 2) return null;

  final bandwidth = imageWidth * 0.06;

  // Cluster the right edges, then prefer the RIGHTMOST cluster rather than the
  // largest. A bill with a rate column has two competing clusters — rates and
  // amounts — and they may be the same size, but the amount is always the
  // outer one. Picking by size would read the rate as the line's cost and
  // undercount the bill.
  var bestCenter = rightEdges.first;
  var bestCount = 0;

  for (final candidate in rightEdges) {
    final near =
        rightEdges.where((e) => (e - candidate).abs() <= bandwidth).toList();
    if (near.length < 2) continue;
    final center = near.reduce((a, b) => a + b) / near.length;
    if (center > bestCenter || bestCount == 0) {
      bestCenter = center;
      bestCount = near.length;
    }
  }

  // Nothing formed a cluster of two or more: the numbers on the right are not
  // aligned with each other, so there is no column to speak of.
  return bestCount >= 2 ? bestCenter : null;
}

/// Reads a single token as a money amount, or null if it is not one.
///
/// Deliberately strict: it matches a whole token only, so "2x" and "GST18%"
/// are rejected rather than yielding 2 and 18. Grouping separators are allowed
/// in either the Indian (1,23,456) or Western (123,456) style, since receipts
/// print both.
double? parseAmountToken(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[₹]'), '');
  if (cleaned.isEmpty) return null;

  final match = RegExp(
    r'^(?:(?:rs|inr)\.?\s*)?(\d{1,3}(?:,\d{2,3})*|\d+)(?:\.(\d{1,2}))?\s*(?:/-)?$',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (match == null) return null;

  final whole = match.group(1)!.replaceAll(',', '');
  final fraction = match.group(2);
  final value = double.tryParse(fraction == null ? whole : '$whole.$fraction');
  if (value == null || !value.isFinite) return null;

  // A single line on a shared food or shopping bill does not run to seven
  // figures; a number that large is a phone number or a GST id misread.
  if (value > 1000000) return null;

  return value;
}
