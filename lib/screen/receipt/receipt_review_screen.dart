import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/currencies.dart';
import '../../utils/receipt_parser.dart';
import '../../widgets/common_widgets.dart';

/// Step 2: check what the scan read, fix anything wrong, then save.
///
/// The screen's job is to make a wrong reading obvious and cheap to correct.
/// Every field shows the confidence the parser assigned it, and anything below
/// "high" is tinted and called out at the top, because the expensive mistake
/// here is a plausible-looking wrong total that nobody checks.
///
/// Pops with `true` once the expense is saved.
class ReceiptReviewScreen extends StatefulWidget {
  final String groupId;
  final ReceiptData data;

  /// The photo that was read, shown as a thumbnail so the user can compare.
  final String imagePath;

  const ReceiptReviewScreen({
    super.key,
    required this.groupId,
    required this.data,
    required this.imagePath,
  });

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;

  late DateTime _date;
  late String _category;
  String? _paidById;

  /// Everyone the bill is split across. Seeded with the whole group, which is
  /// the common case for a shared receipt.
  final Map<String, bool> _splitWith = {};

  /// The items read off the bill, editable here. Held in state rather than
  /// read from the scan each build, because the user can correct them.
  late List<ReceiptItem> _items;

  /// Who is down for each item, keyed by the item's index in [_items].
  /// An item nobody is assigned to is treated as shared by everyone splitting
  /// the bill — the common case for rice, bread and anything else in the
  /// middle of the table.
  final Map<int, Set<String>> _itemAssignments = {};

  /// Whether to divide the bill by item rather than evenly. Only offered when
  /// the scan produced items that add up.
  bool _splitByItem = false;

  bool _isSaving = false;

  /// Fields the user has corrected. Once touched, a field stops being flagged
  /// as low confidence — they have looked at it, which is all the flag asked.
  final Set<String> _corrected = {};

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

    final data = widget.data;
    _merchantController = TextEditingController(text: data.merchant.value ?? '')
      ..addListener(() => _markCorrected('merchant'));
    _amountController = TextEditingController(
      text: data.total.value != null ? data.total.value!.toStringAsFixed(2) : '',
    )..addListener(() => _markCorrected('total'));

    // A missing date almost always means today's receipt, which beats an
    // empty field the user must fill in by hand.
    _date = data.date.value ?? DateTime.now();
    _category = data.category.value ?? 'Food & drink';

    _items = List.of(data.items);

