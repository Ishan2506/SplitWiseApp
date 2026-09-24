import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/group_model.dart';
import '../models/models.dart';
import '../state/group_provider.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/currencies.dart';
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

  /// "You paid", "Priya paid", or for a split payment "You and 2 others
  /// paid" — matching how the primary payer's own name already reads
  /// elsewhere on this screen.
  String _payersSummary(GroupModel group, Expense expense, String currentUserId) {
    if (!expense.hasMultiplePayers) {
      final name = _memberName(group, expense.paidById);
      return expense.paidById == currentUserId ? 'You' : name;
    }

    final ids = expense.payers.keys.toList();
    final iAmPayer = ids.contains(currentUserId);
    final others = ids.where((id) => id != currentUserId).toList();

    if (iAmPayer) {
      return others.isEmpty
          ? 'You'
          : 'You and ${others.length} other${others.length == 1 ? '' : 's'}';
    }

    final firstName = _memberName(group, ids.first);
    final remaining = ids.length - 1;
    return remaining <= 0
        ? firstName
        : '$firstName and $remaining other${remaining == 1 ? '' : 's'}';
  }

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
    final payersSummary = _payersSummary(group, expense, currentUserId);

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
                if (expense.wasConverted) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Paid as ${formatMoney(expense.originalAmount!, decimals: true, symbol: currencySymbolFor(expense.originalCurrency))} '
                    '(${expense.originalCurrency})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Added by ${payersSummary == 'You' ? 'you' : payersSummary} on '
                  '${_formatDate(expense.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),

                PSCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!expense.hasMultiplePayers)
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
                        )
                      else ...[
                        Text(
                          '$payersSummary paid '
                          '${formatMoney(expense.amount, decimals: true, symbol: symbol)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final entry in expense.payers.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                AvatarWidget.forName(
                                    _memberName(group, entry.key), size: 28),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    entry.key == currentUserId
                                        ? 'You'
                                        : _memberName(group, entry.key),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatMoney(entry.value,
                                      decimals: true, symbol: symbol),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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

                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Comments'),
                _CommentsSection(
                  expenseId: expense.id,
                  currentUserId: currentUserId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An expense's discussion thread: every comment, oldest first, plus an
/// input to add one. Loads its own data so the rest of the screen does not
/// need to know comments exist until this section is actually built.
class _CommentsSection extends StatefulWidget {
  final String expenseId;
  final String currentUserId;

  const _CommentsSection({
    required this.expenseId,
    required this.currentUserId,
  });

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    context.read<StateManager>().loadExpenseComments(widget.expenseId).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final result =
        await context.read<StateManager>().addComment(widget.expenseId, text);
    if (!mounted) return;
    setState(() => _sending = false);

    if (result['success'] == true) {
      _controller.clear();
    } else {
      showAppSnack(
        context,
        result['message'] ?? 'Could not post the comment',
        success: false,
      );
    }
  }

  Future<void> _delete(ExpenseComment comment) async {
    final result = await context.read<StateManager>().deleteComment(comment.id);
    if (!mounted) return;
    if (result['success'] != true) {
      showAppSnack(
        context,
        result['message'] ?? 'Could not delete the comment',
        success: false,
      );
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final comments = context
        .watch<StateManager>()
        .comments
        .where((c) => c.expenseId == widget.expenseId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'No comments yet — be the first to say something.',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          )
        else
          PSCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < comments.length; i++) ...[
                  if (i != 0) const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Divider(height: 1),
                  ),
                  _CommentRow(
                    comment: comments[i],
                    isMine: comments[i].authorId == widget.currentUserId,
                    relativeTime: _relativeTime(comments[i].createdAt),
                    onDelete: () => _delete(comments[i]),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Add a comment',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.inputBg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: 'Send',
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.primaryAccent),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  final ExpenseComment comment;
  final bool isMine;
  final String relativeTime;
  final VoidCallback onDelete;

  const _CommentRow({
    required this.comment,
    required this.isMine,
    required this.relativeTime,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarWidget.forName(comment.authorName, size: 30),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isMine ? 'You' : comment.authorName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      relativeTime,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isMine)
            IconButton(
              tooltip: 'Delete comment',
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.muted),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
