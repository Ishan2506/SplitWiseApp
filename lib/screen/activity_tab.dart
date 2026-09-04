import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Mark all read
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activity',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                  Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Notifications List
            if (true) // Always show mock notifications for now
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: _getMockNotifications().map((notif) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: notif['bg'] as Color,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: notif['border'] as Color,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: notif['iconBg'] as Color,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Center(
                              child: Text(
                                notif['icon'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: notif['iconFg'] as Color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['subtitle'] as String,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notif['time'] as String,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFA29BA7),
                                    letterSpacing: 0.08,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          // Unread dot
                          if (notif['unread'] as bool)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: AppColors.primaryAccent,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              margin: const EdgeInsets.only(top: 4),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getMockNotifications() {
    return [
      {
        'icon': '+',
        'title': 'Rahul added "Beach shack dinner"',
        'subtitle': '₹4,800 · your share ₹1,200',
        'time': '2 MIN AGO',
        'unread': true,
        'bg': const Color(0xFFFFF5F8),
        'border': const Color(0xFFF7DEE6),
        'iconBg': const Color(0xFFFFE0EA),
        'iconFg': AppColors.primaryAccent,
      },
      {
        'icon': '✓',
        'title': 'Priya settled ₹800 with you',
        'subtitle': 'Balances updated',
        'time': '1 HR AGO',
        'unread': false,
        'bg': const Color(0xFFF6FDF8),
        'border': const Color(0xFFD9ECDF),
        'iconBg': const Color(0xFFD8ECDF),
        'iconFg': const Color(0xFF1D7A4C),
      },
      {
        'icon': '✎',
        'title': 'Aman edited "Groceries"',
        'subtitle': '₹2,100 → ₹2,350',
        'time': 'YESTERDAY',
        'unread': false,
        'bg': Colors.white,
        'border': const Color(0xFFEFEBF1),
        'iconBg': const Color(0xFFF4F2F6),
        'iconFg': AppColors.textSecondary,
      },
      {
        'icon': '+',
        'title': 'Sneha joined Goa Trip 2026',
        'subtitle': 'Invited by you',
        'time': '2 DAYS AGO',
        'unread': false,
        'bg': Colors.white,
        'border': const Color(0xFFEFEBF1),
        'iconBg': const Color(0xFFF4F2F6),
        'iconFg': AppColors.textSecondary,
      },
      {
        'icon': '↔',
        'title': 'You were added to Team lunches',
        'subtitle': '8 members',
        'time': '3 DAYS AGO',
        'unread': false,
        'bg': Colors.white,
        'border': const Color(0xFFEFEBF1),
        'iconBg': const Color(0xFFF4F2F6),
        'iconFg': AppColors.textSecondary,
      },
      {
        'icon': '✓',
        'title': 'Weekend brunch is fully settled',
        'subtitle': 'No open balances',
        'time': 'LAST WEEK',
        'unread': false,
        'bg': Colors.white,
        'border': const Color(0xFFEFEBF1),
        'iconBg': const Color(0xFFF4F2F6),
        'iconFg': AppColors.textSecondary,
      },
    ];
  }
}
