import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/currencies.dart';
import '../../utils/payment_links.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/payment_options.dart';
import '../groups/group_detail_screen.dart';
import 'people_balances_screen.dart';

/// Where the signed-in user stands with one person across every shared
/// group: the per-group debts, the net they add up to, and a way to settle
/// the lot in one go.
class PersonBalanceScreen extends StatefulWidget {
  final String userId;

  const PersonBalanceScreen({super.key, required this.userId});

  @override
  State<PersonBalanceScreen> createState() => _PersonBalanceScreenState();
}

class _PersonBalanceScreenState extends State<PersonBalanceScreen> {
  bool _saving = false;

  /// Remembered so the "all settled" state can still say who with, after the
  /// person drops out of the (now settled) balances list.
  String _lastKnownName = '';

  /// Records settlements in every shared group so the whole net is cleared.
  Future<void> _settleAll(PersonBalance p, PaymentMethod method) async {
    setState(() => _saving = true);
    final groups = context.read<GroupProvider>();
    final state = context.read<StateManager>();
    final amountText = formatMoney(p.settleAmount!.abs(),
        symbol: currencySymbolFor(p.settleCurrency), decimals: true);

    final result = await groups.settleNetBalance(
      userId: p.person.id,
      method: method.wireValue,
      note: p.spansGroups
          ? '${method.note} · settled across all shared groups'
          : method.note,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] != true) {
      showAppSnack(
        context,
        (result['message'] ?? 'Could not record the settlement').toString(),
        success: false,
      );
      return;
    }

