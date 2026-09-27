import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/group_model.dart';
import '../models/models.dart';
import '../state/group_provider.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/common_widgets.dart';

/// The user's own activity — what *they* did, across every group or one at
/// a time, grouped by the day it happened. Backed by a real endpoint (see
/// StateManager.loadMyActivity), so unlike the old local-only feed this
/// survives closing and reopening the app.
class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  /// null means "All groups".
  String? _selectedGroupId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await context
        .read<StateManager>()
        .loadMyActivity(groupId: _selectedGroupId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result['success'] == true
          ? null
          : (result['message'] ?? 'Could not load activity').toString();
    });
  }

  void _selectGroup(String? groupId) {
    if (groupId == _selectedGroupId) return;
    setState(() => _selectedGroupId = groupId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final groups = context.watch<GroupProvider>().groups;
    final activity = state.remoteActivity;
    final unread = activity.where((e) => !e.read).length;

    return RefreshIndicator(
      color: AppColors.primaryAccent,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageContainer(
              child: Padding(
                padding:
                    const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Activity',
                              style: Theme.of(context).textTheme.displaySmall),
                          const SizedBox(height: 2),
                          Text(
                            unread == 0
                                ? 'You are all caught up'
                                : '$unread new update${unread == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (unread > 0)
                      TextButton(
                        onPressed: () => state.markAllActivityRead(),
                        child: const Text('Mark all read'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _GroupFilterRow(
              groups: groups,
              selectedGroupId: _selectedGroupId,
              onSelect: _selectGroup,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          // No local spinner here — the global loading overlay (shown for
          // every in-flight API call, see main.dart) already covers this.
          // While loading we simply show nothing yet, so the empty/error
          // states below don't flash before the real data arrives.
          if (_loading)
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                iconData: Icons.error_outline_rounded,
                title: 'Could not load activity',
                subtitle: _error!,
                buttonLabel: 'Retry',
                onButtonPressed: _load,
              ),
            )
          else if (activity.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                iconData: Icons.history_rounded,
                title: 'Nothing here yet',
                subtitle:
                    'Things you do — adding an expense, creating a group, '
                    'settling up — show up here.',
              ),
            )
          else
            SliverToBoxAdapter(
              child: PageContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in _groupByDay(activity)) ...[
                      _DayHeader(label: group.label),
                      const SizedBox(height: AppSpacing.xs),
                      for (final entry in group.entries) ...[
                        _ActivityCard(
                          entry: entry,
                          onTap: entry.read
                              ? null
                              : () => state.markActivityRead(entry.id),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_DayGroup> _groupByDay(List<ActivityEntry> activity) {
    final groups = <String, List<ActivityEntry>>{};
    for (final entry in activity) {
      groups.putIfAbsent(_dayLabel(entry.createdAt), () => []).add(entry);
    }
    return [
      for (final label in groups.keys) _DayGroup(label, groups[label]!),
    ];
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _DayGroup {
  final String label;
  final List<ActivityEntry> entries;
  const _DayGroup(this.label, this.entries);
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// "All" plus every group the user currently belongs to — matching what
/// they can actually filter by, not groups they have since left.
class _GroupFilterRow extends StatelessWidget {
  final List<GroupModel> groups;
  final String? selectedGroupId;
  final ValueChanged<String?> onSelect;

  const _GroupFilterRow({
    required this.groups,
    required this.selectedGroupId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
            horizontal: AppBreakpoints.pagePadding(context)),
        itemCount: groups.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _FilterChip(
              label: 'All',
              selected: selectedGroupId == null,
              onTap: () => onSelect(null),
            );
          }
          final group = groups[i - 1];
          return _FilterChip(
            label: group.name,
            selected: selectedGroupId == group.id,
            onTap: () => onSelect(group.id),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityEntry entry;
  final VoidCallback? onTap;

  const _ActivityCard({required this.entry, this.onTap});

  ({IconData icon, Color fg, Color bg}) get _visual => switch (entry.iconKey) {
        'group' => (
            icon: Icons.groups_rounded,
            fg: AppColors.primaryAccent,
            bg: AppColors.primaryLight,
          ),
        'member' => (
            icon: Icons.person_add_alt_1_rounded,
            fg: AppColors.textSecondary,
            bg: AppColors.bgSubtle,
          ),
        'expense' => (
            icon: Icons.receipt_long_rounded,
            fg: AppColors.primaryAccent,
            bg: AppColors.primaryLight,
          ),
        'settlement' => (
            icon: Icons.check_rounded,
            fg: AppColors.success,
            bg: AppColors.successLight,
          ),
        _ => (
            icon: Icons.circle_notifications_outlined,
            fg: AppColors.textSecondary,
            bg: AppColors.bgSubtle,
          ),
      };

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final v = _visual;
    final unread = !entry.read;

    return PSCard(
      onTap: onTap,
      color: unread ? AppColors.primarySurface : AppColors.bgPrimary,
      borderColor: unread ? AppColors.primaryBorder : AppColors.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: v.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(v.icon, size: 18, color: v.fg),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.groupName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: AppSpacing.xxs),
              decoration: const BoxDecoration(
                color: AppColors.primaryAccent,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            _time(entry.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
