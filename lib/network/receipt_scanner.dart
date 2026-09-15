import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
      return ReceiptParser.parse(recognized.text);
    } on ReceiptScanException {
      rethrow;
    } catch (e) {
      throw ReceiptScanException('Could not read the receipt: $e');
    }
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
