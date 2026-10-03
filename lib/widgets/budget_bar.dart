import 'package:flutter/material.dart';

import '../model/group_model.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/expense_categories.dart';
import 'common_widgets.dart';

/// Colour for a budget at [percent] used: green while comfortable, amber
/// from the 80% warning line, red once it's gone. Same thresholds as the
/// push alerts, so what the bar shows and what members were told agree.
Color budgetColorFor(double percent) {
  if (percent >= 100) return AppColors.negative;
  if (percent >= 80) return AppColors.warning;
  return AppColors.success;
}

/// One budget: what it's for, how much has gone, and a progress bar.
class BudgetBar extends StatelessWidget {
  final BudgetStatus budget;
  final String currencySymbol;

  /// Drops the "left / over by" line, for tight spaces.
  final bool compact;

  const BudgetBar({
    super.key,
    required this.budget,
    required this.currencySymbol,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = budgetColorFor(budget.percent);
    final ratio = budget.amount > 0
        ? (budget.spent / budget.amount).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              budget.isOverall
                  ? Icons.account_balance_wallet_outlined
                  : iconForCategory(budget.category),
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                budget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${budget.percent.round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: AppColors.bgSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        // Below the bar rather than beside the label: lakh-sized figures
        // don't fit next to a category name on a small phone.
        Text(
          [
            '${formatMoney(budget.spent, symbol: currencySymbol)} of '
                '${formatMoney(budget.amount, symbol: currencySymbol)}',
            if (!compact)
              budget.isExceeded
                  ? 'over by ${formatMoney(-budget.remaining, symbol: currencySymbol)}'
                  : '${formatMoney(budget.remaining, symbol: currencySymbol)} left',
          ].join(' · '),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: budget.isExceeded ? AppColors.negative : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

/// 'YYYY-MM' → 'October 2026'.
String budgetMonthLabel(String month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final parts = month.split('-');
  if (parts.length != 2) return 'This month';
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return 'This month';
  return '${names[m - 1]} ${parts[0]}';
}

/// Spacing helper so lists of bars read evenly.
class BudgetBarList extends StatelessWidget {
  final List<BudgetStatus> budgets;
  final String currencySymbol;
  final bool compact;

  const BudgetBarList({
    super.key,
    required this.budgets,
    required this.currencySymbol,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < budgets.length; i++) ...[
          BudgetBar(
            budget: budgets[i],
            currencySymbol: currencySymbol,
            compact: compact,
          ),
          if (i != budgets.length - 1)
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        ],
      ],
    );
  }
}
