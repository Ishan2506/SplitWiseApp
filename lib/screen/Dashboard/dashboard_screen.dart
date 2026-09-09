import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard_tab.dart';
import '../activity_tab.dart';
import '../history_tab.dart';
import '../profile/profile_screen.dart';
import '../groups/create_group_screen.dart';
import '../add_expense_screen.dart';

/// The app shell: brand bar on top, four tabs plus a raised "add" action in a
/// dark bar along the bottom, matching the reference navigation.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    _NavItem('Groups', Icons.groups_rounded, Icons.groups_outlined),
    _NavItem('Activity', Icons.notifications_rounded,
        Icons.notifications_none_rounded),
    _NavItem('History', Icons.receipt_long_rounded,
        Icons.receipt_long_outlined),
    _NavItem('Profile', Icons.person_rounded, Icons.person_outline_rounded),
  ];

  Widget _pageFor(int index) => switch (index) {
        0 => const DashboardTab(),
        1 => const ActivityTab(),
        2 => const HistoryTab(),
        _ => const ProfileScreen(embedded: true),
      };

  Future<void> _openAddSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _QuickAddSheet(),
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case 'expense':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
        );
      case 'group':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        );
    }
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave PaisaSplit?'),
        content: const Text('Your groups and balances will be here when you '
            'come back.'),
        actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Stay'),
          ),
          PSButton(
            label: 'Exit',
            expand: false,
            size: PSButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final unread = state.unreadNotificationCount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Any tab other than the first pops back to Groups before exiting.
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldExit = await _confirmExit();
        if (!context.mounted || !shouldExit) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: _currentIndex == 3
            ? null
            : AppBar(
                automaticallyImplyLeading: false,
                titleSpacing: AppBreakpoints.pagePadding(context),
                title: const _BrandMark(),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.person_outline_rounded),
                    tooltip: 'Profile',
                    onPressed: () => setState(() => _currentIndex = 3),
                  ),
                  SizedBox(width: AppBreakpoints.pagePadding(context) - 8),
                ],
              ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: _pageFor(_currentIndex),
        ),
        bottomNavigationBar: _BottomBar(
          items: _tabs,
          currentIndex: _currentIndex,
          unreadCount: unread,
          onSelected: (i) => setState(() => _currentIndex = i),
          onAdd: _openAddSheet,
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData active;
  final IconData inactive;
  const _NavItem(this.label, this.active, this.inactive);
}

/// Wordmark shown in the app bar.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            '₹',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Text(
          'PaisaSplit',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Dark bottom bar with a raised centre action, from the reference design.
class _BottomBar extends StatelessWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  const _BottomBar({
    required this.items,
    required this.currentIndex,
    required this.unreadCount,
    required this.onSelected,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: bottomInset > 0 ? bottomInset : AppSpacing.sm,
        left: AppSpacing.xs,
        right: AppSpacing.xs,
      ),
      child: Row(
        children: [
          _tab(0),
          _tab(1),
          Expanded(
            child: Center(
              child: Tooltip(
                message: 'Add expense or group',
                child: Material(
                  color: AppColors.primaryAccent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onAdd,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.add_rounded,
                          color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _tab(2),
          _tab(3),
        ],
      ),
    );
  }

  Widget _tab(int index) {
    final item = items[index];
    final isActive = currentIndex == index;
    final showBadge = index == 1 && unreadCount > 0;

    return Expanded(
      child: Semantics(
        selected: isActive,
        button: true,
        label: item.label,
        child: InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isActive ? item.active : item.inactive,
                      size: 22,
                      color: isActive
                          ? Colors.white
                          : const Color(0xFF8B8B93),
                    ),
                    if (showBadge)
                      Positioned(
                        right: -5,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 15),
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.ink, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color:
                        isActive ? Colors.white : const Color(0xFF8B8B93),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet offering the two things a user can create.
class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs, AppSpacing.xxs, 0, AppSpacing.sm),
              child: Text('Add to PaisaSplit',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            _option(
              context,
              icon: Icons.receipt_long_rounded,
              title: 'Add an expense',
              subtitle: 'Split a bill with a group',
              value: 'expense',
            ),
            const SizedBox(height: AppSpacing.xs),
            _option(
              context,
              icon: Icons.group_add_rounded,
              title: 'Create a group',
              subtitle: 'Start splitting with new people',
              value: 'group',
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return PSCard(
      onTap: () => Navigator.pop(context, value),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppColors.primaryAccent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.muted),
        ],
      ),
    );
  }
}
