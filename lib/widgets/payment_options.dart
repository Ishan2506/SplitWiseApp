import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/payment_links.dart';
import 'common_widgets.dart';

/// "Pay ₹500 via UPI" / "Pay via PayPal" for whoever is being paid.
///
/// Opens the payer's own app with everything pre-filled, then — once they
/// come back — asks whether it went through. Only a "yes" calls [onPaid];
/// the caller records the settlement, so a payment abandoned halfway never
/// marks anything as settled.
class PaymentOptions extends StatefulWidget {
  final String payeeName;
  final String upiId;
  final String paypalMe;
  final String currency;
  final String currencySymbol;

  /// Read at tap time, so an amount the user has just edited is what gets
  /// pre-filled.
  final double Function() amount;

  /// Shown in the UPI app as the payment note.
  final String? note;

  /// Called after the payer confirms the payment went through.
  final Future<void> Function(PaymentMethod method) onPaid;

  /// Checked before leaving for the payment app; a non-null message is shown
  /// instead, so nobody pays an amount the app would then refuse to record.
  final String? Function()? validate;

  const PaymentOptions({
    super.key,
    required this.payeeName,
    required this.upiId,
    required this.paypalMe,
    required this.currency,
    required this.currencySymbol,
    required this.amount,
    required this.onPaid,
    this.note,
    this.validate,
  });

  @override
  State<PaymentOptions> createState() => _PaymentOptionsState();
}

class _PaymentOptionsState extends State<PaymentOptions> {
  bool _busy = false;

  bool get _canUpi =>
      widget.upiId.isNotEmpty && PaymentLinks.supportsUpi(widget.currency);
  bool get _canPaypal => widget.paypalMe.isNotEmpty;

  Future<void> _pay(PaymentMethod method) async {
    final problem = widget.validate?.call();
    if (problem != null) {
      showAppSnack(context, problem, success: false);
      return;
    }
    final amount = widget.amount();
    if (amount <= 0) {
      showAppSnack(context, 'Enter an amount greater than zero', success: false);
      return;
    }

    final uri = method == PaymentMethod.upi
        ? PaymentLinks.upi(
            upiId: widget.upiId,
            payeeName: widget.payeeName,
            amount: amount,
            note: widget.note,
          )
        : PaymentLinks.paypal(
            username: widget.paypalMe,
            amount: amount,
            currency: widget.currency,
          );

    setState(() => _busy = true);
    final opened = await PaymentLinks.openAndWaitForReturn(uri);
    if (!mounted) return;

    if (!opened) {
      setState(() => _busy = false);
      showAppSnack(
        context,
        method == PaymentMethod.upi
            ? 'No UPI app found on this phone — copy the UPI ID instead'
            : 'Could not open PayPal',
        success: false,
      );
      return;
    }

    final amountText =
        formatMoney(amount, symbol: widget.currencySymbol, decimals: true);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Did the payment go through?'),
        content: Text(
          'If ${widget.payeeName} received $amountText via '
          '${method.label}, we will mark it as settled for everyone.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Not yet'),
          ),
          PSButton(
            label: 'Yes, mark settled',
            size: PSButtonSize.small,
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.onPaid(method);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _copyUpiId() {
    Clipboard.setData(ClipboardData(text: widget.upiId));
    showAppSnack(context, 'UPI ID copied');
  }

  @override
  Widget build(BuildContext context) {
    if (!_canUpi && !_canPaypal) {
      return _Hint(
        text: widget.upiId.isNotEmpty
            ? 'UPI only works for rupee payments. Pay ${widget.payeeName} '
                'however suits you, then record it below.'
            : '${widget.payeeName} hasn\'t added a UPI ID or PayPal.me yet. '
                'Pay them however suits you, then record it below.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_canUpi)
          PSButton(
            label: 'Pay via UPI app',
            icon: Icons.account_balance_rounded,
            onPressed: _busy ? null : () => _pay(PaymentMethod.upi),
          ),
        if (_canUpi && _canPaypal) const SizedBox(height: AppSpacing.xs),
        if (_canPaypal)
          PSButton(
            label: 'Pay via PayPal',
            icon: Icons.open_in_new_rounded,
            variant: _canUpi
                ? PSButtonVariant.secondary
                : PSButtonVariant.primary,
            onPressed: _busy ? null : () => _pay(PaymentMethod.paypal),
          ),
        if (_canUpi) ...[
          const SizedBox(height: AppSpacing.xxs),
          Center(
            child: TextButton.icon(
              onPressed: _copyUpiId,
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: Text(
                widget.upiId,
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 17, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
