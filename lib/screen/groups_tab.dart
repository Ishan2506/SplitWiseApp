import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/group_model.dart';
import '../state/group_provider.dart';
import '../state/state_manager.dart';
import 'groups/create_group_screen.dart';
import 'groups/group_detail_screen.dart';
import 'groups/group_widgets.dart';
import 'groups/join_group_screen.dart';
import 'groups/scan_qr_screen.dart';

/// The Groups tab: every group the user belongs to, filterable by type, with
/// the two ways in — create one, or join someone else's.
class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  /// null means "All".
  GroupType? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GroupProvider>();
      if (!provider.hasLoadedOnce) provider.loadGroups();
    });
  }

  Future<void> _scanToJoin() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanQrScreen()),
    );
    if (code == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JoinGroupScreen(inviteCode: code)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final all = provider.groups;
    final groups =
        _filter == null ? all : all.where((g) => g.type == _filter).toList();

    return Scaffold(
      backgroundColor: GroupColors.background,
      body: RefreshIndicator(
        color: GroupColors.primary,
        backgroundColor: GroupColors.surface,
        onRefresh: () => provider.loadGroups(silent: true),
        child: Column(
          children: [
            _buildHeader(all.length),
            if (all.isNotEmpty) _buildFilters(all),
            Expanded(
              child: _buildBody(provider, groups),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int totalGroups) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Your Groups',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          IconButton(
            tooltip: 'Scan a QR code to join',
            onPressed: _scanToJoin,
            icon: const Icon(Icons.qr_code_scanner, color: GroupColors.accent),
          ),
          IconButton(
            tooltip: 'Join with a code',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JoinGroupScreen()),
            ),
            icon: const Icon(Icons.group_add, color: GroupColors.accent),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<GroupModel> all) {
    // Only offer a filter for types that actually have groups.
    final present = GroupType.values
        .where((t) => all.any((g) => g.type == t))
        .toList();
    if (present.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _filterChip(label: 'All', selected: _filter == null, color: GroupColors.accent,
              onTap: () => setState(() => _filter = null)),
          ...present.map(
            (type) => _filterChip(
              label: type.label,
              icon: type.icon,
              color: type.color,
              selected: _filter == type,
              onTap: () => setState(
                  () => _filter = _filter == type ? null : type),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : GroupColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : GroupColors.surfaceAlt,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14,
                    color: selected ? color : GroupColors.muted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : GroupColors.muted,
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(GroupProvider provider, List<GroupModel> groups) {
    if (provider.isLoading && !provider.hasLoadedOnce) {
      return const Center(
        child: CircularProgressIndicator(color: GroupColors.primary),
      );
    }

    if (provider.error != null && provider.groups.isEmpty) {
      return _buildMessage(
        icon: Icons.cloud_off,
        title: 'Could not load your groups',
        message: provider.error!,
        actionLabel: 'Try again',
        onAction: () => provider.loadGroups(),
      );
    }

    if (groups.isEmpty) {
      // Distinguish "no groups at all" from "none of this type".
      final filtered = provider.groups.isNotEmpty;
      return _buildMessage(
        icon: filtered ? Icons.filter_alt_off : Icons.groups_outlined,
        title: filtered
            ? 'No ${_filter?.label.toLowerCase()} groups'
            : 'No groups yet',
        message: filtered
            ? 'Try a different filter, or create one.'
            : 'Create a group to start splitting, or join one with a QR code '
                'or invite link.',
        actionLabel: filtered ? 'Show all' : 'Create a group',
        onAction: () {
          if (filtered) {
            setState(() => _filter = null);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
            );
          }
        },
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: groups.length,
      itemBuilder: (_, index) => _buildGroupCard(groups[index], provider),
    );
  }

  Widget _buildGroupCard(GroupModel group, GroupProvider provider) {
    final currentUserId = context.read<StateManager>().currentUserId;
    final balances = provider.balancesFor(group.id);
    final userBalance = balances.balanceFor(currentUserId);
    final settled = userBalance.abs() < 0.01;
    final symbol = group.currencySymbol;

    MemberBalance? mine;
    for (final b in balances.balances) {
      if (b.userId == currentUserId) mine = b;
    }

    return Card(
      color: GroupColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(groupId: group.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GroupAvatar(group: group, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            GroupTypeChip(type: group.type, compact: true),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${group.members.length} '
                                '${group.members.length == 1 ? 'member' : 'members'}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: GroupColors.muted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (group.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            group.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: GroupColors.muted,
                                fontSize: 12,
                                height: 1.3),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        settled
                            ? 'settled'
                            : userBalance > 0
                                ? 'you are owed'
                                : 'you owe',
                        style: TextStyle(
                          color: settled
                              ? GroupColors.muted
                              : userBalance > 0
                                  ? GroupColors.positive
                                  : GroupColors.negative,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$symbol${userBalance.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: settled
                              ? GroupColors.muted
                              : userBalance > 0
                                  ? GroupColors.positive
                                  : GroupColors.negative,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Only worth the space when a limit is set and being used.
              if (group.hasBalanceLimit && (mine?.limitUsed ?? 0) > 0) ...[
                const SizedBox(height: 14),
                BalanceLimitBar(
                  used: mine!.limitUsed,
                  limit: group.balanceLimit,
                  currencySymbol: symbol,
                  label: 'Your balance limit',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    // Wrapped in a scroll view so pull-to-refresh still works when empty.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 56, color: GroupColors.surfaceAlt),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: GroupColors.muted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GroupColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(actionLabel,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
