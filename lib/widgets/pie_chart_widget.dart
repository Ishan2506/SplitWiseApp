import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import 'common_widgets.dart';

/// One wedge of a [PSPieChart]: what it represents, how much, and the colour
/// it is drawn in.
class PieSlice {
  final String label;
  final double value;
  final Color color;

  const PieSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// A donut chart with the total in the middle, plus a legend listing each
/// slice's share. Hand-painted rather than pulled in from a package: the app
/// has no charting dependency yet, and this stays a couple of small widgets
/// styled to match everything else here.
class PSPieChart extends StatelessWidget {
  final List<PieSlice> slices;
  final String currencySymbol;

  /// Shown in the centre of the ring — usually "Total".
  final String centerLabel;

  const PSPieChart({
    super.key,
    required this.slices,
    required this.currencySymbol,
    this.centerLabel = 'Total',
  });

  double get _total => slices.fold<double>(0, (sum, s) => sum + s.value);

  @override
  Widget build(BuildContext context) {
    final total = _total;

    return Column(
      children: [
        SizedBox(
          height: 200,
          width: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(200, 200),
                painter: _PieChartPainter(slices: slices, total: total),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatMoney(total, symbol: currencySymbol),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    centerLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Legend(slices: slices, total: total, currencySymbol: currencySymbol),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<PieSlice> slices;
  final double total;

  static const double _strokeWidth = 30;

  _PieChartPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - _strokeWidth) / 2;

    if (total <= 0 || slices.isEmpty) {
      final paint = Paint()
        ..color = AppColors.bgSubtle
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    // Start at the top (12 o'clock) rather than the mathematical zero angle
    // (3 o'clock), which is where a viewer's eye actually starts reading a
    // ring chart.
    var startAngle = -3.14159265 / 2;

    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * 3.14159265;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}

/// Colour dot, label, amount and share for every slice — sorted largest
/// first, since that is the order a reader wants to scan a breakdown in.
class _Legend extends StatelessWidget {
  final List<PieSlice> slices;
  final double total;
  final String currencySymbol;

  const _Legend({
    required this.slices,
    required this.total,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...slices]..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (final slice in ordered)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: slice.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    slice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  formatMoney(slice.value, symbol: currencySymbol),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 42,
                  child: Text(
                    total > 0
                        ? '${(slice.value / total * 100).toStringAsFixed(0)}%'
                        : '0%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
