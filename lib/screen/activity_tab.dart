import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/common_widgets.dart';

/// The activity feed. Unread items carry a tinted background and a dot so the
/// eye lands on what is new before anything else.
class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final notifications = state.notifications;
    final unread = state.unreadNotificationCount;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageContainer(
            child: Padding(
              padding: const EdgeInsets.only(
                  top: AppSpacing.xs, bottom: AppSpacing.md),
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
                      onPressed: () {
                        state.markAllNotificationsRead();
                        showAppSnack(context, 'All caught up');
                      },
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (notifications.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              iconData: Icons.notifications_none_rounded,
              title: 'Nothing here yet',
              subtitle:
                  'When someone adds an expense or settles up, it shows up here.',
            ),
          )
        else
          SliverToBoxAdapter(
            child: PageContainer(
              child: Column(
                children: [
                  for (final n in notifications) ...[
                    _ActivityCard(
                      notification: n,
                      onTap: () => state.markNotificationRead(n.id),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _ActivityCard({required this.notification, required this.onTap});

  ({IconData icon, Color fg, Color bg}) get _visual =>
      switch (notification.kind) {
        ActivityKind.expenseAdded => (
            icon: Icons.add_rounded,
            fg: AppColors.primaryAccent,
            bg: AppColors.primaryLight,
          ),
        ActivityKind.settled => (
            icon: Icons.check_rounded,
            fg: AppColors.success,
            bg: AppColors.successLight,
          ),
        ActivityKind.edited => (
            icon: Icons.edit_outlined,
            fg: AppColors.textSecondary,
            bg: AppColors.bgSubtle,
          ),
        ActivityKind.memberJoined => (
            icon: Icons.person_add_alt_1_rounded,
            fg: AppColors.textSecondary,
            bg: AppColors.bgSubtle,
          ),
        ActivityKind.groupCreated => (
            icon: Icons.groups_rounded,
            fg: AppColors.textSecondary,
            bg: AppColors.bgSubtle,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final v = _visual;
    final unread = !notification.isRead;

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
                  notification.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  notification.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                OverlineLabel(notification.relativeTime),
              ],
            ),
          ),
          if (unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, left: AppSpacing.xs),
              decoration: const BoxDecoration(
                color: AppColors.primaryAccent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