    state.pushNotification(
      kind: ActivityKind.settled,
      title: 'Settled up with ${p.person.name}',
      subtitle: '$amountText net across ${p.groups.length} '
          'group${p.groups.length == 1 ? '' : 's'}',
    );
    showAppSnack(context, 'All settled with ${p.person.name}');
    // Group screens and the expense list read their own copies.
    for (final g in p.groups) {
      groups.refreshGroup(g.groupId);
    }
  }

  Future<void> _confirmManualSettle(PersonBalance p) async {
    final symbol = currencySymbolFor(p.settleCurrency);
    final amountText =
        formatMoney(p.settleAmount!.abs(), symbol: symbol, decimals: true);
    final owesYou = p.theyOweYou;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(owesYou
            ? 'Did ${p.person.name} pay you $amountText?'
            : 'Did you pay ${p.person.name} $amountText?'),
        content: Text(
          p.spansGroups
              ? 'This clears your balances in all ${p.groups.length} groups '
                  'you share — each group gets its own settlement, so every '
                  'group\'s numbers stay right.'
              : 'This records the payment in ${p.groups.first.groupName}.',
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
            label: 'Mark settled',
            size: PSButtonSize.small,
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _settleAll(p, PaymentMethod.cash);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<GroupProvider>().netBalances;
    final p = all.forPerson(widget.userId);
    if (p != null) _lastKnownName = p.person.name;

    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyStateWidget(
          iconData: Icons.handshake_outlined,
          title: 'All settled',
          subtitle: _lastKnownName.isEmpty
              ? 'There is nothing open between you two.'
              : 'You and $_lastKnownName are square in every group.',
        ),
      );
    }

    final owesYou = p.theyOweYou;
    final color = owesYou ? AppColors.success : AppColors.negative;
    final canSettleAtOnce = p.isSingleCurrency && p.settleAmount != null;

    return Scaffold(
      appBar: AppBar(title: Text(p.person.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                _NetHeader(person: p, all: all, color: color),
                const SizedBox(height: AppSpacing.xl),

                SectionHeader(
                  title: 'By group',
                  subtitle: p.spansGroups
                      ? 'Netted into the figure above'
                      : null,
                ),
                _GroupBreakdown(person: p),
                if (p.spansGroups && canSettleAtOnce) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _NettingExplainer(person: p),
                ],
                const SizedBox(height: AppSpacing.xl),

                if (!canSettleAtOnce)
                  Text(
                    'These balances are in different currencies, so they '
                    'can\'t be cleared with one payment. Open each group to '
                    'settle it there.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else if (!owesYou) ...[
                  // You're paying: offer the pre-filled UPI / PayPal link for
                  // the whole net amount.
                  PaymentOptions(
                    payeeName: p.person.name,
                    upiId: p.person.upiId,
                    paypalMe: p.person.paypalMe,
                    currency: p.settleCurrency!,
                    currencySymbol: currencySymbolFor(p.settleCurrency),
                    amount: () => p.settleAmount!.abs(),
                    note: 'PaisaSplit settle up',
                    onPaid: (method) => _settleAll(p, method),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PSButton(
                    label: 'I paid another way — mark settled',
                    variant: PSButtonVariant.secondary,
                    isLoading: _saving,
                    onPressed: _saving ? null : () => _confirmManualSettle(p),
                  ),
                ] else
                  PSButton(
                    label: '${p.person.name} paid me — mark settled',
                    isLoading: _saving,
                    onPressed: _saving ? null : () => _confirmManualSettle(p),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetHeader extends StatelessWidget {
  final PersonBalance person;
  final NetBalances all;
  final Color color;

  const _NetHeader({
    required this.person,
    required this.all,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final owesYou = person.theyOweYou;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: owesYou ? AppColors.successLight : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: owesYou ? AppColors.successBorder : AppColors.primaryBorder,
        ),
      ),
      child: Row(
        children: [
          AvatarWidget.forName(
            person.person.name,
            size: 52,
            imageUrl:
                person.person.avatarUrl.isEmpty ? null : person.person.avatarUrl,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OverlineLabel(
                  owesYou
                      ? '${person.person.name} owes you'
                      : 'You owe ${person.person.name}',
                  color: owesYou
                      ? const Color(0xFF4F8A68)
                      : const Color(0xFFC2607C),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPersonNet(person, all),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.05,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  person.spansGroups
                      ? 'Net, across ${person.groups.length} groups'
                      : 'In ${person.groups.first.groupName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupBreakdown extends StatelessWidget {
  final PersonBalance person;

  const _GroupBreakdown({required this.person});

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
          for (var i = 0; i < person.groups.length; i++) ...[
            _GroupDebtRow(debt: person.groups[i], name: person.person.name),
            if (i != person.groups.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _GroupDebtRow extends StatelessWidget {
  final PersonGroupDebt debt;
  final String name;

  const _GroupDebtRow({required this.debt, required this.name});

  @override
  Widget build(BuildContext context) {
    final owesYou = debt.amount > 0;
    final group = context.watch<GroupProvider>().groupById(debt.groupId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: group == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupDetailScreen(groupId: debt.groupId),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (group?.type.color ?? AppColors.muted)
                      .withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  group?.type.icon ?? Icons.groups_outlined,
                  size: 18,
                  color: group?.type.color ?? AppColors.muted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      owesYou ? '$name owes you' : 'You owe $name',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${owesYou ? '+' : '−'}'
                '${formatMoney(debt.amount.abs(), symbol: debt.currencySymbol)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: owesYou ? AppColors.success : AppColors.negative,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "₹500 − ₹200 = ₹300" — shows the netting so the single figure is
/// believable rather than magic.
class _NettingExplainer extends StatelessWidget {
  final PersonBalance person;

  const _NettingExplainer({required this.person});

  @override
  Widget build(BuildContext context) {
    final symbol = currencySymbolFor(person.settleCurrency);
    final owedToYou = person.groups
        .where((g) => g.amount > 0)
        .fold<double>(0, (sum, g) => sum + g.amount);
    final youOwe = person.groups
        .where((g) => g.amount < 0)
        .fold<double>(0, (sum, g) => sum - g.amount);
    final net = person.settleAmount!.abs();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '${formatMoney(owedToYou, symbol: symbol)} owed to you − '
        '${formatMoney(youOwe, symbol: symbol)} you owe = '
        '${formatMoney(net, symbol: symbol)} net. One payment of that settles '
        'every group.',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
