import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'group_widgets.dart';
import 'invite_link_handler.dart';

/// Points the camera at a group's QR code and returns the invite code it holds.
///
/// Pops with the code as a `String`, or null if the user backs out. The caller
/// decides what to do with it — normally opening the join screen.
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  /// Guards against the detector firing again while we are already popping.
  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final code = _extractCode(raw);
      if (code == null) continue;

      _handled = true;
      Navigator.pop(context, code);
      return;
    }
  }

  /// Accepts the full invite URL, the deep link, or a bare code typed into a
  /// generic QR generator.
  static String? _extractCode(String raw) {
    final trimmed = raw.trim();

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final fromLink = inviteCodeFromUri(uri);
      if (fromLink != null && fromLink.isNotEmpty) {
        return fromLink.toUpperCase();
      }
    }

    // A bare code: 8 characters from the invite alphabet.
    if (RegExp(r'^[A-Za-z2-9]{8}$').hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan invite code',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: _torchOn ? 'Turn flash off' : 'Turn flash on',
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? GroupColors.warning : Colors.white,
            ),
            onPressed: () async {
              await _controller.toggleTorch();
              if (mounted) setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _buildError(error),
          ),
          // A cut-out frame to aim with.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border:
                      Border.all(color: GroupColors.accent, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Line up the group’s QR code inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(MobileScannerException error) {
    // Most commonly a denied camera permission — say so plainly and give the
    // user the manual route instead of a dead screen.
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              permissionDenied ? Icons.no_photography : Icons.error_outline,
              color: GroupColors.negative,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              permissionDenied
                  ? 'Splitwise needs camera access to scan invite codes.'
                  : 'The camera could not be started.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              'You can still join by entering the code by hand.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GroupColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style:
                  ElevatedButton.styleFrom(backgroundColor: GroupColors.primary),
              child: const Text('Go back',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
