import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// How a settlement's money moved. The app never moves money itself: `upi`
/// and `paypal` mean the payer tapped through a pre-filled link we built and
/// then confirmed it went through. Wire values match the server's enum.
enum PaymentMethod { cash, upi, paypal }

extension PaymentMethodInfo on PaymentMethod {
  String get wireValue => name;

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.upi => 'UPI',
        PaymentMethod.paypal => 'PayPal',
      };

  /// What gets stored on the settlement as its note.
  String get note => switch (this) {
        PaymentMethod.cash => 'Paid in cash, outside the app',
        PaymentMethod.upi => 'Paid via UPI',
        PaymentMethod.paypal => 'Paid via PayPal',
      };
}

/// Builds pre-filled payment links. No payment provider is involved — these
/// are plain deep links that hand off to whatever app the payer has.
class PaymentLinks {
  PaymentLinks._();

  /// UPI moves rupees only.
  static bool supportsUpi(String currency) =>
      currency.toUpperCase().trim() == 'INR';

  /// `upi://pay?...` per the NPCI deep-link spec. Opens the payer's UPI app
  /// (GPay, PhonePe, Paytm, BHIM...) with payee, amount and note filled in.
  ///
  /// Built by hand rather than with `Uri(queryParameters:)`, which encodes
  /// spaces as `+` — several UPI apps show that literally in the payee name.
  static Uri upi({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  }) {
    final params = <String>[
      // Validated as handle@psp on save, so it is safe unencoded — and some
      // apps refuse a `%40` in place of the `@`.
      'pa=${upiId.trim()}',
      'pn=${Uri.encodeComponent(payeeName.trim())}',
      'am=${amount.toStringAsFixed(2)}',
      'cu=INR',
      if (note != null && note.trim().isNotEmpty)
        // Apps truncate long notes inconsistently; keep it short and safe.
        'tn=${Uri.encodeComponent(_truncate(note.trim(), 40))}',
    ];
    return Uri.parse('upi://pay?${params.join('&')}');
  }

  /// `https://paypal.me/<user>/<amount><CURRENCY>` — opens the PayPal app
  /// when installed, the browser otherwise.
  static Uri paypal({
    required String username,
    required double amount,
    required String currency,
  }) {
    final user = Uri.encodeComponent(username.trim());
    return Uri.parse(
      'https://paypal.me/$user/${amount.toStringAsFixed(2)}${currency.toUpperCase()}',
    );
  }

  /// Opens [uri] outside the app. False when nothing can handle it — e.g. no
  /// UPI app installed — so the caller can say so rather than fail silently.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Opens [uri], then completes once the user is back in this app — the
  /// moment to ask whether the payment actually went through.
  ///
  /// Resolves to false straight away if nothing could open the link.
  static Future<bool> openAndWaitForReturn(Uri uri) async {
    final returned = Completer<void>();
    var leftApp = false;
    final listener = AppLifecycleListener(
      onHide: () => leftApp = true,
      onPause: () => leftApp = true,
      onResume: () {
        if (!returned.isCompleted) returned.complete();
      },
    );

    try {
      final opened = await open(uri);
      if (!opened) return false;

      // Some handlers (a browser tab on web, a chooser that is dismissed at
      // once) never take the app to the background. If we haven't left
      // shortly after launching, there's no resume coming to wait for.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (leftApp) await returned.future;
      return true;
    } finally {
      listener.dispose();
    }
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
