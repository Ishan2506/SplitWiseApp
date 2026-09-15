import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/currencies.dart';
import '../../widgets/common_widgets.dart';

/// Records a payment that clears part or all of a debt.
///
/// Unlike the older bottom sheet, this writes through to the server, so the
/// balances everyone sees move as soon as it is saved — which is the whole
/// point of marking something settled.
///
/// Pops with `true` when a payment was recorded.
class SettleUpScreen extends StatefulWidget {
  final String groupId;

  /// Who is paying. Defaults to the signed-in user when not given.
  final String? fromUserId;

  /// Who is being paid. Pre-selected when opened from a specific debt.
  final String? toUserId;

  /// The outstanding amount, used to seed the "full amount" option.
  final double? suggestedAmount;

  const SettleUpScreen({
    super.key,
    required this.groupId,
    this.fromUserId,
    this.toUserId,
    this.suggestedAmount,
  });

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  final _amountController = TextEditingController();

  String? _fromId;
  String? _toId;

  /// False once the user chooses "Partial" or edits the amount by hand.
  bool _isFullAmount = true;

  /// Whether the money moved outside the app. Recorded as a note, since the
  /// app does not move money itself.
  bool _recordedAsCash = true;

  bool _isSaving = false;

  /// Guards against the amount listener fighting our own writes.
  bool _seedingAmount = false;

  @override
  void initState() {
    super.initState();

    final currentUserId = context.read<StateManager>().currentUserId;
    _fromId = widget.fromUserId ?? currentUserId;

    // Opened from the group screen there is no specific debt in hand. Falling
    // back to the largest thing the user owes beats landing on a screen with
    // nothing selected and a dead "Mark as settled" button.
    _toId = widget.toUserId ?? _largestDebtRecipient();

    _seedAmount(widget.suggestedAmount ?? _outstandingBetween());
    _amountController.addListener(_onAmountChanged);
  }

  /// Whoever the payer owes the most in this group, or null if nobody.
  String? _largestDebtRecipient() {
    final suggestions =
        context.read<GroupProvider>().balancesFor(widget.groupId).suggestions;

    SettlementSuggestion? largest;
    for (final s in suggestions) {
      if (s.fromId != _fromId) continue;
      if (largest == null || s.amount > largest.amount) largest = s;
    }
    return largest?.toId;
  }

