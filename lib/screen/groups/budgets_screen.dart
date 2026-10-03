import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/expense_categories.dart';
import '../../widgets/budget_bar.dart';
import '../../widgets/common_widgets.dart';

/// A group's monthly budgets — "Food: ₹5000/month" — with how much of each
/// has gone this month. Every member can see them; members with push on are
/// told when one passes 80% and again at 100%. Only the group's creator
/// edits them, same as the balance limit and default split.
class BudgetsScreen extends StatefulWidget {
  final String groupId;

  const BudgetsScreen({super.key, required this.groupId});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final result =
        await context.read<GroupProvider>().loadBudgets(widget.groupId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result['success'] == true ? null : result['message']?.toString();
    });
  }

  Future<void> _edit(GroupModel group, GroupBudgets current) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _BudgetEditorScreen(group: group, current: current),
      ),
    );
    if (saved == true && mounted) showAppSnack(context, 'Budgets saved');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final group = provider.groupById(widget.groupId);
    final budgets = provider.budgetsFor(widget.groupId);
    final currentUserId = context.watch<StateManager>().currentUserId;

    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyStateWidget(
          iconData: Icons.link_off_rounded,
          title: 'Group unavailable',
          subtitle: 'This group may have been deleted or you were removed.',
        ),
      );
    }

    final canEdit = group.isCreatedBy(currentUserId);
    final symbol = group.currencySymbol;

    // Most-used first: the ones that need attention lead.
    final sorted = [...budgets.budgets]
      ..sort((a, b) => b.percent.compareTo(a.percent));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly budgets'),
        actions: [
          if (canEdit && !budgets.isEmpty)
            TextButton(
              onPressed: () => _edit(group, budgets),
              child: const Text('Edit'),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryAccent,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  Text(group.name, style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    budgets.month.isEmpty
                        ? 'This month'
                        : budgetMonthLabel(budgets.month),
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_loading && budgets.isEmpty)
                    const SkeletonCard()
                  else if (_error != null && budgets.isEmpty)
                    EmptyStateWidget(
                      iconData: Icons.cloud_off_rounded,
                      title: 'Could not load budgets',
                      subtitle: _error!,
                      compact: true,
                    )
                  else if (budgets.isEmpty)
                    _NoBudgets(
                      canEdit: canEdit,
                      onCreate: () => _edit(group, budgets),
                    )
                  else ...[
                    PSCard(
                      child: BudgetBarList(
                        budgets: sorted,
                        currencySymbol: symbol,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Budgets reset on the 1st of each month. Members with '
                      'push notifications on are alerted at 80% and 100%.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBudgets extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onCreate;

  const _NoBudgets({required this.canEdit, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return PSCard(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg, horizontal: AppSpacing.md),
      child: Column(
        children: [
          EmptyStateWidget(
            iconData: Icons.savings_outlined,
            title: 'No budgets yet',
            subtitle: canEdit
                ? 'Set a monthly target — for everything, or per category '
                    'like Food & drink — and everyone gets a heads-up at 80%.'
                : 'The group\'s creator can set monthly spending targets here.',
            compact: true,
          ),
          if (canEdit)
            PSButton(
              label: 'Set a budget',
              size: PSButtonSize.medium,
              onPressed: onCreate,
            ),
        ],
      ),
    );
  }
}

/// One editable row: a category and its monthly amount.
class _DraftBudget {
  String category;
  final TextEditingController amount;

  _DraftBudget(this.category, double? value)
      : amount = TextEditingController(
          text: value == null
              ? ''
              : (value == value.roundToDouble()
                  ? value.toStringAsFixed(0)
                  : value.toStringAsFixed(2)),
        );
}

/// Add, change or remove a group's budgets, then save them all at once.
class _BudgetEditorScreen extends StatefulWidget {
  final GroupModel group;
  final GroupBudgets current;

  const _BudgetEditorScreen({required this.group, required this.current});

  @override
  State<_BudgetEditorScreen> createState() => _BudgetEditorScreenState();
}

class _BudgetEditorScreenState extends State<_BudgetEditorScreen> {
  late final List<_DraftBudget> _rows;

  /// Rows the user removed. Their controllers are disposed with the screen,
  /// not on removal — the TextField still holds one until the next frame.
  final List<_DraftBudget> _removed = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final b in widget.current.budgets) _DraftBudget(b.category, b.amount),
    ];
    if (_rows.isEmpty) _rows.add(_DraftBudget(kAllCategoriesBudget, null));
  }

  @override
  void dispose() {
    for (final r in [..._rows, ..._removed]) {
      r.amount.dispose();
    }
    super.dispose();
  }

  /// Every category a budget could be for: overall, the built-in ones, and
  /// any custom category this group has actually spent in.
  List<String> get _allCategories {
    final seen = <String>{kAllCategoriesBudget, ...kExpenseCategories.keys};
    for (final key in widget.current.spend.keys) {
      seen.add(key);
    }
    for (final r in _rows) {
      seen.add(r.category);
    }
    return seen.toList();
  }

  List<String> _choicesFor(_DraftBudget row) {
    final taken = _rows.where((r) => r != row).map((r) => r.category).toSet();
    return _allCategories.where((c) => !taken.contains(c)).toList();
  }

  String _labelFor(String category) =>
      category == kAllCategoriesBudget ? 'All spending' : category;

  void _addRow() {
    final taken = _rows.map((r) => r.category).toSet();
    final free = _allCategories.where((c) => !taken.contains(c)).toList();
    if (free.isEmpty) return;
    setState(() => _rows.add(_DraftBudget(free.first, null)));
  }

  Future<void> _save() async {
    final budgets = <String, double>{};
    for (final r in _rows) {
      final value = double.tryParse(r.amount.text.trim()) ?? 0;
      if (value <= 0) {
        showAppSnack(
          context,
          'Enter a monthly amount for ${_labelFor(r.category)}',
          success: false,
        );
        return;
      }
      budgets[r.category] = value;
    }

    setState(() => _saving = true);
    final result = await context.read<GroupProvider>().saveBudgets(
          groupId: widget.group.id,
          budgets: budgets,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      showAppSnack(
        context,
        (result['message'] ?? 'Could not save budgets').toString(),
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.group.currencySymbol;
    final canAddMore = _rows.length < _allCategories.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit budgets'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Monthly limits for ${widget.group.name}, in '
                  '${widget.group.currency}. They count the whole group\'s '
                  'spending, not each person\'s share.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final row in _rows) ...[
                  _BudgetRow(
                    key: ObjectKey(row),
                    row: row,
                    choices: _choicesFor(row),
                    labelFor: _labelFor,
                    currencySymbol: symbol,
                    spentThisMonth: widget.current.spend[row.category] ?? 0,
                    onCategory: (c) => setState(() => row.category = c),
                    onRemove: () => setState(() {
                      _rows.remove(row);
                      _removed.add(row);
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                if (canAddMore)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add a budget'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                PSButton(
                  label: _rows.isEmpty ? 'Remove all budgets' : 'Save budgets',
                  variant: _rows.isEmpty
                      ? PSButtonVariant.danger
                      : PSButtonVariant.primary,
                  onPressed: _saving ? null : _save,
                  isLoading: _saving,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final _DraftBudget row;
  final List<String> choices;
  final String Function(String) labelFor;
  final String currencySymbol;
  final double spentThisMonth;
  final ValueChanged<String> onCategory;
  final VoidCallback onRemove;

  const _BudgetRow({
    super.key,
    required this.row,
    required this.choices,
    required this.labelFor,
    required this.currencySymbol,
    required this.spentThisMonth,
    required this.onCategory,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return PSCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.xs, AppSpacing.xxs, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: row.category,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    items: [
                      for (final c in choices)
                        DropdownMenuItem(
                          value: c,
                          child: Text(
                            labelFor(c),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (c) {
                      if (c != null) onCategory(c);
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: row.amount,
                  textAlign: TextAlign.right,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: currencySymbol,
                    hintText: '0',
                    suffixText: '/mo',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textTertiary),
              ),
            ],
          ),
          if (spentThisMonth > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${formatMoney(spentThisMonth, symbol: currencySymbol)} spent so far this month',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
