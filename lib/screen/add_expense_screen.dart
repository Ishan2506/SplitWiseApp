import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/group_provider.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/currencies.dart';
import '../widgets/common_widgets.dart';

/// Add an expense: what it was, how much, who paid, and how it splits.
///
/// The split section always shows the resulting per-person figures so the
/// numbers are visible before saving rather than only afterwards.
/// Opens Add Expense for a group chosen by the user.
///
/// Expenses always belong to a group, so entry points that have no group in
/// hand (the dashboard's quick-add, the History empty state) ask which one
/// first instead of offering a group field inside the form.
///
/// Does nothing if the user has no groups yet — there is nothing to add to.
Future<void> openAddExpense(BuildContext context) async {
  final state = context.read<StateManager>();
  final groups = state.groups;

  if (groups.isEmpty) {
    showAppSnack(
      context,
      'Create a group first — expenses are added to a group',
      success: false,
    );
    return;
  }

  String? groupId = groups.first.id;
  if (groups.length > 1) {
    groupId = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetContext) => _OptionSheet(
        title: 'Add expense to',
        options: [
          for (final g in groups)
            _Option(id: g.id, label: g.name, icon: Icons.groups_rounded),
        ],
        selectedId: '',
      ),
    );
  }

  if (groupId == null || groupId.isEmpty || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AddExpenseScreen(groupId: groupId!)),
  );
}

