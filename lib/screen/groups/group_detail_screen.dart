import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import '../add_expense_screen.dart';
import '../settle_up_dialog.dart';
import 'create_group_screen.dart';
import 'group_members_screen.dart';
import 'group_widgets.dart';
import 'invite_screen.dart';

/// One group: what it is, where everyone stands, and who should pay whom.
class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Balances change whenever anyone adds an expense, so always refetch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().refreshGroup(widget.groupId);
    });
  }

  Future<void> _confirmDelete(GroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this group?'),
        content: Text(
          'Every expense and settlement in "${group.name}" will be deleted '
          'too. This cannot be undone.',
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

    if (confirmed != true || !mounted) return;

    final result = await context.read<GroupProvider>().deleteGroup(group.id);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(context);
      showGroupSnack(context, 'Deleted "${group.name}"');
    } else {
      showGroupSnack(context, result['message'] ?? 'Could not delete the group',
          success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final group = provider.groupById(widget.groupId);

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

    final currentUserId = context.read<StateManager>().currentUserId;
    final isCreator = group.isCreatedBy(currentUserId);
    final balances = provider.balancesFor(group.id);
    final userBalance = balances.balanceFor(currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Invite people',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InviteScreen(groupId: group.id)),
            ),
          ),
          if (isCreator)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateGroupScreen(existingGroupId: group.id),
                    ),
                  );
                } else if (value == 'delete') {
                  _confirmDelete(group);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit group'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Delete group',
                          style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryAccent,
        onRefresh: () => provider.refreshGroup(group.id),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  _GroupHeader(group: group),
                  const SizedBox(height: AppSpacing.md),
                  _YourPosition(
                    balance: userBalance,
                    onSettle: () async {
                      final recorded = await SettleUpDialog.show(context,
                          groupId: group.id);
                      if (recorded == true && context.mounted) {
                        provider.refreshGroup(group.id);
                      }
                    },
                    onAddExpense: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddExpenseScreen(preselectedGroupId: group.id),
                      ),
                    ),
                  ),
                  if (group.hasBalanceLimit) ...[
                    const SizedBox(height: AppSpacing.md),
                    _LimitCard(
                      group: group,
                      balances: balances,
                      currentUserId: currentUserId,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  SectionHeader(
                    title: 'Member balances',
                    actionLabel: 'Manage',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupMembersScreen(groupId: group.id),
                      ),
                    ),
                  ),
                  _MemberBalanceList(
                    group: group,
                    balances: balances,
                    currentUserId: currentUserId,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const SectionHeader(title: 'Who pays whom'),
                  _SettlementList(
                    balances: balances,
                    currentUserId: currentUserId,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Group identity: avatar, type and member count.
class _GroupHeader extends StatelessWidget {
  final GroupModel group;

  const _GroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return PSCard(
      child: Row(
        children: [
          GroupAvatar(group: group, size: 50),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${group.type.label} · ${group.members.length} member'
                  '${group.members.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (group.description.isNotEmpty &&
                    group.description != group.type.label) ...[
                  const SizedBox(height: 3),
                  Text(
                    group.description,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the signed-in user stands in this group, plus the two main actions.
class _YourPosition extends StatelessWidget {
  final double balance;
  final VoidCallback onSettle;
  final VoidCallback onAddExpense;

  const _YourPosition({
    required this.balance,
    required this.onSettle,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final settled = balance.abs() < 0.01;
    final owed = balance > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: settled
            ? AppColors.bgPrimary
            : owed
                ? AppColors.successLight
                : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: settled
              ? AppColors.border
              : owed
                  ? AppColors.successBorder
                  : AppColors.primaryBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverlineLabel(
            settled
                ? 'Your balance'
                : owed
                    ? "You're owed"
                    : 'You owe',
            color: settled
                ? AppColors.muted
                : owed
                    ? const Color(0xFF4F8A68)
                    : const Color(0xFFC2607C),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(balance.abs()),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.3,
                height: 1.05,
                color: settled
                    ? AppColors.textPrimary
                    : owed
                        ? AppColors.success
                        : AppColors.negative,
              ),
            ),
          ),
          if (settled) ...[
            const SizedBox(height: 4),
            Text('You are all square in this group',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: PSButton(
                  label: 'Add expense',
                  size: PSButtonSize.medium,
                  onPressed: onAddExpense,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: PSButton(
                  label: 'Settle up',
                  variant: PSButtonVariant.secondary,
                  size: PSButtonSize.medium,
                  onPressed: onSettle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The per-member spending guard, when the group has one.
class _LimitCard extends StatelessWidget {
  final GroupModel group;
  final GroupBalances balances;
  final String currentUserId;

  const _LimitCard({
    required this.group,
    required this.balances,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    MemberBalance? mine;
    for (final b in balances.balances) {
      if (b.userId == currentUserId) mine = b;
    }
    final overLimit = balances.balances.where((b) => b.limitExceeded).toList();

    return PSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded,
                  size: 17, color: AppColors.primaryAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Balance limit',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(
                '${formatMoney(group.balanceLimit)} per member',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'New expenses are blocked once a member would owe more than this.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          BalanceLimitBar(
            used: mine?.limitUsed ?? 0,
            limit: group.balanceLimit,
            currencySymbol: group.currencySymbol,
            label: 'Your share of the limit',
          ),
          if (overLimit.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.negative),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      overLimit.length == 1
                          ? '${overLimit.first.name} is over the limit'
                          : '${overLimit.length} members are over the limit',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every member and where they stand.
class _MemberBalanceList extends StatelessWidget {
  final GroupModel group;
  final GroupBalances balances;
  final String currentUserId;

  const _MemberBalanceList({
    required this.group,
    required this.balances,
    required this.currentUserId,
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        children: [
          for (var i = 0; i < group.members.length; i++) ...[
            Builder(builder: (context) {
              final member = group.members[i];
              final balance = balances.balanceFor(member.id);
              final settled = balance.abs() < 0.01;
              final isSelf = member.id == currentUserId;

              return BalanceRow(
                name: isSelf ? '${member.name} (you)' : member.name,
                label: settled
                    ? 'settled'
                    : balance > 0
                        ? 'gets back'
                        : 'owes',
                amount: settled ? '—' : formatMoney(balance.abs()),
                amountColor: settled
                    ? AppColors.muted
                    : balance > 0
                        ? AppColors.success
                        : AppColors.negative,
              );
            }),
            if (i != group.members.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 54, right: AppSpacing.xs),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

/// The simplified set of payments that would clear the group.
class _SettlementList extends StatelessWidget {
  final GroupBalances balances;
  final String currentUserId;

  const _SettlementList({
    required this.balances,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = balances.suggestions;

    if (suggestions.isEmpty) {
      return PSCard(
        color: AppColors.successLight,
        borderColor: AppColors.successBorder,
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 19, color: AppColors.success),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Everyone is settled up in this group.',
                style: const TextStyle(
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

    return Column(
      children: [
        for (final s in suggestions) ...[
          _SettlementRow(suggestion: s, currentUserId: currentUserId),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _SettlementRow extends StatelessWidget {
  final SettlementSuggestion suggestion;
  final String currentUserId;

  const _SettlementRow({
    required this.suggestion,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final iPay = suggestion.fromId == currentUserId;
    final iReceive = suggestion.toId == currentUserId;
    final involvesMe = iPay || iReceive;

    return PSCard(
      color: involvesMe ? AppColors.primarySurface : AppColors.bgPrimary,
      borderColor: involvesMe ? AppColors.primaryBorder : AppColors.border,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          AvatarWidget.forName(suggestion.fromName, size: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded,
                size: 15,
                color: involvesMe ? AppColors.primaryAccent : AppColors.muted),
          ),
          AvatarWidget.forName(suggestion.toName, size: 32),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: iPay ? 'You' : suggestion.fromName),
                  const TextSpan(
                    text: ' pay ',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextSpan(text: iReceive ? 'you' : suggestion.toName),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            formatMoney(suggestion.amount, decimals: true),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: iReceive
                  ? AppColors.success
                  : iPay
                      ? AppColors.negative
                      : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
