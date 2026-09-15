import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/state_manager.dart';
import '../utils/app_constants.dart';
import '../widgets/common_widgets.dart';
import 'add_expense_screen.dart';

/// Every expense, searchable and filterable.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _searchController = TextEditingController();

  String _query = '';
  String _groupFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final userId = state.currentUserId;

    final groupNames = ['All', ...state.groups.map((g) => g.name)];

    // Newest first, then narrowed by the search box and group chip.
    final expenses = [...state.expenses]
      ..sort((a, b) => b.date.compareTo(a.date));

    final filtered = expenses.where((e) {
      if (_query.isNotEmpty &&
          !e.description.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if (_groupFilter != 'All') {
        final group = _groupOf(state, e.groupId);
        if (group?.name != _groupFilter) return false;
      }
      return true;
    }).toList();

    final total = filtered.fold<double>(0, (sum, e) => sum + e.amount);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Text('Expenses',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 2),
                Text(
                  filtered.isEmpty
                      ? 'Nothing to show'
                      : '${filtered.length} expense'
                          '${filtered.length == 1 ? '' : 's'} · '
                          '${formatMoney(total)} total',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                PSSearchField(
                  hint: 'Search expenses',
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                ),
                if (groupNames.length > 1) ...[
                  const SizedBox(height: AppSpacing.sm),
                  PSFilterChips(
                    options: groupNames,
                    selected: _groupFilter,
                    onSelected: (v) => setState(() => _groupFilter = v),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),

        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: state.expenses.isEmpty
                ? EmptyStateWidget(
                    iconData: Icons.receipt_long_outlined,
                    title: 'No expenses yet',
                    subtitle:
                        'Add your first expense and it will show up here.',
                    buttonLabel: 'Add expense',
                    onButtonPressed: () => openAddExpense(context),
                  )
                : const EmptyStateWidget(
                    iconData: Icons.search_off_rounded,
                    title: 'No matches',
                    subtitle: 'Try a different search or group filter.',
                  ),
          )
        else
          SliverToBoxAdapter(
            child: PageContainer(
              child: Column(
                children: [
                  for (final expense in filtered) ...[
                    _ExpenseRow(
                      expense: expense,
                      userId: userId,
                      groupName: _groupOf(state, expense.groupId)?.name,
                      payerName: _memberName(state, expense.paidById),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Group? _groupOf(StateManager state, String? groupId) {
    if (groupId == null) return null;
    for (final g in state.groups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  String _memberName(StateManager state, String id) {
    for (final m in state.members) {
      if (m.id == id) return m.name;
    }
    return 'Someone';
  }
}

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final String userId;
  final String? groupName;
  final String payerName;

  const _ExpenseRow({
    required this.expense,
    required this.userId,
    required this.groupName,
    required this.payerName,
  });

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];

  @override
  Widget build(BuildContext context) {
    final share = expense.splits[userId] ?? 0;
    final paidByMe = expense.paidById == userId;

    // If you paid, you are owed everyone else's share; otherwise you owe yours.
    final youLabel = paidByMe ? 'you lent' : 'your share';
    final youAmount = paidByMe ? expense.amount - share : share;

    return ExpenseItem(
      title: expense.description,
      subtitle: [
        ?groupName,
        '${paidByMe ? 'You' : payerName} paid',
      ].join(' · '),
      amount: formatMoney(expense.amount),
      day: expense.date.day.toString().padLeft(2, '0'),
      month: _months[expense.date.month - 1],
      trailingLabel: youAmount.abs() < 0.01
          ? 'not involved'
          : '$youLabel ${formatMoney(youAmount)}',
    );
  }
}