    final state = context.read<StateManager>();
    _paidById = state.currentUserId;
    for (final id in _memberIdsFor(state)) {
      _splitWith[id] = true;
    }
  }

  /// Whether splitting by item is worth offering.
  ///
  /// Only when the items reconcile with the total. Items that do not add up
  /// have rows missing or double-counted, and dividing by them would put real
  /// money in the wrong place — the kind of error nobody notices until they
  /// settle up. Offering an even split there is the honest option.
  bool get _canSplitByItem => widget.data.itemsReconcile && _items.isNotEmpty;

  List<String> _memberIdsFor(StateManager state) {
    final group = state.groups.where((g) => g.id == widget.groupId).firstOrNull;
    return group?.memberIds ?? state.members.map((m) => m.id).toList();
  }

  /// The receipt is entered in the group's currency, which only the
  /// server-backed group knows about.
  String get _symbol =>
      context.read<GroupProvider>().groupById(widget.groupId)?.currencySymbol ??
      currencySymbolFor(null);

  /// Notes that the user has edited a field, which clears its low-confidence
  /// flag — they have looked at it, which is all the flag was asking for.
  void _markCorrected(String field) {
    if (!mounted || _corrected.contains(field)) return;
    setState(() => _corrected.add(field));
  }

  /// The confidence to display for a field: whatever the parser said, unless
  /// the user has since edited it.
  FieldConfidence _confidenceOf(String field, ExtractedField<Object?> parsed) =>
      _corrected.contains(field) ? FieldConfidence.high : parsed.confidence;

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  List<String> get _selectedIds =>
      _splitWith.entries.where((e) => e.value).map((e) => e.key).toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _corrected.add('date');
      });
    }
  }

  Future<void> _save() async {
    final participants = _selectedIds;

    if (_amount <= 0) {
      showAppSnack(context, 'Enter an amount greater than zero', success: false);
      return;
    }
    if (participants.isEmpty) {
      showAppSnack(context, 'Pick at least one person to split with',
          success: false);
      return;
    }
    if (_paidById == null) {
      showAppSnack(context, 'Choose who paid', success: false);
      return;
    }

    setState(() => _isSaving = true);
    final state = context.read<StateManager>();
    // Read before awaiting — this touches context, which may be gone after.
    final symbol = _symbol;

    // The merchant name is the most useful label; fall back to the category
    // when the scan could not read one.
    final merchant = _merchantController.text.trim();
    final description = merchant.isEmpty ? _category : merchant;

    try {
      // By item the shares are uneven by design, so they are stored as exact
      // amounts rather than as an even division.
      final byItem = _splitByItem && _canSplitByItem;
      final result = await state.saveExpense(
        description: description,
        category: _category,
        amount: _amount,
        paidById: _paidById!,
        splitType: byItem ? SplitType.exact : SplitType.equal,
        participants: participants,
        splits: byItem
            ? _itemSplits(_amount, participants)
            : _equalSplits(_amount, participants),
        groupId: widget.groupId,
        date: _date,
        notes: byItem
            ? 'Added from a scanned receipt · split by item'
            : 'Added from a scanned receipt',
      );

      if (!mounted) return;

      if (result['success'] != true) {
        setState(() => _isSaving = false);
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
        subtitle: '${formatMoney(_amount, symbol: symbol)} · from a receipt',
      );

      showAppSnack(context, 'Expense saved');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppSnack(context, 'Could not save: $e', success: false);
    }
  }

  /// Drops a misread row. The bill's total is left alone — it was read
  /// separately and is what the restaurant actually charged, so removing a
  /// stray row should not silently change what everyone owes.
  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      // Assignments are keyed by position, so they have to shift down with
      // the items they belong to.
      final shifted = <int, Set<String>>{};
      _itemAssignments.forEach((i, who) {
        if (i < index) {
          shifted[i] = who;
        } else if (i > index) {
          shifted[i - 1] = who;
        }
      });
      _itemAssignments
        ..clear()
        ..addAll(shifted);
    });
  }

  /// Marks that someone did or did not have a given item.
  void _toggleAssignment(int index, String memberId) {
    setState(() {
      final who = _itemAssignments.putIfAbsent(index, () => <String>{});
      if (!who.remove(memberId)) who.add(memberId);
      if (who.isEmpty) _itemAssignments.remove(index);
    });
  }

  /// Splits the bill by who had what.
  ///
  /// Each item's cost goes to the people assigned to it, divided evenly among
  /// them; an item with nobody assigned is shared by everyone, which is what
  /// the shared dishes in the middle of the table actually are.
  ///
  /// The bill's total is usually more than the items add up to, because tax
  /// and service are added at the foot. That difference is spread in
  /// proportion to what each person ate, so the person who ordered the most
  /// carries the most tax — the same answer as splitting each summary line
  /// pro rata, without needing to read those lines correctly.
  ///
  /// Returns shares that sum to [total] exactly.
  Map<String, double> _itemSplits(double total, List<String> members) {
    if (members.isEmpty) return {};

    final memberSet = members.toSet();
    // Work in paise: money divided into thirds does not survive as doubles,
    // and this has to add back up to the paisa.
    final owed = {for (final m in members) m: 0};

    var assignedPaise = 0;
    for (var i = 0; i < _items.length; i++) {
      // Only people actually splitting this bill can be charged for an item.
      final assigned = (_itemAssignments[i] ?? const <String>{})
          .where(memberSet.contains)
          .toList();
      final eaters = assigned.isEmpty ? members : assigned;

      final itemPaise = (_items[i].lineTotal * 100).round();
      final each = itemPaise ~/ eaters.length;
      var remainder = itemPaise - each * eaters.length;

      for (final m in eaters) {
        // The odd paise go to the first few eaters. Deterministic, so the
        // same bill always splits the same way.
        owed[m] = owed[m]! + each + (remainder > 0 ? 1 : 0);
        if (remainder > 0) remainder--;
      }
      assignedPaise += itemPaise;
    }

    // Tax, service and anything else the items did not cover, shared in
    // proportion to each person's share of the items.
    final totalPaise = (total * 100).round();
    final extraPaise = totalPaise - assignedPaise;
    if (extraPaise != 0 && assignedPaise > 0) {
      var distributed = 0;
      final ordered = members.toList();
      for (final m in ordered) {
        final share = (extraPaise * owed[m]!) ~/ assignedPaise;
        owed[m] = owed[m]! + share;
        distributed += share;
      }
      // Integer division leaves a few paise over; give them to the largest
      // shares first so the rounding follows the money.
      var leftover = extraPaise - distributed;
      ordered.sort((a, b) => owed[b]!.compareTo(owed[a]!));
      for (var i = 0; leftover > 0 && ordered.isNotEmpty; i++, leftover--) {
        owed[ordered[i % ordered.length]] =
            owed[ordered[i % ordered.length]]! + 1;
      }
    }

    // Guard the invariant: whatever the arithmetic above did, the shares must
    // add up to the bill. Any residue lands on the payer, who is the person
    // best placed to notice it.
    final sum = owed.values.fold<int>(0, (a, b) => a + b);
    final drift = totalPaise - sum;
    if (drift != 0) {
      final absorber =
          members.contains(_paidById) ? _paidById! : members.first;
      owed[absorber] = owed[absorber]! + drift;
    }

    return {for (final e in owed.entries) e.key: e.value / 100};
  }

  /// Even split where the last person absorbs the rounding, so the shares add
  /// up to the total to the paisa.
  Map<String, double> _equalSplits(double total, List<String> members) {
    final per = (total / members.length * 100).roundToDouble() / 100;
    final splits = {for (final m in members) m: per};

    final sum = splits.values.fold<double>(0, (a, b) => a + b);
    final drift = ((total - sum) * 100).roundToDouble() / 100;
    if (drift != 0) {
      splits[members.last] =
          ((splits[members.last]! + drift) * 100).roundToDouble() / 100;
    }
    return splits;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final group = state.groups.where((g) => g.id == widget.groupId).firstOrNull;
    final symbol = context
            .watch<GroupProvider>()
            .groupById(widget.groupId)
            ?.currencySymbol ??
        currencySymbolFor(null);
    final members = group != null
        ? state.members.where((m) => group.memberIds.contains(m.id)).toList()
        : state.members;

    final selectedCount = _selectedIds.length;
    final perHead = selectedCount > 0 ? _amount / selectedCount : 0.0;

    // Recompute against the current edits rather than the original scan.
    final stillUnchecked = [
      _confidenceOf('merchant', widget.data.merchant),
      _confidenceOf('total', widget.data.total),
      _confidenceOf('date', widget.data.date),
      _confidenceOf('category', widget.data.category),
    ].any((c) => c != FieldConfidence.high);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScanSummary(
                  fieldsFound: widget.data.fieldsFound,
                  needsChecking: stillUnchecked,
                  imagePath: widget.imagePath,
                ),
                const SizedBox(height: AppSpacing.lg),

                _ReviewField(
                  label: 'Merchant',
                  confidence: _confidenceOf('merchant', widget.data.merchant),
                  child: TextField(
                    controller: _merchantController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Who was paid',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                _ReviewField(
                  label: 'Total amount',
                  confidence: _confidenceOf('total', widget.data.total),
                  child: TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      prefixText: symbol,
                      hintText: '0.00',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                _ReviewField(
                  label: 'Date',
                  confidence: _confidenceOf('date', widget.data.date),
                  child: InkWell(
                    onTap: _pickDate,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          Text(
                            _formatDate(_date),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.calendar_today_rounded,
                              size: 16, color: AppColors.muted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                _ReviewField(
                  label: 'Suggested category',
                  confidence: _confidenceOf('category', widget.data.category),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final entry in _categories.entries)
                          _CategoryChip(
                            label: entry.key,
                            icon: entry.value,
                            selected: entry.key == _category,
                            onTap: () => setState(() {
                              _category = entry.key;
                              _corrected.add('category');
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                if (_items.isNotEmpty) ...[
                  SectionHeader(title: 'Items on the bill (${_items.length})'),
                  _ItemsCard(
                    items: _items,
                    itemsTotal: widget.data.itemsTotal,
                    billTotal: _amount,
                    reconciles: widget.data.itemsReconcile,
                    currencySymbol: symbol,
                    onRemove: _removeItem,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                const SectionHeader(title: 'Paid by · Split between'),
                _PayerRow(
                  members: members,
                  paidById: _paidById,
                  onChanged: (id) => setState(() => _paidById = id),
                ),
                const SizedBox(height: AppSpacing.sm),

                if (_canSplitByItem) ...[
                  _SplitModeToggle(
                    byItem: _splitByItem,
                    onChanged: (v) => setState(() => _splitByItem = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                _SplitSummary(
                  members: members,
                  selected: _splitWith,
                  perHead: perHead,
                  currencySymbol: symbol,
                  onToggle: (id, value) =>
                      setState(() => _splitWith[id] = value),
                ),

                // Who had what. Shown only when dividing by item, since it is
                // a lot of controls to put in front of someone splitting evenly.
                if (_splitByItem && _canSplitByItem) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AssignmentList(
                    items: _items,
                    members: members
                        .where((m) => _splitWith[m.id] ?? false)
                        .toList(),
                    assignments: _itemAssignments,
                    currencySymbol: symbol,
                    onToggle: _toggleAssignment,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PerPersonSummary(
                    splits: _itemSplits(_amount, _selectedIds),
                    members: members,
                    currencySymbol: symbol,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),

                Row(
                  children: [
                    Expanded(
                      child: PSButton(
                        label: 'Rescan',
                        variant: PSButtonVariant.secondary,
                        onPressed:
                            _isSaving ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      flex: 2,
                      child: PSButton(
                        label: 'Confirm & save',
                        onPressed: _isSaving ? null : _save,
                        isLoading: _isSaving,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// "We read N fields" — with the receipt thumbnail beside it so the user can
/// glance between the photo and what we made of it.
class _ScanSummary extends StatelessWidget {
  final int fieldsFound;
  final bool needsChecking;
  final String imagePath;

  const _ScanSummary({
    required this.fieldsFound,
    required this.needsChecking,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: needsChecking ? AppColors.primarySurface : AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: needsChecking
              ? AppColors.primaryBorder
              : AppColors.successBorder,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: _Thumbnail(path: imagePath),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We read $fieldsFound field${fieldsFound == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  needsChecking
                      ? 'Check anything marked low confidence before saving.'
                      : 'Everything scanned cleanly — worth a quick look.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The captured photo. Falls back to an icon if the file has gone — a scan
/// reviewed after the temp file was cleaned up should not crash the screen.
class _Thumbnail extends StatelessWidget {
  final String path;

  const _Thumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      width: 52,
      height: 64,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: 52,
        height: 64,
        color: AppColors.bgSubtle,
        child: const Icon(Icons.receipt_long_rounded,
            size: 22, color: AppColors.muted),
      ),
    );
  }
}

/// A labelled field carrying its confidence badge, tinted when it needs a look.
class _ReviewField extends StatelessWidget {
  final String label;
  final FieldConfidence confidence;
  final Widget child;

  const _ReviewField({
    required this.label,
    required this.confidence,
    required this.child,
  });

  bool get _flagged => confidence != FieldConfidence.high;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _flagged ? AppColors.primaryBorder : AppColors.border,
          width: _flagged ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              _ConfidenceBadge(confidence: confidence),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

/// HIGH / MED / LOW, in the same places the mockup puts them.
class _ConfidenceBadge extends StatelessWidget {
  final FieldConfidence confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (confidence) {
      FieldConfidence.high => (AppColors.successLight, AppColors.success),
      FieldConfidence.medium => (AppColors.warningLight, AppColors.warning),
      FieldConfidence.low => (AppColors.primaryLight, AppColors.primaryDark),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        confidence.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who paid, as a horizontal strip of avatars.
class _PayerRow extends StatelessWidget {
  final List<Member> members;
  final String? paidById;
  final ValueChanged<String> onChanged;

  const _PayerRow({
    required this.members,
    required this.paidById,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final member = members[i];
          final isPayer = member.id == paidById;
          return GestureDetector(
            onTap: () => onChanged(member.id),
            child: SizedBox(
              width: 62,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPayer
                            ? AppColors.primaryAccent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: AvatarWidget.forName(member.name, size: 40),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isPayer ? FontWeight.w800 : FontWeight.w600,
                      color: isPayer
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
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

/// Who the bill splits across, with the resulting per-head figure.
class _SplitSummary extends StatelessWidget {
  final List<Member> members;
  final Map<String, bool> selected;
  final double perHead;
  final String currencySymbol;
  final void Function(String id, bool value) onToggle;

  const _SplitSummary({
    required this.members,
    required this.selected,
    required this.perHead,
    required this.currencySymbol,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Split equally',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${formatMoney(perHead, decimals: true, symbol: currencySymbol)} each',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryAccent,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final member in members)
            CheckboxListTile(
              value: selected[member.id] ?? false,
              onChanged: (v) => onToggle(member.id, v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: AppColors.primaryAccent,
              title: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              secondary: Text(
                (selected[member.id] ?? false)
                    ? formatMoney(perHead, decimals: true, symbol: currencySymbol)
                    : '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: (selected[member.id] ?? false)
                      ? AppColors.textPrimary
                      : AppColors.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The bill's line items, with a running check that they add up.
///
/// The reconciliation line is the point of this card. A scan that reads eight
/// of nine dishes looks perfectly plausible row by row; only the sum gives it
/// away, which is why the comparison against the bill's own total is shown
/// rather than left for the user to do in their head.
class _ItemsCard extends StatelessWidget {
  final List<ReceiptItem> items;
  final double itemsTotal;
  final double billTotal;
  final bool reconciles;
  final String currencySymbol;
  final void Function(int index) onRemove;

  const _ItemsCard({
    required this.items,
    required this.itemsTotal,
    required this.billTotal,
    required this.reconciles,
    required this.currencySymbol,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Compare against what the user currently has in the amount box, not the
    // scanned total: if they corrected the total, that is the number the items
    // now have to agree with.
    final difference = billTotal - itemsTotal;
    final agrees = reconciles && difference.abs() <= billTotal * 0.2;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _ItemRow(
              item: items[i],
              currencySymbol: currencySymbol,
              isLast: i == items.length - 1,
              onRemove: () => onRemove(i),
            ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: agrees ? AppColors.successLight : AppColors.warningLight,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.lg),
              ),
              border: Border(
                top: BorderSide(
                  color: agrees
                      ? AppColors.successBorder
                      : AppColors.primaryBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  agrees
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: agrees ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    agrees
                        ? 'Items add up to ${formatMoney(itemsTotal, symbol: currencySymbol)} of the ${formatMoney(billTotal, symbol: currencySymbol)} bill.'
                        : 'Items add up to ${formatMoney(itemsTotal, symbol: currencySymbol)}, but the bill says ${formatMoney(billTotal, symbol: currencySymbol)}. A row may have been missed.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: agrees ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One item: what it was, how many, and what it cost.
class _ItemRow extends StatelessWidget {
  final ReceiptItem item;
  final String currencySymbol;
  final bool isLast;
  final VoidCallback onRemove;

  const _ItemRow({
    required this.item,
    required this.currencySymbol,
    required this.isLast,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (item.quantity > 1)
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${item.quantity}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            formatMoney(item.lineTotal, symbol: currencySymbol),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 16),
            color: AppColors.muted,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: 'Remove ${item.name}',
          ),
        ],
      ),
    );
  }
}

/// Chooses between splitting the bill evenly and splitting it by item.
class _SplitModeToggle extends StatelessWidget {
  final bool byItem;
  final ValueChanged<bool> onChanged;

  const _SplitModeToggle({required this.byItem, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeButton(
            label: 'Split evenly',
            icon: Icons.balance_rounded,
            selected: !byItem,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ModeButton(
            label: 'Split by item',
            icon: Icons.restaurant_menu_rounded,
            selected: byItem,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primaryBorder : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.textPrimary : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.textPrimary : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who had what: one row per item, with a chip per person.
///
/// Leaving an item unassigned means everyone shares it, which matches how
/// shared dishes actually work and saves tapping every name on the rice.
class _AssignmentList extends StatelessWidget {
  final List<ReceiptItem> items;
  final List<Member> members;
  final Map<int, Set<String>> assignments;
  final String currencySymbol;
  final void Function(int index, String memberId) onToggle;

  const _AssignmentList({
    required this.items,
    required this.members,
    required this.assignments,
    required this.currencySymbol,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            'Tap who had each item. Anything left untapped is shared by everyone.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (var i = 0; i < items.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].quantity > 1
                            ? '${items[i].quantity}x ${items[i].name}'
                            : items[i].name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(items[i].lineTotal, symbol: currencySymbol),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final m in members)
                      _PersonChip(
                        label: m.name,
                        selected: assignments[i]?.contains(m.id) ?? false,
                        onTap: () => onToggle(i, m.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PersonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primaryBorder : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.textPrimary : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

/// What each person ends up owing once the items are divided — the number that
/// actually lands in the ledger, shown before it is saved rather than after.
class _PerPersonSummary extends StatelessWidget {
  final Map<String, double> splits;
  final List<Member> members;
  final String currencySymbol;

  const _PerPersonSummary({
    required this.splits,
    required this.members,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final owing = members.where((m) => splits.containsKey(m.id)).toList();
    if (owing.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Each person owes',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final m in owing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      m.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    // Decimals here, unlike elsewhere in the app: these are
                    // the exact amounts that go into the ledger, and rounding
                    // three shares of a 100 bill to whole rupees would show
                    // 99 and look like the split had lost money.
                    formatMoney(
                      splits[m.id] ?? 0,
                      symbol: currencySymbol,
                      decimals: true,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
