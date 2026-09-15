import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../network/receipt_scanner.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'receipt_review_screen.dart';

/// Step 1 of adding an expense from a receipt: get a photo of it.
///
/// The screen is deliberately dark and chrome-free — it is a viewfinder, and
/// the only decisions here are "take one" or "pick one". Everything the OCR
/// gets wrong is corrected on the next screen, so nothing is asked twice.
///
/// Pops with `true` once an expense has been saved further down the flow, so
/// the caller knows to refresh.
class ReceiptScanScreen extends StatefulWidget {
  /// Group the resulting expense belongs to.
  final String groupId;

  const ReceiptScanScreen({super.key, required this.groupId});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final ImagePicker _picker = ImagePicker();

  /// True while OCR is running, which blocks a second capture.
  bool _isProcessing = false;

  @override
  void dispose() {
    // Let go of the ML Kit model — the user is leaving the scan flow.
    ReceiptScanner.dispose();
    super.dispose();
  }

  Future<void> _capture(ImageSource source) async {
    if (_isProcessing) return;

    try {
      final shot = await _picker.pickImage(
        source: source,
        // Receipts are text on paper: a smaller image still OCRs well and is
        // much faster to process than a full-resolution photo.
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (shot == null || !mounted) return;

      setState(() => _isProcessing = true);
      final data = await ReceiptScanner.scan(shot.path);
      if (!mounted) return;

      // Nothing readable at all is worth saying plainly rather than opening a
      // review screen with four empty fields.
      if (data.fieldsFound == 0) {
        setState(() => _isProcessing = false);
        showAppSnack(
          context,
          'Could not read that receipt — try a straighter, brighter shot',
          success: false,
        );
        return;
      }

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            groupId: widget.groupId,
            data: data,
            imagePath: shot.path,
          ),
        ),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // The expense was saved downstream: this screen's job is done too.
      if (saved == true) Navigator.pop(context, true);
    } on ReceiptScanException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      showAppSnack(context, e.message, success: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      showAppSnack(context, 'Could not open the camera', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(
                  onClose: () => Navigator.pop(context),
                  onUpload: () => _capture(ImageSource.gallery),
                ),
                const Expanded(child: _FramingGuide()),
                _ShutterBar(
                  onCapture: () => _capture(ImageSource.camera),
                  onUpload: () => _capture(ImageSource.gallery),
                  enabled: !_isProcessing,
                ),
              ],
            ),
            if (_isProcessing) const _ReadingOverlay(),
          ],
        ),
      ),
    );
  }
}

/// Close on the left, upload on the right — the two ways out of the camera.
class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onUpload;

  const _TopBar({required this.onClose, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          _CircleButton(icon: Icons.close_rounded, onTap: onClose),
          const Expanded(
            child: Text(
              'Scan receipt',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: onUpload,
            child: const Text(
              'Upload',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}

/// The dashed frame showing where to put the receipt.
///
/// This is a guide, not a crop: ML Kit reads the whole photo. Framing still
/// matters because a receipt that fills the shot OCRs far better than one
/// photographed from across the table.
class _FramingGuide extends StatelessWidget {
  const _FramingGuide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _DashedBorderPainter(),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 44,
                      color: Colors.white24,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Point at the receipt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Fit the whole receipt in the frame',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded dashed rectangle, drawn by hand because Flutter has no dashed border.
class _DashedBorderPainter extends CustomPainter {
  static const double _dash = 9;
  static const double _gap = 7;
  static const double _radius = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );

    // Walk the outline and stroke alternating segments.
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

/// Gallery thumbnail, shutter, and the flash affordance.
class _ShutterBar extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback onUpload;
  final bool enabled;

  const _ShutterBar({
    required this.onCapture,
    required this.onUpload,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SquareAction(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            onTap: enabled ? onUpload : null,
          ),
          _ShutterButton(onTap: enabled ? onCapture : null),
          // The system camera owns the flash, so this opens it rather than
          // pretending to toggle a torch we do not control.
          _SquareAction(
            icon: Icons.bolt_rounded,
            label: 'Flash',
            onTap: enabled ? onCapture : null,
          ),
        ],
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SquareAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

/// The accent-filled shutter, ringed the way a camera app rings it.
class _ShutterButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _ShutterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Capture receipt',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap == null
                  ? AppColors.primaryAccent.withValues(alpha: 0.5)
                  : AppColors.primaryAccent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Covers the viewfinder while OCR runs so the shutter cannot be tapped twice.
class _ReadingOverlay extends StatelessWidget {
  const _ReadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink.withValues(alpha: 0.82),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(AppColors.primaryAccent),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Reading the receipt…',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
