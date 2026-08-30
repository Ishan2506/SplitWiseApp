import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import 'create_group_screen.dart';
import 'group_members_screen.dart';
import 'group_widgets.dart';
import 'invite_screen.dart';

/// One group: its photo and description, who is in it, where everyone stands,
/// and how much of the balance limit is left.
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
        backgroundColor: GroupColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this group?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Every expense and settlement in "${group.name}" will be deleted too. '
          'This cannot be undone.',
          style: const TextStyle(color: GroupColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel',
                style: TextStyle(color: GroupColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: GroupColors.negative),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result =
        await context.read<GroupProvider>().deleteGroup(group.id);
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
        backgroundColor: GroupColors.background,
        appBar: AppBar(
          backgroundColor: GroupColors.surface,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text('This group is no longer available',
              style: TextStyle(color: GroupColors.muted)),
        ),
      );
    }

    final currentUserId = context.read<StateManager>().currentUserId;
    final isCreator = group.isCreatedBy(currentUserId);
    final balances = provider.balancesFor(group.id);
    final userBalance = balances.balanceFor(currentUserId);
    final symbol = group.currencySymbol;

    return Scaffold(
      backgroundColor: GroupColors.background,
      appBar: AppBar(
        backgroundColor: GroupColors.surface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(group.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Invite people',
            icon: const Icon(Icons.person_add_alt_1, color: GroupColors.accent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => InviteScreen(groupId: group.id)),
            ),
          ),
          if (isCreator)
            PopupMenuButton<String>(
              color: GroupColors.surface,
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateGroupScreen(existing: group),
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
                      Icon(Icons.edit, size: 18, color: GroupColors.accent),
                      SizedBox(width: 10),
                      Text('Edit group',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: GroupColors.negative),
                      SizedBox(width: 10),
                      Text('Delete group',
                          style: TextStyle(color: GroupColors.negative)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: GroupColors.primary,
        backgroundColor: GroupColors.surface,
        onRefresh: () => provider.refreshGroup(group.id),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildHeader(group),
            const SizedBox(height: 20),
            _buildBalanceCard(group, userBalance, symbol),
            if (group.hasBalanceLimit) ...[
              const SizedBox(height: 14),
              _buildLimitCard(group, balances, currentUserId, symbol),
            ],
            const SizedBox(height: 20),
            _buildMembersStrip(group, balances, currentUserId, symbol),
            const SizedBox(height: 20),
            _buildSettlements(group, balances, currentUserId, symbol),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(GroupModel group) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GroupAvatar(group: group, size: 64, radius: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                GroupTypeChip(type: group.type),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    group.description,
                    style: const TextStyle(
                        color: GroupColors.muted, fontSize: 13, height: 1.4),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 14, color: GroupColors.muted),
                    const SizedBox(width: 5),
                    Text(
                      '${group.members.length} '
                      '${group.members.length == 1 ? 'member' : 'members'}',
                      style: const TextStyle(
                          color: GroupColors.muted, fontSize: 12),
                    ),
                    if (group.createdByName.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Text('•',
                          style: TextStyle(color: GroupColors.muted)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'by ${group.createdByName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: GroupColors.muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
      GroupModel group, double userBalance, String symbol) {
    final settled = userBalance.abs() < 0.01;
    final color = settled
        ? GroupColors.muted
        : userBalance > 0
            ? GroupColors.positive
            : GroupColors.negative;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            settled
                ? Icons.check_circle_outline
                : userBalance > 0
                    ? Icons.trending_up
                    : Icons.trending_down,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your balance in this group',
                    style:
                        TextStyle(color: GroupColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  settled
                      ? 'All settled up'
                      : userBalance > 0
                          ? 'You are owed $symbol${userBalance.toStringAsFixed(2)}'
                          : 'You owe $symbol${userBalance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitCard(GroupModel group, GroupBalances balances,
      String currentUserId, String symbol) {
    MemberBalance? mine;
    for (final b in balances.balances) {
      if (b.userId == currentUserId) mine = b;
    }

    final overLimit =
        balances.balances.where((b) => b.limitExceeded).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: GroupColors.accent),
              const SizedBox(width: 8),
              const Text(
                'Group balance limit',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '$symbol${group.balanceLimit.toStringAsFixed(0)} per member',
                style: const TextStyle(
                    color: GroupColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'New expenses are blocked once a member would owe more than this.',
            style: TextStyle(color: GroupColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          BalanceLimitBar(
            used: mine?.limitUsed ?? 0,
            limit: group.balanceLimit,
            currencySymbol: symbol,
            label: 'Your share of the limit',
          ),
          if (overLimit.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GroupColors.negative.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: GroupColors.negative),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      overLimit.length == 1
                          ? '${overLimit.first.name} is over the limit'
                          : '${overLimit.length} members are over the limit',
                      style: const TextStyle(
                          color: GroupColors.negative, fontSize: 12),
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

  Widget _buildMembersStrip(GroupModel group, GroupBalances balances,
      String currentUserId, String symbol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Members',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupMembersScreen(groupId: group.id),
                ),
              ),
              child: const Text('Manage',
                  style: TextStyle(color: GroupColors.accent, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: group.members.length,
            itemBuilder: (_, index) {
              final member = group.members[index];
              final balance = balances.balanceFor(member.id);
              final isSelf = member.id == currentUserId;
              final settled = balance.abs() < 0.01;

              return Container(
                width: 92,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: GroupColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MemberAvatar(member: member, radius: 18),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        isSelf ? 'You' : member.name.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      settled
                          ? 'settled'
                          : balance > 0
                              ? '+$symbol${balance.abs().toStringAsFixed(0)}'
                              : '-$symbol${balance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        color: settled
                            ? GroupColors.muted
                            : balance > 0
                                ? GroupColors.positive
                                : GroupColors.negative,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettlements(GroupModel group, GroupBalances balances,
      String currentUserId, String symbol) {
    final suggestions = balances.suggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Who pays whom',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (suggestions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GroupColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: GroupColors.positive, size: 20),
                SizedBox(width: 12),
                Text('Everyone is settled up in this group.',
                    style: TextStyle(
                        color: GroupColors.muted, fontSize: 13)),
              ],
            ),
          )
        else
          ...suggestions.map((s) {
            final involvesMe =
                s.fromId == currentUserId || s.toId == currentUserId;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: GroupColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: involvesMe
                    ? Border.all(
                        color: GroupColors.primary.withValues(alpha: 0.5))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: s.fromId == currentUserId
                                ? 'You'
                                : s.fromName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text: '  →  ',
                            style: TextStyle(color: GroupColors.muted),
                          ),
                          TextSpan(
                            text:
                                s.toId == currentUserId ? 'You' : s.toName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    '$symbol${s.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: s.toId == currentUserId
                          ? GroupColors.positive
                          : GroupColors.negative,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
