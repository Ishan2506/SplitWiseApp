import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/group_model.dart';
import '../models/models.dart';
import '../state/group_provider.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/common_widgets.dart';
import 'add_expense_screen.dart';

/// One expense: what it was, who paid, and who owes what — with edit and
/// delete for whoever needs to correct it after the fact.
///
/// Looks the expense and its group up live from state rather than taking
/// them as fixed arguments, so an edit made here (or a delete elsewhere)
/// is reflected immediately instead of showing stale data.
class ExpenseDetailScreen extends StatelessWidget {
  final String expenseId;
  final String groupId;

  const ExpenseDetailScreen({
    super.key,
    required this.expenseId,
    required this.groupId,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Future<void> _edit(BuildContext context, Expense expense) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          groupId: groupId,
          existingExpense: expense,
        ),
      ),
    );
    if (updated == true && context.mounted) {
      context.read<GroupProvider>().refreshGroup(groupId);
      context.read<StateManager>().loadGroupExpenses(groupId);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: Text(
          '"${expense.description}" and its splits will be removed for '
          'everyone in the group. This cannot be undone.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Cancel'),
          ),
          PSButton(
            label: 'Delete',
            variant: PSButtonVariant.danger,
            size: PSButtonSize.small,
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final state = context.read<StateManager>();
    final result = await state.deleteExpense(expense.id);
    if (!context.mounted) return;

    if (result['success'] == true) {
      // Balances shift the moment an expense disappears.
      context.read<GroupProvider>().refreshGroup(groupId);
      Navigator.pop(context);
      showAppSnack(context, 'Expense deleted');
    } else {
      showAppSnack(
        context,
        result['message'] ?? 'Could not delete the expense',
        success: false,
      );
    }
  }

  String _memberName(GroupModel group, String memberId) {
    for (final m in group.members) {
      if (m.id == memberId) return m.name;
    }
    return 'Someone';
  }

  String _formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final group = context.watch<GroupProvider>().groupById(groupId);
    final expense = state.expenses.where((e) => e.id == expenseId).firstOrNull;

    if (expense == null || group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyStateWidget(
          iconData: Icons.receipt_long_outlined,
          title: 'Expense unavailable',
          subtitle: 'This expense may have been deleted.',
        ),
      );
    }

    final currentUserId = state.currentUserId;
    final symbol = group.currencySymbol;
    final payerName = _memberName(group, expense.paidById);
    final paidByMe = expense.paidById == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(expense.description, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Edit expense',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, expense),
          ),
          IconButton(
            tooltip: 'Delete expense',
            icon:
                const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => _confirmDelete(context, expense),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Text(
                  expense.description,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  expense.category,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatMoney(expense.amount, decimals: true, symbol: symbol),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Added by ${paidByMe ? 'you' : payerName} on '
                  '${_formatDate(expense.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),

                PSCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AvatarWidget.forName(payerName, size: 36),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              '${paidByMe ? 'You' : payerName} paid '
                              '${formatMoney(expense.amount, decimals: true, symbol: symbol)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (expense.splits.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        for (final entry in expense.splits.entries)
                          Padding(
                            padding: const EdgeInsets.only(left: 44, top: 6),
                            child: Text(
                              entry.key == currentUserId
                                  ? 'You owe ${formatMoney(entry.value, decimals: true, symbol: symbol)}'
                                  : '${_memberName(group, entry.key)} owes '
                                      '${formatMoney(entry.value, decimals: true, symbol: symbol)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

                if ((expense.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Notes'),
                  PSCard(
                    child: Text(
                      expense.notes!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
