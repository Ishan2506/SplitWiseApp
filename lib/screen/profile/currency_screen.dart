import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/currencies.dart';
import '../../widgets/common_widgets.dart';

/// Picks the currency new groups and personal totals default to.
///
/// Saving goes straight to the server rather than waiting for a Save button:
/// there is only one value here, so a tap is the whole intent.
class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  /// The code currently being written to the server, if any. Used to show a
  /// spinner on that one row and to ignore further taps while it is in flight.
  String? _saving;

  Future<void> _select(String code) async {
    final state = context.read<StateManager>();
    final current = state.currentUserModel?.preferredCurrency ?? kDefaultCurrencyCode;
    if (_saving != null || code == current) return;

    setState(() => _saving = code);
    final result = await state.updateProfile(preferredCurrency: code);

    if (!mounted) return;
    setState(() => _saving = null);

    if (result['success'] == true) {
      showAppSnack(context, '${currencyFor(code).name} is now your default');
    } else {
      showAppSnack(
        context,
        (result['message'] ?? 'Could not change your currency').toString(),
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        context.watch<StateManager>().currentUserModel?.preferredCurrency ??
            kDefaultCurrencyCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Currency')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'New groups you create start in this currency, and it is used '
                  'for your personal totals.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Existing groups keep the currency they were created with. '
                  'Amounts are not converted.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PSCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final c in kCurrencies)
                        _CurrencyRow(
                          currency: c,
                          isSelected: c.code == selected,
                          isSaving: _saving == c.code,
                          isLast: c.code == kCurrencies.last.code,
                          onTap: () => _select(c.code),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  final AppCurrency currency;
  final bool isSelected;
  final bool isSaving;
  final bool isLast;
  final VoidCallback onTap;

  const _CurrencyRow({
    required this.currency,
    required this.isSelected,
    required this.isSaving,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.bgSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    currency.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primaryAccent
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currency.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currency.code,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryAccent,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 68),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),
      ],
    );
  }
}
