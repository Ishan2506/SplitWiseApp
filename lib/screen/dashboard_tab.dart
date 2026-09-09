import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/group_model.dart';
import '../state/state_manager.dart';
import '../state/group_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/common_widgets.dart';
import 'groups/group_detail_screen.dart';
import 'groups/create_group_screen.dart';
import 'groups/join_group_screen.dart';

/// Home. Answers "where do I stand?" in the first screenful — one headline
/// balance, then the owe / owed split, then the groups behind those numbers.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GroupProvider>().loadGroups();
      }
    });
  }

  Future<void> _refresh() =>
      context.read<GroupProvider>().loadGroups(silent: true);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final provider = context.watch<GroupProvider>();

    final userId = state.currentUserId;
    final owed = state.getUserTotalOwed(userId);
    final owe = state.getUserTotalOwe(userId);
    final net = owed - owe;

    final firstName = state.currentUser.name.trim().split(' ').first;
    final groups = provider.groups;
    final loading = provider.isLoading && !provider.hasLoadedOnce;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryAccent,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Hi $firstName',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your balance',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BalanceSummary(net: net, owe: owe, owed: owed),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: PageContainer(
              child: SectionHeader(
                title: 'Your groups',
                subtitle: groups.isEmpty
                    ? null
                    : '${groups.length} active',
                actionLabel: groups.isEmpty ? null : 'New group',
                onAction: groups.isEmpty ? null : () => _createGroup(context),
              ),
            ),
          ),

          if (loading)
            SliverToBoxAdapter(
              child: PageContainer(
                child: Column(
                  children: const [
                    SkeletonCard(),
                    SizedBox(height: AppSpacing.xs),
                    SkeletonCard(),
                    SizedBox(height: AppSpacing.xs),
                    SkeletonCard(),
                  ],
                ),
              ),
            )
          else if (provider.error != null && groups.isEmpty)
            SliverToBoxAdapter(
              child: PageContainer(
                child: _ErrorPanel(
                  message: provider.error!,
                  onRetry: () => provider.loadGroups(),
                ),
              ),
            )
          else if (groups.isEmpty)
            SliverToBoxAdapter(
              child: PageContainer(
                child: PSCard(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg, horizontal: AppSpacing.md),
                  child: Column(
                    children: [
                      const EmptyStateWidget(
                        iconData: Icons.groups_outlined,
                        title: 'No groups yet',
                        subtitle:
                            'Create a group to start splitting bills, or join '
                            'one with an invite code.',
                        compact: true,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: PSButton(
                              label: 'Create group',
                              size: PSButtonSize.medium,
                              onPressed: () => _createGroup(context),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: PSButton(
                              label: 'Join',
                              variant: PSButtonVariant.secondary,
                              size: PSButtonSize.medium,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const JoinGroupScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: PageContainer(
                child: _GroupGrid(groups: groups, userId: userId),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  void _createGroup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
  }
}

/// The headline figure plus the two-column owe / owed breakdown.
class _BalanceSummary extends StatelessWidget {
  final double net;
  final double owe;
  final double owed;

  const _BalanceSummary({
    required this.net,
    required this.owe,
    required this.owed,
  });

  @override
  Widget build(BuildContext context) {
    final settled = net.abs() < 0.01;
    final positive = net > 0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OverlineLabel('Across all groups',
                  color: Color(0xFF8B8B93)),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  settled ? formatMoney(0) : formatMoney(net.abs()),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.6,
                    height: 1.05,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: settled
                          ? const Color(0xFF8B8B93)
                          : positive
                              ? const Color(0xFF4ADE80)
                              : AppColors.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      settled
                          ? 'Everything is settled'
                          : positive
                              ? 'you are owed overall'
                              : 'you owe overall',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB8B0BD),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'You owe',
                value: formatMoney(owe),
                valueColor: AppColors.negative,
                background: AppColors.negativeLight,
                borderColor: AppColors.negativeBorder,
                labelColor: const Color(0xFFC2607C),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: StatTile(
                label: "You're owed",
                value: formatMoney(owed),
                valueColor: AppColors.success,
                background: AppColors.successLight,
                borderColor: AppColors.successBorder,
                labelColor: const Color(0xFF4F8A68),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Groups as a single column on phones, widening to a grid on larger screens.
class _GroupGrid extends StatelessWidget {
  final List<GroupModel> groups;
  final String userId;

  const _GroupGrid({required this.groups, required this.userId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final columns = AppBreakpoints.gridColumns(context);

    final cards = [
      for (final group in groups)
        _GroupTile(
          group: group,
          balance: provider.userBalanceIn(group.id, userId),
        ),
    ];

    if (columns == 1) {
      return Column(
        children: [
          for (final card in cards) ...[
            card,
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      );
    }

    // A wrap keeps rows tight without forcing every card to a fixed height.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.xs;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final double balance;

  const _GroupTile({required this.group, required this.balance});

  @override
  Widget build(BuildContext context) {
    final settled = balance.abs() < 0.01;
    final owed = balance > 0;

    return GroupCard(
      groupName: group.name,
      description:
          '${group.type.label} · ${group.members.length} member${group.members.length == 1 ? '' : 's'}',
      icon: group.type.icon,
      iconColor: group.type.color,
      amount: formatMoney(balance.abs()),
      amountLabel: owed ? "You're owed" : 'You owe',
      amountColor: owed ? AppColors.success : AppColors.negative,
      isSettled: settled,
      memberNames: group.members.map((m) => m.name).toList(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: group.id),
        ),
      ),
    );
  }
}

/// Shown when the group list could not be loaded at all.
class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return PSCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.cloud_off_rounded,
                size: 21, color: AppColors.primaryAccent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text("Couldn't load your groups",
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          PSButton(
            label: 'Try again',
            size: PSButtonSize.medium,
            expand: false,
            variant: PSButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
