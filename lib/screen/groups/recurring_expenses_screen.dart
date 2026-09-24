import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../models/models.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import '../add_expense_screen.dart';

/// Every recurring-expense template set up for a group — rent, a shared
/// subscription — with pause/resume and delete. Creating one happens
/// through the ordinary Add Expense form's "Repeat this expense" switch;
/// this screen only manages templates that already exist.
class RecurringExpensesScreen extends StatefulWidget {
  final String groupId;

  const RecurringExpensesScreen({super.key, required this.groupId});

  @override
  State<RecurringExpensesScreen> createState() =>
      _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context
        .read<StateManager>()
        .loadGroupRecurringExpenses(widget.groupId);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addNew() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          groupId: widget.groupId,
          startAsRecurring: true,
        ),
      ),
    );
    if (created == true && mounted) _load();
  }

  Future<void> _toggleActive(RecurringExpense template, bool active) async {
    final result = await context
        .read<StateManager>()
        .setRecurringExpenseActive(template.id, active);
    if (!mounted) return;
    if (result['success'] != true) {
      showAppSnack(
        context,
        result['message'] ?? 'Could not update it',
        success: false,
      );
    }
  }

  Future<void> _confirmDelete(RecurringExpense template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop this recurring expense?'),
        content: Text(
          '"${template.description}" will no longer create new expenses. '
          'Anything it already created stays as-is.',
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
            label: 'Stop',
            variant: PSButtonVariant.danger,
            size: PSButtonSize.small,
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final result =
        await context.read<StateManager>().deleteRecurringExpense(template.id);
    if (!mounted) return;
    if (result['success'] != true) {
      showAppSnack(
        context,
        result['message'] ?? 'Could not stop it',
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = context.watch<GroupProvider>().groupById(widget.groupId);
    final templates = context
        .watch<StateManager>()
        .recurringExpenses
        .where((r) => r.groupId == widget.groupId)
        .toList()
      ..sort((a, b) => a.nextRunDate.compareTo(b.nextRunDate));

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : templates.isEmpty
              ? EmptyStateWidget(
                  iconData: Icons.repeat_rounded,
                  title: 'Nothing set to repeat',
                  subtitle: 'Rent, subscriptions, anything that comes up '
                      'the same way each cycle — set it up once and it '
                      'adds itself.',
                  buttonLabel: 'New recurring expense',
                  onButtonPressed: _addNew,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  children: [
                    PageContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.xs),
                          for (final template in templates) ...[
                            _RecurringExpenseCard(
                              template: template,
                              group: group,
                              onToggleActive: (v) => _toggleActive(template, v),
                              onDelete: () => _confirmDelete(template),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _RecurringExpenseCard extends StatelessWidget {
  final RecurringExpense template;
  final GroupModel? group;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  const _RecurringExpenseCard({
    required this.template,
    required this.group,
    required this.onToggleActive,
    required this.onDelete,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  @override
  Widget build(BuildContext context) {
    final symbol = group?.currencySymbol ?? '';

    return PSCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.description,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatMoney(template.amount, decimals: true, symbol: symbol)} · '
                  '${template.frequency.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  template.active
                      ? 'Next on ${_formatDate(template.nextRunDate)}'
                      : 'Paused',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: template.active
                        ? AppColors.textTertiary
                        : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              // Plain Switch() — matches the shared SwitchThemeData used by
              // every other switch in the app (e.g. Profile's "Push
              // notifications" row) instead of a one-off color.
              Switch(
                value: template.active,
                onChanged: onToggleActive,
              ),
              IconButton(
                tooltip: 'Stop',
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.error),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