  /// Keeps the full/partial pills honest as the user edits the figure.
  void _onAmountChanged() {
    // Our own seeding is not a user edit, and a disposed screen has nothing
    // left to update.
    if (_seedingAmount || !mounted) return;

    final typed = double.tryParse(_amountController.text.trim()) ?? 0;
    final full = _outstandingBetween();
    final matchesFull = full > 0 && (typed - full).abs() < 0.01;

    if (_isFullAmount != matchesFull) {
      setState(() => _isFullAmount = matchesFull);
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _seedAmount(double value) {
    _seedingAmount = true;
    _amountController.text = value > 0 ? value.toStringAsFixed(2) : '';
    _seedingAmount = false;
  }

  /// What the payer still owes the recipient, per the server's simplified
  /// transfers. Zero when the two are not paired in the suggestions.
  double _outstandingBetween() {
    if (_fromId == null || _toId == null) return 0;
    final suggestions =
        context.read<GroupProvider>().balancesFor(widget.groupId).suggestions;
    for (final s in suggestions) {
      if (s.fromId == _fromId && s.toId == _toId) return s.amount;
    }
    return 0;
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  /// The group's own symbol — a payment is always in the group's currency.
  String get _symbol =>
      context.read<GroupProvider>().groupById(widget.groupId)?.currencySymbol ??
      currencySymbolFor(null);

  Future<void> _save() async {
    final outstanding = _outstandingBetween();

    if (_toId == null || _fromId == null) {
      showAppSnack(context, 'Choose who is being paid', success: false);
      return;
    }
    if (_fromId == _toId) {
      showAppSnack(context, 'Payer and recipient cannot be the same person',
          success: false);
      return;
    }
    if (_amount <= 0) {
      showAppSnack(context, 'Enter an amount greater than zero', success: false);
      return;
    }
    // Overpaying would flip the balance the other way, which is almost always
    // a typo rather than an intention.
    if (outstanding > 0 && _amount - outstanding > 0.01) {
      showAppSnack(
        context,
        'That is more than the ${formatMoney(outstanding, symbol: _symbol)} outstanding',
        success: false,
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<GroupProvider>();
    final state = context.read<StateManager>();
    // Read before awaiting — this touches context, which may be gone after.
    final symbol = _symbol;

    final result = await provider.recordSettlement(
      groupId: widget.groupId,
      fromUserId: _fromId!,
      toUserId: _toId!,
      amount: _amount,
      note: _recordedAsCash ? 'Paid in cash, outside the app' : null,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => _isSaving = false);
      showAppSnack(
        context,
        (result['message'] ?? 'Could not record the payment').toString(),
        success: false,
      );
      return;
    }

    state.pushNotification(
      kind: ActivityKind.settled,
      title: 'Payment of ${formatMoney(_amount, symbol: symbol)} recorded',
      subtitle: 'Balances updated for everyone',
    );

    showAppSnack(context, 'Recorded ${formatMoney(_amount, symbol: symbol)}');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final currentUserId = context.watch<StateManager>().currentUserId;

    final group = provider.groupById(widget.groupId);
    final balances = provider.balancesFor(widget.groupId);
    final symbol = group?.currencySymbol ?? currencySymbolFor(null);

    // Everyone the user could be paying, with what they owe each of them.
    final payable = balances.suggestions
        .where((s) => s.fromId == _fromId)
        .toList();

    final outstanding = _outstandingBetween();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Settle up'),
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
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (balances.suggestions.isNotEmpty)
                  _RecommendedCard(
                    transferCount: balances.suggestions.length,
                  ),
                const SizedBox(height: AppSpacing.lg),

                const _Label('Paying'),
                const SizedBox(height: AppSpacing.xs),
                if (payable.isEmpty)
                  const _NothingToPay()
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < payable.length; i++) ...[
                          _RecipientRow(
                            suggestion: payable[i],
                            selected: payable[i].toId == _toId,
                            currencySymbol: symbol,
                            onTap: () => setState(() {
                              _toId = payable[i].toId;
                              // A different creditor means a different balance,
                              // so re-seed rather than keep a stale figure.
                              _isFullAmount = true;
                              _seedAmount(payable[i].amount);
                            }),
                          ),
                          if (i != payable.length - 1)
                            const Padding(
                              padding: EdgeInsets.only(left: 56),
                              child: Divider(height: 1),
                            ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),

                const _Label('Amount'),
                const SizedBox(height: AppSpacing.xs),
                _AmountCard(
                  controller: _amountController,
                  isFullAmount: _isFullAmount,
                  outstanding: outstanding,
                  currencySymbol: symbol,
                  onFull: () => setState(() {
                    _isFullAmount = true;
                    _seedAmount(outstanding);
                  }),
                  onPartial: () => setState(() => _isFullAmount = false),
                ),
                const SizedBox(height: AppSpacing.md),

                _CashToggle(
                  value: _recordedAsCash,
                  onChanged: (v) => setState(() => _recordedAsCash = v),
                ),
                const SizedBox(height: AppSpacing.xl),

                PSButton(
                  label: 'Mark as settled',
                  onPressed: (_isSaving || _toId == null) ? null : _save,
                  isLoading: _isSaving,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  currentUserId == _fromId
                      ? 'Balances update for everyone immediately'
                      : 'Recording a payment made by someone else',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

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

/// Explains that the listed payments are the simplified set, not every debt.
class _RecommendedCard extends StatelessWidget {
  final int transferCount;

  const _RecommendedCard({required this.transferCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OverlineLabel('Recommended settlement'),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            transferCount == 1
                ? 'One payment clears this group.'
                : '$transferCount payments clear the whole group — '
                    'fewer transfers than settling every debt one by one.',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One person the user can pay, with the amount outstanding.
class _RecipientRow extends StatelessWidget {
  final SettlementSuggestion suggestion;
  final bool selected;
  final String currencySymbol;
  final VoidCallback onTap;

  const _RecipientRow({
    required this.suggestion,
    required this.selected,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.bgSubtle : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              AvatarWidget.forName(suggestion.toName, size: 38),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.toName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'You owe ${formatMoney(suggestion.amount, symbol: currencySymbol)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 21,
                color: selected ? AppColors.ink : AppColors.borderStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The amount being paid, with the full/partial choice beneath it.
class _AmountCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isFullAmount;
  final double outstanding;
  final String currencySymbol;
  final VoidCallback onFull;
  final VoidCallback onPartial;

  const _AmountCard({
    required this.controller,
    required this.isFullAmount,
    required this.outstanding,
    required this.currencySymbol,
    required this.onFull,
    required this.onPartial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              prefixText: '$currencySymbol ',
              prefixStyle: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
              hintText: '0',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Wrap rather than Row: on a narrow phone the two pills would
          // otherwise run past the card's edge.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _Pill(
                label: 'Full amount',
                selected: isFullAmount,
                // Nothing outstanding means there is no "full" to snap to.
                onTap: outstanding > 0 ? onFull : null,
              ),
              _Pill(
                label: 'Partial',
                selected: !isFullAmount,
                onTap: onPartial,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (onTap == null
                    ? AppColors.muted
                    : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// "Recorded as cash · outside app" — the app tracks the payment, it does not
/// move the money, and the switch keeps that honest.
class _CashToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CashToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Recorded as cash · outside app',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Shown when the user owes nobody in this group.
class _NothingToPay extends StatelessWidget {
  const _NothingToPay();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.successBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 19, color: AppColors.success),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'You do not owe anyone in this group.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