class AddExpenseScreen extends StatefulWidget {
  /// The group the expense belongs to. Expenses are always recorded against a
  /// group, so this is required rather than chosen inside the form.
  final String groupId;
  const AddExpenseScreen({super.key, required this.groupId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _paidById;
  String _selectedCategory = 'Food & drink';
  DateTime _selectedDate = DateTime.now();
  SplitType _splitType = SplitType.equal;

  bool _isSaving = false;
  final Map<String, bool> _splitMembersSelected = {};
  final Map<String, TextEditingController> _customAmountControllers = {};

  /// True while we are rewriting the custom-split fields ourselves, so the
  /// controllers' onChanged does not treat our own text as a user edit.
  bool _seedingCustomFields = false;

  /// Set once the user types into a custom field: after that we stop
  /// re-seeding the fields from the total behind their back.
  bool _customFieldsTouched = false;

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
    final state = Provider.of<StateManager>(context, listen: false);
    _paidById = state.currentUserId;
    _updateSelectedMembersForGroup(state);
  }

  /// An expense is always in its group's currency. The server-backed group
  /// carries that, so it is read from GroupProvider rather than the lighter
  /// in-memory group held by StateManager.
  String get _symbol =>
      context.read<GroupProvider>().groupById(widget.groupId)?.currencySymbol ??
      currencySymbolFor(null);

  void _updateSelectedMembersForGroup(StateManager state) {
    final grp = state.groups.where((g) => g.id == widget.groupId).firstOrNull;
    // Fall back to everyone we know if the group has not loaded yet.
    final memberIds = grp?.memberIds ?? state.members.map((m) => m.id).toList();

    _splitMembersSelected.clear();
    for (final controller in _customAmountControllers.values) {
      controller.dispose();
    }
    _customAmountControllers.clear();

    for (final mId in memberIds) {
      _splitMembersSelected[mId] = true;
      _customAmountControllers[mId] = TextEditingController();
    }

    // A payer carried over from another group may not be in this one.
    if (_paidById == null || !memberIds.contains(_paidById)) {
      final currentUser = state.currentUserId;
      _paidById = memberIds.contains(currentUser)
          ? currentUser
          : (memberIds.isNotEmpty ? memberIds.first : null);
    }

    _customFieldsTouched = false;
    _seedCustomFields();
  }

  /// Fills the custom-split fields with the even share of the current total,
  /// so switching to "Exact"/"Percentage" starts from a balanced split rather
  /// than from zeros the user has to overwrite. Stops once the user edits.
  void _seedCustomFields() {
    if (_customFieldsTouched) return;

    final ids = _selectedMemberIds;
    _seedingCustomFields = true;
    for (final entry in _customAmountControllers.entries) {
      final isSelected = _splitMembersSelected[entry.key] ?? false;
      if (!isSelected || ids.isEmpty) {
        // Deselected people must not keep a stale value that would come back
        // if they were re-selected.
        entry.value.text = '';
        continue;
      }
      final share = _splitType == SplitType.percentage
          ? 100.0 / ids.length
          : _amount / ids.length;
      entry.value.text = _amount <= 0 && _splitType != SplitType.percentage
          ? ''
          : share.toStringAsFixed(2);
    }
    _seedingCustomFields = false;
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  List<String> get _selectedMemberIds => _splitMembersSelected.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toList();

  /// Sum of what the user has typed for the people currently selected.
  /// Deselected rows are ignored, so their leftover text can never count.
  double get _assigned => _selectedMemberIds.fold<double>(
        0,
        (sum, id) =>
            sum +
            (double.tryParse(_customAmountControllers[id]?.text.trim() ?? '') ??
                0),
      );

  /// For custom splits, how much is still unallocated: rupees for an exact
  /// split, percentage points for a percentage split.
  double get _remainder {
    if (_splitType == SplitType.equal) return 0;
    final target = _splitType == SplitType.percentage ? 100.0 : _amount;
    return target - _assigned;
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedSplitMembers = _selectedMemberIds;
    if (selectedSplitMembers.isEmpty) {
      showAppSnack(context, 'Pick at least one person to split with',
          success: false);
      return;
    }

    if (_paidById == null) {
      showAppSnack(context, 'Choose who paid', success: false);
      return;
    }

    if (_splitType != SplitType.equal) {
      // Every custom field must be a real, non-negative number.
      for (final id in selectedSplitMembers) {
        final raw = _customAmountControllers[id]?.text.trim() ?? '';
        final parsed = double.tryParse(raw);
        if (raw.isEmpty || parsed == null || parsed < 0) {
          showAppSnack(
            context,
            _splitType == SplitType.percentage
                ? 'Give everyone a valid percentage'
                : 'Give everyone a valid amount',
            success: false,
          );
          return;
        }
      }

      if (_remainder.abs() > 0.01) {
        showAppSnack(
          context,
          _splitType == SplitType.percentage
              ? 'Percentages must add up to 100% (currently '
                  '${_assigned.toStringAsFixed(2)}%)'
              : 'Split amounts must add up to ${formatMoney(_amount, symbol: _symbol)}',
          success: false,
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final state = Provider.of<StateManager>(context, listen: false);
    final amount = double.parse(_amountController.text.trim());
    // Read before awaiting — this touches context, which may be gone after.
    final symbol = _symbol;

    // The category doubles as the expense's label.
    final description = _selectedCategory;

    try {
      final result = await state.saveExpense(
        description: description,
        amount: amount,
        paidById: _paidById!,
        splitType: _splitType,
        participants: selectedSplitMembers,
        splits: _calculateSplits(amount, selectedSplitMembers),
        // The server recomputes the splits from these, so an exact or
        // percentage expense is validated in one place rather than two.
        values: _splitType == SplitType.equal
            ? null
            : _customValues(selectedSplitMembers),
        groupId: widget.groupId,
        date: _selectedDate,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] != true) {
        showAppSnack(
          context,
          (result['message'] ?? 'Could not save the expense').toString(),
          success: false,
        );
        return;
      }

      state.pushNotification(
        kind: ActivityKind.expenseAdded,
        title: 'You added "$description"',
        subtitle:
            '${formatMoney(amount, symbol: symbol)} · split ${selectedSplitMembers.length} ways',
      );

      showAppSnack(context, 'Expense saved');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showAppSnack(context, 'Could not save: $e', success: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// The raw numbers the user typed, in the unit of the current split type:
  /// rupees for an exact split, percentage points for a percentage split.
  Map<String, double> _customValues(List<String> members) => {
        for (final m in members)
          m: double.tryParse(_customAmountControllers[m]?.text.trim() ?? '') ??
              0,
      };

  /// Builds the stored split map. Every branch returns *rupee amounts* that
  /// sum exactly to [total] — the last member absorbs any rounding drift, so
  /// splitting 100 three ways stores 33.33/33.33/33.34 rather than three
  /// figures that quietly lose a paisa.
  Map<String, double> _calculateSplits(double total, List<String> members) {
    if (members.isEmpty) return {};

    final splits = <String, double>{};

    switch (_splitType) {
      case SplitType.equal:
        final per = _round2(total / members.length);
        for (final m in members) {
          splits[m] = per;
        }
        break;

      case SplitType.exact:
        for (final m in members) {
          splits[m] = _round2(
              double.tryParse(_customAmountControllers[m]?.text.trim() ?? '') ??
                  0);
        }
        break;

      case SplitType.percentage:
        for (final m in members) {
          final pct =
              double.tryParse(_customAmountControllers[m]?.text.trim() ?? '') ??
                  0;
          splits[m] = _round2(total * pct / 100.0);
        }
        break;
    }

    _absorbRoundingDrift(splits, members, total);
    return splits;
  }

  /// Nudges the last participant so the shares add up to the total to the paisa.
  void _absorbRoundingDrift(
      Map<String, double> splits, List<String> members, double total) {
    final sum = splits.values.fold<double>(0, (a, b) => a + b);
    final drift = _round2(_round2(total) - sum);
    if (drift != 0) {
      final last = members.last;
      splits[last] = _round2((splits[last] ?? 0) + drift);
    }
  }

  static double _round2(double n) => (n * 100).roundToDouble() / 100;

  void _onSplitTypeChanged(SplitType type) {
    if (type == _splitType) return;
    setState(() {
      _splitType = type;
      // Exact amounts and percentages are different units, so values typed for
      // one are meaningless for the other: start the new mode from an even
      // split the user can adjust.
      _customFieldsTouched = false;
      _seedCustomFields();
    });
  }

  void _onMemberToggled(String id, bool value) {
    setState(() {
      _splitMembersSelected[id] = value;
      if (!value) {
        // Clear the row so a stale figure cannot reappear on re-selection.
        _seedingCustomFields = true;
        _customAmountControllers[id]?.text = '';
        _seedingCustomFields = false;
      }
      // Changing who is involved changes everyone's even share.
      _seedCustomFields();
    });
  }

  void _onCustomAmountChanged() {
    if (_seedingCustomFields) return;
    setState(() => _customFieldsTouched = true);
  }

  /// Puts the custom fields back to an even split.
  void _resetCustomFields() {
    setState(() {
      _customFieldsTouched = false;
      _seedCustomFields();
    });
  }

  @override
  void dispose() {
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
    final members = state.members;

    final group =
        state.groups.where((g) => g.id == widget.groupId).firstOrNull;
    // The expense is entered in the group's currency, which only the
    // server-backed group knows about.
    final symbol = context
            .watch<GroupProvider>()
            .groupById(widget.groupId)
            ?.currencySymbol ??
        currencySymbolFor(null);
    // Before the group loads we do not know its roster, so fall back to
    // everyone rather than showing an empty split list.
    final activeMembers = group != null
        ? members.where((m) => group.memberIds.contains(m.id)).toList()
        : members;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add expense'),
            if (group != null)
              Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
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
                    currencySymbol: symbol,
                    onChanged: (_) => setState(_seedCustomFields),
                  ),
                  const SizedBox(height: AppSpacing.lg),

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
                          label: 'Date',
                          value: _formatDate(_selectedDate),
                          icon: Icons.calendar_today_rounded,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _PickerField(
                          label: 'Paid by',
                          value: _payerName(activeMembers),
                          icon: Icons.account_balance_wallet_outlined,
                          onTap: () => _pickPayer(activeMembers),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const SectionHeader(title: 'Split'),
                  _SplitTypeToggle(
                    value: _splitType,
                    onChanged: _onSplitTypeChanged,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  _SplitList(
                    members: activeMembers,
                    selected: _splitMembersSelected,
                    controllers: _customAmountControllers,
                    splitType: _splitType,
                    total: _amount,
                    currencySymbol: symbol,
                    onToggle: _onMemberToggled,
                    onAmountChanged: _onCustomAmountChanged,
                  ),

                  if (_splitType != SplitType.equal) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _RemainderBar(
                      remainder: _remainder,
                      total: _amount,
                      isPercentage: _splitType == SplitType.percentage,
                      currencySymbol: symbol,
                      onReset: _resetCustomFields,
                    ),
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
  final String currencySymbol;
  final ValueChanged<String> onChanged;

  const _AmountField({
    required this.controller,
    required this.currencySymbol,
    required this.onChanged,
  });

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
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                prefixText: currencySymbol,
                prefixStyle: const TextStyle(
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
          _segment('Equally', SplitType.equal),
          _segment('Exact', SplitType.exact),
          _segment('Percentage', SplitType.percentage),
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
  final String currencySymbol;
  final void Function(String id, bool value) onToggle;
  final VoidCallback onAmountChanged;

  const _SplitList({
    required this.members,
    required this.selected,
    required this.controllers,
    required this.splitType,
    required this.total,
    required this.currencySymbol,
    required this.onToggle,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount =
        members.where((m) => selected[m.id] ?? false).length;
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

  /// What this member's typed percentage comes to in rupees.
  double _percentShare(String memberId) {
    final pct =
        double.tryParse(controllers[memberId]?.text.trim() ?? '') ?? 0;
    return total * pct / 100.0;
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
                  formatMoney(perHead, decimals: true, symbol: currencySymbol),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                )
              else ...[
                // For a percentage split, show what the percent works out to
                // as an amount so the figure is never a guess.
                if (splitType == SplitType.percentage)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Text(
                      formatMoney(_percentShare(member.id),
                          decimals: true, symbol: currencySymbol),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                SizedBox(
                  width: splitType == SplitType.percentage ? 84 : 96,
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
                    decoration: InputDecoration(
                      prefixText: splitType == SplitType.percentage
                          ? null
                          : currencySymbol,
                      suffixText:
                          splitType == SplitType.percentage ? '%' : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
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
  final bool isPercentage;
  final String currencySymbol;
  final VoidCallback onReset;

  const _RemainderBar({
    required this.remainder,
    required this.total,
    required this.isPercentage,
    required this.currencySymbol,
    required this.onReset,
  });

  /// Formats a leftover/overshoot in the unit the current split uses.
  String _unit(double value) => isPercentage
      ? '${value.toStringAsFixed(2)}%'
      : formatMoney(value, decimals: true, symbol: currencySymbol);

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
                  ? (isPercentage
                      ? 'Percentages add up to 100%'
                      : 'Splits add up to ${formatMoney(total, symbol: currencySymbol)}')
                  : over
                      ? '${_unit(remainder.abs())} over'
                      : '${_unit(remainder)} left to assign',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: balanced ? AppColors.success : AppColors.primaryDark,
              ),
            ),
          ),
          if (!balanced)
            GestureDetector(
              onTap: onReset,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  'Split evenly',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
