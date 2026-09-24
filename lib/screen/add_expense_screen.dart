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

  /// When set, the form opens pre-filled with this expense's data and
  /// "Save" updates it in place instead of creating a new one.
  final Expense? existingExpense;

  /// Opens the form with "Repeat this expense" already switched on — the
  /// entry point from the recurring-expenses screen's "New" action.
  final bool startAsRecurring;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    this.existingExpense,
    this.startAsRecurring = false,
  });

  bool get isEditing => existingExpense != null;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
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

  /// True when "who paid" is more than one person — e.g. two cards split a
  /// restaurant bill. False is the common case: a single payer via
  /// [_paidById].
  bool _multiplePayers = false;
  final Map<String, bool> _payerSelected = {};
  final Map<String, TextEditingController> _payerAmountControllers = {};
  bool _seedingPayerFields = false;
  bool _payerFieldsTouched = false;

  /// Only offered when creating a brand-new expense — an existing one-time
  /// expense can't retroactively become a recurring template.
  bool _isRecurring = false;
  RecurringFrequency _frequency = RecurringFrequency.monthly;

  /// The currency [_amountController] (and every split/payer figure on this
  /// screen) is being entered in. Defaults to the group's own; the server
  /// converts automatically when this differs from it.
  String _currencyCode = kDefaultCurrencyCode;

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
    final existing = widget.existingExpense;
    final groupCurrency =
        Provider.of<GroupProvider>(context, listen: false)
                .groupById(widget.groupId)
                ?.currency ??
            kDefaultCurrencyCode;

    if (existing != null) {
      // Edit in whatever currency it was originally entered in — the
      // group-currency `amount` is a converted figure, not what was typed.
      _currencyCode = existing.originalCurrency ?? groupCurrency;
      _amountController.text =
          (existing.originalAmount ?? existing.amount).toStringAsFixed(2);
      _titleController.text = existing.description;
      _notesController.text = existing.notes ?? '';
      _selectedCategory =
          _categories.containsKey(existing.category) ? existing.category : 'Other';
      _selectedDate = existing.date;
      _splitType = existing.splitType;
      _paidById = existing.paidById;
    } else {
      _currencyCode = groupCurrency;
      _paidById = state.currentUserId;
      _isRecurring = widget.startAsRecurring;
    }

    _updateSelectedMembersForGroup(state);

    if (existing != null) {
      _applyExistingSplits(existing);
      _applyExistingPayers(existing);
    }
  }

  /// Prefills the "paid by" section from a previously saved expense. Most
  /// expenses have a single payer and this is a no-op beyond what
  /// [_updateSelectedMembersForGroup] already set; a multi-payer expense
  /// switches the form into split-payment mode with each contributor's
  /// real amount.
  void _applyExistingPayers(Expense existing) {
    if (!existing.hasMultiplePayers) return;

    _multiplePayers = true;
    for (final id in _payerSelected.keys.toList()) {
      _payerSelected[id] = existing.payers.containsKey(id);
    }

    _seedingPayerFields = true;
    for (final entry in existing.payers.entries) {
      final field = _payerAmountControllers[entry.key];
      if (field == null) continue;
      field.text = entry.value.toStringAsFixed(2);
    }
    _seedingPayerFields = false;

    _payerFieldsTouched = true;
  }

  /// Prefills who is in the split and each person's figure from a previously
  /// saved expense, overriding the even-split default that
  /// [_updateSelectedMembersForGroup] seeds every field with.
  void _applyExistingSplits(Expense existing) {
    for (final id in _splitMembersSelected.keys.toList()) {
      _splitMembersSelected[id] = existing.splits.containsKey(id);
    }

    _seedingCustomFields = true;
    for (final entry in existing.splits.entries) {
      final field = _customAmountControllers[entry.key];
      if (field == null) continue;
      field.text = _splitType == SplitType.percentage
          ? (existing.amount > 0
              ? (entry.value / existing.amount * 100).toStringAsFixed(2)
              : '')
          : entry.value.toStringAsFixed(2);
    }
    _seedingCustomFields = false;

    // These are the expense's real saved shares, not a guess — stop the
    // even-split auto-fill from overwriting them on the next rebuild.
    _customFieldsTouched = true;
  }

  /// An expense is always in its group's currency. The server-backed group
  /// carries that, so it is read from GroupProvider rather than the lighter
  /// in-memory group held by StateManager.
  /// Every figure on this screen — amount, split shares, payer amounts — is
  /// entered and previewed in [_currencyCode], not necessarily the group's
  /// own; the server converts once this is saved.
  String get _symbol => currencySymbolFor(_currencyCode);

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

    _payerSelected.clear();
    for (final controller in _payerAmountControllers.values) {
      controller.dispose();
    }
    _payerAmountControllers.clear();
    for (final mId in memberIds) {
      _payerSelected[mId] = mId == _paidById;
      _payerAmountControllers[mId] = TextEditingController();
    }
    _payerFieldsTouched = false;
    _seedPayerFields();

    _customFieldsTouched = false;
    _seedCustomFields();
  }

  /// Fills the payer amount fields with an even share of the current total
  /// across whoever is currently marked as a payer — a sane starting point
  /// the user can adjust, mirroring how [_seedCustomFields] seeds splits.
  void _seedPayerFields() {
    if (_payerFieldsTouched) return;

    final ids =
        _payerSelected.entries.where((e) => e.value).map((e) => e.key).toList();
    _seedingPayerFields = true;
    for (final entry in _payerAmountControllers.entries) {
      final isSelected = _payerSelected[entry.key] ?? false;
      if (!isSelected || ids.isEmpty) {
        entry.value.text = '';
        continue;
      }
      final share = _amount / ids.length;
      entry.value.text = _amount <= 0 ? '' : share.toStringAsFixed(2);
    }
    _seedingPayerFields = false;
  }

  void _onPayerToggled(String id, bool value) {
    setState(() {
      _payerSelected[id] = value;
      if (!value) {
        _seedingPayerFields = true;
        _payerAmountControllers[id]?.text = '';
        _seedingPayerFields = false;
      }
      _seedPayerFields();
    });
  }

  void _onPayerAmountChanged() {
    if (_seedingPayerFields) return;
    setState(() => _payerFieldsTouched = true);
  }

  void _resetPayerFields() {
    setState(() {
      _payerFieldsTouched = false;
      _seedPayerFields();
    });
  }

  List<String> get _selectedPayerIds => _multiplePayers
      ? _payerSelected.entries.where((e) => e.value).map((e) => e.key).toList()
      : (_paidById != null ? [_paidById!] : const []);

  double get _payersAssigned => _selectedPayerIds.fold<double>(
        0,
        (sum, id) =>
            sum +
            (double.tryParse(_payerAmountControllers[id]?.text.trim() ?? '') ??
                0),
      );

  double get _payersRemainder => _amount - _payersAssigned;

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

    if (!_multiplePayers && _paidById == null) {
      showAppSnack(context, 'Choose who paid', success: false);
      return;
    }

    final selectedPayers = _selectedPayerIds;
    if (_multiplePayers) {
      if (selectedPayers.isEmpty) {
        showAppSnack(context, 'Choose who paid', success: false);
        return;
      }
      for (final id in selectedPayers) {
        final raw = _payerAmountControllers[id]?.text.trim() ?? '';
        final parsed = double.tryParse(raw);
        if (raw.isEmpty || parsed == null || parsed <= 0) {
          showAppSnack(context, 'Give each payer a valid amount',
              success: false);
          return;
        }
      }
      if (_payersRemainder.abs() > 0.01) {
        showAppSnack(
          context,
          'Payer amounts must add up to ${formatMoney(_amount, symbol: _symbol)}',
          success: false,
        );
        return;
      }
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

    final description = _titleController.text.trim();

    // The server recomputes the splits from these, so an exact or percentage
    // expense is validated in one place rather than two.
    final values = _splitType == SplitType.equal
        ? null
        : _customValues(selectedSplitMembers);
    final notes = _notesController.text.trim();

    // The server only needs a `payers` breakdown when it is more than one
    // person; the primary payer (whoever fronted the most) still goes in
    // `paidById` for every place that only shows a single "paid by" name.
    final payersMap = _multiplePayers
        ? {
            for (final id in selectedPayers)
              id: double.parse(_payerAmountControllers[id]!.text.trim()),
          }
        : null;
    final primaryPayerId = _multiplePayers
        ? payersMap!.entries.reduce((a, b) => b.value > a.value ? b : a).key
        : _paidById!;

    try {
      final result = widget.isEditing
          ? await state.updateExpense(
              expenseId: widget.existingExpense!.id,
              description: description,
              category: _selectedCategory,
              amount: amount,
              paidById: primaryPayerId,
              payers: payersMap,
              splitType: _splitType,
              participants: selectedSplitMembers,
              values: values,
              date: _selectedDate,
              notes: notes,
              currency: _currencyCode,
            )
          : _isRecurring
              ? await state.createRecurringExpense(
                  groupId: widget.groupId,
                  description: description,
                  category: _selectedCategory,
                  amount: amount,
                  paidById: primaryPayerId,
                  payers: payersMap,
                  splitType: _splitType,
                  participants: selectedSplitMembers,
                  values: values,
                  frequency: _frequency,
                  startDate: _selectedDate,
                )
              : await state.saveExpense(
                  description: description,
                  category: _selectedCategory,
                  amount: amount,
                  paidById: primaryPayerId,
                  payers: payersMap,
                  splitType: _splitType,
                  participants: selectedSplitMembers,
                  splits: _calculateSplits(amount, selectedSplitMembers),
                  values: values,
                  groupId: widget.groupId,
                  date: _selectedDate,
                  notes: notes,
                );

      if (!mounted) return;

      if (result['success'] != true) {
        showAppSnack(
          context,
          (result['message'] ??
                  'Could not ${widget.isEditing ? 'update' : 'save'} the expense')
              .toString(),
          success: false,
        );
        return;
      }

      if (_isRecurring && !widget.isEditing) {
        // The server may have already created the first occurrence (a
        // start date of today is due immediately) — pick it up so it shows
        // in the group right away instead of waiting for a manual refresh.
        await state.loadGroupExpenses(widget.groupId);
        if (!mounted) return;
        context.read<GroupProvider>().refreshGroup(widget.groupId);
      }

      state.pushNotification(
        kind: ActivityKind.expenseAdded,
        title: _isRecurring && !widget.isEditing
            ? 'You set up "$description" to repeat ${_frequency.label.toLowerCase()}'
            : 'You ${widget.isEditing ? 'updated' : 'added'} "$description"',
        subtitle:
            '${formatMoney(amount, symbol: symbol)} · split ${selectedSplitMembers.length} ways',
      );

      showAppSnack(
        context,
        widget.isEditing
            ? 'Expense updated'
            : _isRecurring
                ? 'Recurring expense set up'
                : 'Expense saved',
      );

      if (widget.isEditing) {
        // An edit is reached through Group -> Expense detail -> here; after
        // saving the change, go straight back to Home rather than retracing
        // those screens one at a time.
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.pop(context, true);
      }
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
    _titleController.dispose();
    _notesController.dispose();
    for (final controller in _customAmountControllers.values) {
      controller.dispose();
    }
    for (final controller in _payerAmountControllers.values) {
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
    // Every figure on this screen previews in whatever currency is
    // currently selected, which may not be the group's own — the server
    // converts on save. The group's currency is only needed for the
    // "converts to ..." note below the picker.
    final symbol = _symbol;
    final groupCurrencyCode = context
            .watch<GroupProvider>()
            .groupById(widget.groupId)
            ?.currency ??
        kDefaultCurrencyCode;
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
            Text(widget.isEditing ? 'Edit expense' : 'Add expense'),
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
                    onChanged: (_) => setState(() {
                      _seedCustomFields();
                      _seedPayerFields();
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: IgnorePointer(
                      ignoring: _isRecurring,
                      child: Opacity(
                        opacity: _isRecurring ? 0.5 : 1,
                        child: _CurrencyPicker(
                          selected: _currencyCode,
                          onChanged: (code) => setState(() => _currencyCode = code),
                        ),
                      ),
                    ),
                  ),
                  if (_currencyCode != groupCurrencyCode) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Converts to ${currencySymbolFor(groupCurrencyCode)} '
                        '($groupCurrencyCode) when saved',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  PSTextField(
                    label: 'Title',
                    placeholder: 'What was this for? e.g. Tea, Cab fare',
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Give this expense a title'
                        : null,
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

                  _PickerField(
                    label: 'Date',
                    value: _formatDate(_selectedDate),
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Row(
                    children: [
                      const Expanded(child: _FieldLabel('Paid by')),
                      if (activeMembers.length > 1)
                        GestureDetector(
                          onTap: () => setState(() {
                            if (_multiplePayers) {
                              _multiplePayers = false;
                            } else {
                              _multiplePayers = true;
                              _payerFieldsTouched = false;
                              _seedPayerFields();
                            }
                          }),
                          child: Text(
                            _multiplePayers
                                ? 'Paid by one person'
                                : 'Split payment',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primaryDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (!_multiplePayers)
                    _TappableField(
                      value: _payerName(activeMembers),
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => _pickPayer(activeMembers),
                    )
                  else ...[
                    _PayerList(
                      members: activeMembers,
                      selected: _payerSelected,
                      controllers: _payerAmountControllers,
                      currencySymbol: symbol,
                      onToggle: _onPayerToggled,
                      onAmountChanged: _onPayerAmountChanged,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _RemainderBar(
                      remainder: _payersRemainder,
                      total: _amount,
                      isPercentage: false,
                      currencySymbol: symbol,
                      onReset: _resetPayerFields,
                      balancedNoun: 'Payments',
                    ),
                  ],
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

                  if (!widget.isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _RepeatToggle(
                      isRecurring: _isRecurring,
                      frequency: _frequency,
                      onChanged: (value) => setState(() {
                        _isRecurring = value;
                        // Recurring templates always post in the group's own
                        // currency — switching one on while a different
                        // currency is selected would silently record every
                        // future occurrence at the wrong amount.
                        if (value) _currencyCode = groupCurrencyCode;
                      }),
                      onFrequencyChanged: (f) => setState(() => _frequency = f),
                    ),
                    if (_isRecurring)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'Recurring expenses always post in the group\'s '
                          'own currency ($groupCurrencyCode).',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
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
                    label: widget.isEditing
                        ? 'Update expense'
                        : _isRecurring
                            ? 'Set up recurring expense'
                            : 'Save expense',
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

/// A tappable field that opens a picker sheet, without its own label —
/// the label sits above it separately (used where a link needs to share
/// that label row, e.g. "Paid by" next to "Split payment").
/// A small "USD ▾" chip under the amount field — tapping opens the same
/// currency list the group and profile currency pickers use.
class _CurrencyPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CurrencyPicker({required this.selected, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final code = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetContext) => _OptionSheet(
        title: 'Currency',
        options: [
          for (final c in kCurrencies)
            _Option(
              id: c.code,
              label: '${c.code} — ${c.name} (${c.symbol})',
              icon: Icons.currency_exchange_rounded,
            ),
        ],
        selectedId: selected,
      ),
    );
    if (code != null) onChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgSubtle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TappableField extends StatelessWidget {
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _TappableField({
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
    );
  }
}

/// Who fronted the money when an expense was split between multiple
/// payers, with each contributor's amount editable — the payer-side
/// counterpart to [_SplitList]'s exact-amount mode.
class _PayerList extends StatelessWidget {
  final List<Member> members;
  final Map<String, bool> selected;
  final Map<String, TextEditingController> controllers;
  final String currencySymbol;
  final void Function(String id, bool value) onToggle;
  final VoidCallback onAmountChanged;

  const _PayerList({
    required this.members,
    required this.selected,
    required this.controllers,
    required this.currencySymbol,
    required this.onToggle,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
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
            _row(members[i]),
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

  Widget _row(Member member) {
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
                    decoration: InputDecoration(
                      prefixText: currencySymbol,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
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

/// "Make this repeat" — a switch that reveals a frequency picker once on,
/// only ever shown when creating a brand-new expense.
class _RepeatToggle extends StatelessWidget {
  final bool isRecurring;
  final RecurringFrequency frequency;
  final ValueChanged<bool> onChanged;
  final ValueChanged<RecurringFrequency> onFrequencyChanged;

  const _RepeatToggle({
    required this.isRecurring,
    required this.frequency,
    required this.onChanged,
    required this.onFrequencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.repeat_rounded, size: 18, color: AppColors.muted),
            const SizedBox(width: AppSpacing.xs),
            const Expanded(
              child: Text(
                'Repeat this expense',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Plain Switch(), no color overrides — the app's shared
            // SwitchThemeData already gives it the same look as the "Push
            // notifications" switch on the Profile screen.
            Switch(
              value: isRecurring,
              onChanged: onChanged,
            ),
          ],
        ),
        if (isRecurring) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.bgSubtle,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: [
                for (final f in RecurringFrequency.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onFrequencyChanged(f),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: f == frequency
                              ? AppColors.bgPrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: f == frequency ? AppShadow.card : null,
                        ),
                        child: Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: f == frequency
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'First charge on the date above, then every ${frequency.label.toLowerCase()}.',
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
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

  /// What "add up to X" is balancing — "Splits" for the split section,
  /// "Payments" for the multi-payer section.
  final String balancedNoun;

  const _RemainderBar({
    required this.remainder,
    required this.total,
    required this.isPercentage,
    required this.currencySymbol,
    required this.onReset,
    this.balancedNoun = 'Splits',
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
                      : '$balancedNoun add up to ${formatMoney(total, symbol: currencySymbol)}')
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
