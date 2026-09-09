import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/common_widgets.dart';

/// Add an expense: what it was, how much, who paid, and how it splits.
///
/// The split section always shows the resulting per-person figures so the
/// numbers are visible before saving rather than only afterwards.
class AddExpenseScreen extends StatefulWidget {
  final String? preselectedGroupId;
  const AddExpenseScreen({super.key, this.preselectedGroupId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _groupId;
  String? _paidById;
  String _selectedCategory = 'Food & drink';
  DateTime _selectedDate = DateTime.now();
  SplitType _splitType = SplitType.equal;

  bool _isSaving = false;
  final Map<String, bool> _splitMembersSelected = {};
  final Map<String, TextEditingController> _customAmountControllers = {};

  static const _categories = <String, IconData>{
    'Food & drink': Icons.restaurant_rounded,
    'Travel': Icons.flight_takeoff_rounded,
    'Accommodation': Icons.hotel_rounded,
    'Entertainment': Icons.movie_rounded,
    'Other': Icons.category_rounded,
  };

  @override
  void initState() {
    super.initState();
    _groupId = widget.preselectedGroupId;
    final state = Provider.of<StateManager>(context, listen: false);
    _paidById = state.currentUserId;
    _updateSelectedMembersForGroup(state);
  }

  void _updateSelectedMembersForGroup(StateManager state) {
    List<String> memberIds;
    if (_groupId != null) {
      final grp = state.groups.firstWhere((g) => g.id == _groupId);
      memberIds = grp.memberIds;
    } else {
      memberIds = state.members.map((m) => m.id).toList();
    }

    _splitMembersSelected.clear();
    for (final controller in _customAmountControllers.values) {
      controller.dispose();
    }
    _customAmountControllers.clear();

    for (final mId in memberIds) {
      _splitMembersSelected[mId] = true;
      _customAmountControllers[mId] = TextEditingController(text: '0.00');
    }
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  List<String> get _selectedMemberIds => _splitMembersSelected.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toList();

  /// For custom splits, how much of the total is still unallocated.
  double get _remainder {
    if (_splitType == SplitType.equal) return 0;
    final assigned = _selectedMemberIds.fold<double>(
      0,
      (sum, id) =>
          sum + (double.tryParse(_customAmountControllers[id]?.text ?? '') ?? 0),
    );
    return _amount - assigned;
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedSplitMembers = _selectedMemberIds;
    if (selectedSplitMembers.isEmpty) {
      showAppSnack(context, 'Pick at least one person to split with',
          success: false);
      return;
    }

    if (_splitType == SplitType.exact && _remainder.abs() > 0.01) {
      showAppSnack(
        context,
        'Split amounts must add up to ${formatMoney(_amount)}',
        success: false,
      );
      return;
    }

    setState(() => _isSaving = true);

    final state = Provider.of<StateManager>(context, listen: false);
    final amount = double.parse(_amountController.text.trim());

    try {
      final expense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: _descriptionController.text.trim(),
        amount: amount,
        date: _selectedDate,
        paidById: _paidById!,
        splitType: _splitType,
        splits: _calculateSplits(amount, selectedSplitMembers),
        groupId: _groupId,
      );

      state.addExpense(expense);
      state.pushNotification(
        kind: ActivityKind.expenseAdded,
        title: 'You added "${expense.description}"',
        subtitle:
            '${formatMoney(amount)} · split ${selectedSplitMembers.length} ways',
      );

      if (mounted) {
        showAppSnack(context, 'Expense saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, 'Could not save: $e', success: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, double> _calculateSplits(double total, List<String> members) {
    if (members.isEmpty) return {};
    if (_splitType == SplitType.equal) {
      final perMember = total / members.length;
      return {for (var m in members) m: perMember};
    }
    return {
      for (var m in members)
        m: double.tryParse(_customAmountControllers[m]?.text ?? '0') ?? 0
    };
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (final controller in _customAmountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final groups = state.groups;
    final members = state.members;

    final activeMembers = _groupId != null
        ? members
            .where((m) => groups
                .firstWhere((g) => g.id == _groupId)
                .memberIds
                .contains(m.id))
            .toList()
        : members;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add expense'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveExpense,
            child: const Text('Save'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  _AmountField(
                    controller: _amountController,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  PSTextField(
                    label: 'What was it for?',
                    placeholder: 'Dinner at the beach shack',
                    controller: _descriptionController,
                    textInputAction: TextInputAction.next,
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Give the expense a name'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  const _FieldLabel('Category'),
                  const SizedBox(height: AppSpacing.xs),
                  _CategoryPicker(
                    categories: _categories,
                    selected: _selectedCategory,
                    onSelected: (c) => setState(() => _selectedCategory = c),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PickerField(
                          label: 'Group',
                          value: _groupId == null
                              ? 'No group'
                              : groups
                                  .firstWhere((g) => g.id == _groupId)
                                  .name,
                          icon: Icons.groups_outlined,
                          onTap: () => _pickGroup(state),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _PickerField(
                          label: 'Date',
                          value: _formatDate(_selectedDate),
                          icon: Icons.calendar_today_rounded,
                          onTap: _pickDate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  _PickerField(
                    label: 'Paid by',
                    value: _payerName(activeMembers),
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => _pickPayer(activeMembers),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const SectionHeader(title: 'Split'),
                  _SplitTypeToggle(
                    value: _splitType,
                    onChanged: (t) => setState(() => _splitType = t),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  _SplitList(
                    members: activeMembers,
                    selected: _splitMembersSelected,
                    controllers: _customAmountControllers,
                    splitType: _splitType,
                    total: _amount,
                    onToggle: (id, v) =>
                        setState(() => _splitMembersSelected[id] = v),
                    onAmountChanged: () => setState(() {}),
                  ),

                  if (_splitType == SplitType.exact) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _RemainderBar(remainder: _remainder, total: _amount),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  PSTextField(
                    label: 'Notes (optional)',
                    placeholder: 'Anything worth remembering',
                    controller: _notesController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PSButton(
                    label: 'Save expense',
                    onPressed: _isSaving ? null : _saveExpense,
                    isLoading: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Name of whoever is marked as having paid, or a prompt if none is set.
  String _payerName(List<Member> members) {
    for (final m in members) {
      if (m.id == _paidById) return m.name;
    }
    return members.isNotEmpty ? members.first.name : 'Select';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Today';
    }
    return '${d.day} ${months[d.month - 1]}';
  }

  Future<void> _pickGroup(StateManager state) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetContext) => _OptionSheet(
        title: 'Choose a group',
        options: [
          _Option(id: '', label: 'No group', icon: Icons.person_outline_rounded),
          for (final g in state.groups)
            _Option(id: g.id, label: g.name, icon: Icons.groups_rounded),
        ],
        selectedId: _groupId ?? '',
      ),
    );

    if (selected == null || !mounted) return;
    setState(() {
      _groupId = selected.isEmpty ? null : selected;
      _updateSelectedMembersForGroup(state);
    });
  }

  Future<void> _pickPayer(List<Member> members) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetContext) => _OptionSheet(
        title: 'Who paid?',
        options: [
          for (final m in members)
            _Option(id: m.id, label: m.name, icon: Icons.person_rounded),
        ],
        selectedId: _paidById ?? '',
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _paidById = selected);
  }
}

/// Big, centred amount entry — the first thing you fill in.
class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _AmountField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        children: [
          const OverlineLabel('Amount', color: Color(0xFFC2607C)),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextFormField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.6,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                prefixText: '₹',
                prefixStyle: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.6,
                  color: Color(0xFFD9CFD6),
                ),
              ),
              validator: (val) {
                final parsed = double.tryParse((val ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter an amount greater than zero';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final Map<String, IconData> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryPicker({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final entry = categories.entries.elementAt(i);
          final isSelected = entry.key == selected;
          return GestureDetector(
            onTap: () => onSelected(entry.key),
            child: AnimatedContainer(
              duration: AppDuration.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.ink : AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isSelected ? AppColors.ink : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    entry.value,
                    size: 15,
                    color:
                        isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A tappable field that opens a picker sheet.
class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: AppColors.muted),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded,
                      size: 18, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Option {
  final String id;
  final String label;
  final IconData icon;
  const _Option({required this.id, required this.label, required this.icon});
}

/// Generic single-select bottom sheet.
class _OptionSheet extends StatelessWidget {
  final String title;
  final List<_Option> options;
  final String selectedId;

  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
            child:
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, i) {
                final option = options[i];
                final isSelected = option.id == selectedId;
                return ListTile(
                  onTap: () => Navigator.pop(context, option.id),
                  leading: Icon(option.icon,
                      size: 20,
                      color: isSelected
                          ? AppColors.primaryAccent
                          : AppColors.textSecondary),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 19, color: AppColors.primaryAccent)
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

/// Equal / exact segmented control.
class _SplitTypeToggle extends StatelessWidget {
  final SplitType value;
  final ValueChanged<SplitType> onChanged;

  const _SplitTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          _segment('Split equally', SplitType.equal),
          _segment('Exact amounts', SplitType.exact),
        ],
      ),
    );
  }

  Widget _segment(String label, SplitType type) {
    final isSelected = value == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.bgPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: isSelected ? AppShadow.card : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color:
                  isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Who the expense splits across, with each person's resulting share.
class _SplitList extends StatelessWidget {
  final List<Member> members;
  final Map<String, bool> selected;
  final Map<String, TextEditingController> controllers;
  final SplitType splitType;
  final double total;
  final void Function(String id, bool value) onToggle;
  final VoidCallback onAmountChanged;

  const _SplitList({
    required this.members,
    required this.selected,
    required this.controllers,
    required this.splitType,
    required this.total,
    required this.onToggle,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount = selected.values.where((v) => v).length;
    final perHead = selectedCount > 0 ? total / selectedCount : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < members.length; i++) ...[
            _row(context, members[i], perHead),
            if (i != members.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 58),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Member member, double perHead) {
    final isOn = selected[member.id] ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onToggle(member.id, !isOn),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            children: [
              Checkbox(
                value: isOn,
                onChanged: (v) => onToggle(member.id, v ?? false),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
                activeColor: AppColors.primaryAccent,
                visualDensity: VisualDensity.compact,
              ),
              AvatarWidget.forName(member.name, size: 32),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isOn ? AppColors.textPrimary : AppColors.muted,
                  ),
                ),
              ),
              if (!isOn)
                const Text(
                  '—',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                )
              else if (splitType == SplitType.equal)
                Text(
                  formatMoney(perHead, decimals: true),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                )
              else
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: controllers[member.id],
                    onChanged: (_) => onAmountChanged(),
                    textAlign: TextAlign.right,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '₹',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tells the user how much of the total is still unassigned.
class _RemainderBar extends StatelessWidget {
  final double remainder;
  final double total;

  const _RemainderBar({required this.remainder, required this.total});

  @override
  Widget build(BuildContext context) {
    final balanced = remainder.abs() < 0.01;
    final over = remainder < 0;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: balanced ? AppColors.successLight : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: balanced ? AppColors.successBorder : AppColors.primaryBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            balanced
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: balanced ? AppColors.success : AppColors.primaryDark,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              balanced
                  ? 'Splits add up to ${formatMoney(total)}'
                  : over
                      ? '${formatMoney(remainder.abs())} over the total'
                      : '${formatMoney(remainder)} left to assign',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: balanced ? AppColors.success : AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
