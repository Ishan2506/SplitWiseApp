import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../network/api_service.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import 'group_widgets.dart';
import 'invite_screen.dart';

/// Lists who is in a group, what each of them owes, and how much of the
/// balance limit they have used. The creator can add and remove people here;
/// everyone else can leave.
class GroupMembersScreen extends StatefulWidget {
  final String groupId;

  const GroupMembersScreen({super.key, required this.groupId});

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  bool _busy = false;

  Future<void> _showAddMemberSheet(GroupModel group) async {
    final result = await ApiService.searchUsers();
    if (!mounted) return;

    final currentUserId = context.read<StateManager>().currentUserId;
    final candidates = result['success'] == true
        ? (result['users'] as List<GroupMember>)
            .where((u) => u.id != currentUserId && !group.hasMember(u.id))
            .toList()
        : <GroupMember>[];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: GroupColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GroupColors.surfaceAlt,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add a member',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: candidates.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_search,
                              size: 40, color: GroupColors.muted),
                          const SizedBox(height: 14),
                          const Text(
                            'Everyone on the app is already in this group.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: GroupColors.muted, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      InviteScreen(groupId: group.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code, size: 18),
                            label: const Text('Invite with a link or QR code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GroupColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: candidates.length,
                      itemBuilder: (_, index) {
                        final person = candidates[index];
                        return ListTile(
                          leading: MemberAvatar(member: person),
                          title: Text(person.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                          subtitle: person.email != null
                              ? Text(person.email!,
                                  style: const TextStyle(
                                      color: GroupColors.muted, fontSize: 11))
                              : null,
                          trailing: const Icon(Icons.add_circle_outline,
                              color: GroupColors.accent),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _addMember(group, person);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMember(GroupModel group, GroupMember person) async {
    setState(() => _busy = true);
    final result = await context
        .read<GroupProvider>()
        .addMember(groupId: group.id, userId: person.id);
    if (!mounted) return;
    setState(() => _busy = false);

    showGroupSnack(
      context,
      result['success'] == true
          ? '${person.name} was added'
          : result['message'] ?? 'Could not add ${person.name}',
      success: result['success'] == true,
    );
  }

  Future<void> _removeMember(GroupModel group, GroupMember member) async {
    final currentUserId = context.read<StateManager>().currentUserId;
    final leaving = member.id == currentUserId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GroupColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          leaving ? 'Leave this group?' : 'Remove ${member.name}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          leaving
              ? 'You can rejoin later with an invite link or QR code.'
              : '${member.name} will lose access to this group.',
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
            child: Text(leaving ? 'Leave' : 'Remove',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await context.read<GroupProvider>().removeMember(
          groupId: group.id,
          userId: member.id,
          currentUserId: currentUserId,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result['success'] == true) {
      if (leaving) {
        // The group is gone from our list, so close both this screen and the
        // group detail behind it.
        Navigator.of(context)
          ..pop()
          ..pop();
        showGroupSnack(context, 'You left "${group.name}"');
      } else {
        showGroupSnack(context, '${member.name} was removed');
      }
    } else {
      showGroupSnack(context, result['message'] ?? 'Could not remove them',
          success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final group = provider.groupById(widget.groupId);

    if (group == null) {
      return const Scaffold(
        backgroundColor: GroupColors.background,
        body: Center(
          child: Text('This group is no longer available',
              style: TextStyle(color: GroupColors.muted)),
        ),
      );
    }

    final balances = provider.balancesFor(group.id);
    final currentUserId = context.read<StateManager>().currentUserId;
    final isCreator = group.isCreatedBy(currentUserId);

    return Scaffold(
      backgroundColor: GroupColors.background,
      appBar: AppBar(
        backgroundColor: GroupColors.surface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Members (${group.members.length})',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Invite',
            icon: const Icon(Icons.person_add_alt_1, color: GroupColors.accent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => InviteScreen(groupId: group.id)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              ...group.members.map(
                (member) => _buildMemberTile(
                  group: group,
                  member: member,
                  balances: balances,
                  currentUserId: currentUserId,
                  isCreator: isCreator,
                ),
              ),
              if (group.pendingInvites.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Pending invites (${group.pendingInvites.length})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...group.pendingInvites.map(
                  (invite) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GroupColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: GroupColors.surfaceAlt,
                          child: Icon(Icons.hourglass_empty,
                              size: 16, color: GroupColors.warning),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(invite.contact,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              const Text('Invited — not joined yet',
                                  style: TextStyle(
                                      color: GroupColors.muted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _showAddMemberSheet(group),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add a member'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GroupColors.accent,
                  side: const BorderSide(color: GroupColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: GroupColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberTile({
    required GroupModel group,
    required GroupMember member,
    required GroupBalances balances,
    required String currentUserId,
    required bool isCreator,
  }) {
    final isSelf = member.id == currentUserId;
    final isGroupCreator = group.isCreatedBy(member.id);
    final balance = balances.balanceFor(member.id);
    final symbol = group.currencySymbol;

    // The creator can remove anyone but themselves; anyone else can leave.
    final canRemove =
        !isGroupCreator && (isCreator || isSelf);

    MemberBalance? detail;
    for (final b in balances.balances) {
      if (b.userId == member.id) detail = b;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              MemberAvatar(member: member, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isSelf ? 'You' : member.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isGroupCreator) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: GroupColors.primary
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                  color: GroupColors.accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (member.email != null && member.email!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        member.email!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: GroupColors.muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balance.abs() < 0.01
                        ? 'settled'
                        : balance > 0
                            ? 'is owed'
                            : 'owes',
                    style: TextStyle(
                      color: balance.abs() < 0.01
                          ? GroupColors.muted
                          : balance > 0
                              ? GroupColors.positive
                              : GroupColors.negative,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$symbol${balance.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: balance.abs() < 0.01
                          ? GroupColors.muted
                          : balance > 0
                              ? GroupColors.positive
                              : GroupColors.negative,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (canRemove)
                IconButton(
                  tooltip: isSelf ? 'Leave group' : 'Remove member',
                  icon: Icon(
                    isSelf ? Icons.logout : Icons.person_remove_outlined,
                    size: 18,
                    color: GroupColors.negative,
                  ),
                  onPressed:
                      _busy ? null : () => _removeMember(group, member),
                ),
            ],
          ),
          // Show how close this member is to the group's limit.
          if (group.hasBalanceLimit && detail != null && balance < 0) ...[
            const SizedBox(height: 12),
            BalanceLimitBar(
              used: detail.limitUsed,
              limit: group.balanceLimit,
              currencySymbol: symbol,
              label: isSelf ? 'Your limit' : 'Limit used',
            ),
          ],
        ],
      ),
    );
  }
}
