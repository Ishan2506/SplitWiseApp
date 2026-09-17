import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/receipt_geometry.dart';
import '../utils/receipt_parser.dart';

/// Reads a receipt photo with on-device OCR.
///
/// ML Kit runs locally, so the photo never leaves the phone and scanning works
/// with no signal — worth having when the bill arrives in a basement
/// restaurant. The trade-off is that it is unavailable on web, which
/// [isSupported] reports so the UI can hide the entry point rather than fail
/// at the camera.
class ReceiptScanner {
  /// Text recognition is Android/iOS only. Web and desktop have no ML Kit
  /// binary to call into.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// One recognizer reused across scans: construction loads a model, which is
  /// slow enough to be worth keeping alive between shots.
  static TextRecognizer? _recognizer;

  static TextRecognizer get _instance =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans the image at [imagePath] and pulls out the expense fields.
  ///
  /// Returns an empty [ReceiptData] when nothing readable is found, so callers
  /// get "we could not read this" rather than an exception. Genuine failures
  /// (a missing file, an unreadable format) throw [ReceiptScanException] so the
  /// screen can tell the two apart.
  static Future<ReceiptData> scan(String imagePath) async {
    if (!isSupported) {
      throw const ReceiptScanException(
        'Receipt scanning needs the camera on Android or iOS.',
      );
    }

    if (!await File(imagePath).exists()) {
      throw const ReceiptScanException('That image could not be opened.');
    }

    try {
      final recognized =
          await _instance.processImage(InputImage.fromFilePath(imagePath));

      // ML Kit returns text in block order, which is not the order a person
      // reads the bill in: an item's name and its price sit far apart and
      // routinely land in different blocks. Passing the bounding boxes along,
      // rather than just the flattened text, is what lets the parser put each
      // name back with its own price and read the bill as a table.
      final tokens = <OcrToken>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          // Elements are individual words. They separate an item's name from
          // its quantity and price within a row, which whole-line boxes
          // cannot do.
          final parts = line.elements.isNotEmpty
              ? line.elements
                  .map((e) => (text: e.text, box: e.boundingBox))
                  .toList()
              : [(text: line.text, box: line.boundingBox)];

          for (final part in parts) {
            tokens.add(OcrToken(
              text: part.text,
              x: part.box.left.toDouble(),
              y: part.box.top.toDouble(),
              width: part.box.width.toDouble(),
              height: part.box.height.toDouble(),
            ));
          }
        }
      }

      // Column detection works in proportions of the page, so it needs the
      // page's true width — the text's own extent would shrink the page to
      // whatever was printed on it and skew every proportion.
      final imageWidth = await _widthOf(imagePath, tokens);

      return ReceiptParser.parseWithLayout(
        rawText: recognized.text,
        tokens: tokens,
        imageWidth: imageWidth,
      );
    } on ReceiptScanException {
      rethrow;
    } catch (e) {
      throw ReceiptScanException('Could not read the receipt: $e');
    }
  }

  /// The width of the scanned image in pixels.
  ///
  /// Falls back to the extent of the recognised text if the file cannot be
  /// decoded. That is a worse estimate — it treats the widest line as the page
  /// edge — but it keeps item reading working rather than losing it to an
  /// unreadable header.
  static Future<double> _widthOf(String imagePath, List<OcrToken> tokens) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final descriptor = await ui.ImageDescriptor.encoded(
        await ui.ImmutableBuffer.fromUint8List(bytes),
      );
      final width = descriptor.width.toDouble();
      descriptor.dispose();
      if (width > 0) return width;
    } catch (_) {
      // Fall through to the text-extent estimate below.
    }

    if (tokens.isEmpty) return 0;
    return tokens.map((t) => t.right).reduce((a, b) => a > b ? a : b);
  }

  /// Frees the ML Kit model. Called when the scan flow closes — holding the
  /// recognizer open keeps native memory allocated for a feature the user may
  /// not return to.
  static Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}

/// A scan that could not be completed, with a message fit to show the user.
class ReceiptScanException implements Exception {
  final String message;
  const ReceiptScanException(this.message);

  @override
  String toString() => message;
}
