import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'settle_up_screen.dart';

/// Every debt in a group on one screen, answering "who owes whom".
///
/// The signed-in user's own position comes first and in colour, because that
/// is what people open this screen for; everyone else's debts follow in a
/// quieter list. Both come from the server's simplified suggestions, so the
/// list is the minimum set of payments that clears the group rather than every
/// raw pairwise debt.
class WhoOwesWhomScreen extends StatelessWidget {
  final String groupId;

  const WhoOwesWhomScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final currentUserId = context.watch<StateManager>().currentUserId;

    final group = provider.groupById(groupId);
    final balances = provider.balancesFor(groupId);
    final suggestions = balances.suggestions;

    // Split the transfers into the ones the user is part of and the rest.
    final mine = suggestions
        .where((s) => s.fromId == currentUserId || s.toId == currentUserId)
        .toList();
    final others = suggestions
        .where((s) => s.fromId != currentUserId && s.toId != currentUserId)
        .toList();

    // Only the transfers where the user is the payer can be settled from
    // here: the rest are other people's payments to make.
    final iOwe = mine.where((s) => s.fromId == currentUserId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Who owes whom'),
            if (group != null)
              Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadBalances(groupId),
        child: suggestions.isEmpty
            ? const _AllSettled()
            : ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                children: [
                  PageContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (mine.isNotEmpty) ...[
                          const SectionHeader(title: 'Your balances'),
                          for (final s in mine)
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs),
                              child: _YourBalanceCard(
                                suggestion: s,
                                currentUserId: currentUserId,
                                onTap: () => _openSettle(context, s.fromId,
                                    s.toId, s.amount, currentUserId),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (others.isNotEmpty) ...[
                          const SectionHeader(title: 'Everyone else'),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.bgPrimary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (var i = 0; i < others.length; i++) ...[
                                  _OtherDebtRow(suggestion: others[i]),
                                  if (i != others.length - 1)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 56),
                                      child: Divider(height: 1),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
      // Nothing to settle when the user owes nobody, even if they are owed
      // money — that is for the people who owe them to act on.
      bottomNavigationBar: iOwe.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: PSButton(
                label: 'Settle up',
                onPressed: () {
                  // Open on the largest debt, which is the one most worth
                  // clearing first.
                  final biggest = iOwe.reduce(
                      (a, b) => b.amount > a.amount ? b : a);
                  _openSettle(context, biggest.fromId, biggest.toId,
                      biggest.amount, currentUserId);
                },
              ),
            ),
    );
  }

  Future<void> _openSettle(
    BuildContext context,
    String fromId,
    String toId,
    double amount,
    String currentUserId,
  ) async {
    final recorded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SettleUpScreen(
          groupId: groupId,
          // Default to the user paying out when they are the debtor;
          // otherwise record what they are owed.
          fromUserId: fromId,
          toUserId: toId,
          suggestedAmount: amount,
        ),
      ),
    );

    if (recorded == true && context.mounted) {
      await context.read<GroupProvider>().loadBalances(groupId);
    }
  }
}

/// A debt the signed-in user is part of, colour-coded by direction.
class _YourBalanceCard extends StatelessWidget {
  final SettlementSuggestion suggestion;
  final String currentUserId;
  final VoidCallback onTap;

  const _YourBalanceCard({
    required this.suggestion,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // "From" is the person who pays, so if that is the user, they owe.
    final userOwes = suggestion.fromId == currentUserId;
    final other = userOwes ? suggestion.toName : suggestion.fromName;

    return Material(
      color: userOwes ? AppColors.primarySurface : AppColors.successLight,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: userOwes
                  ? AppColors.primaryBorder
                  : AppColors.successBorder,
            ),
          ),
          child: Row(
            children: [
              AvatarWidget.forName(other, size: 42),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userOwes ? 'You owe $other' : '$other owes you',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userOwes ? 'Tap to settle up' : 'Tap to record a payment',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatMoney(suggestion.amount),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: userOwes ? AppColors.negative : AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A debt between two other people — informational, so it stays monochrome.
class _OtherDebtRow extends StatelessWidget {
  final SettlementSuggestion suggestion;

  const _OtherDebtRow({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          AvatarWidget.forName(suggestion.fromName, size: 32),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: suggestion.fromName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' owes '),
                  TextSpan(
                    text: suggestion.toName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            formatMoney(suggestion.amount),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nobody owes anybody. Kept scrollable so pull-to-refresh still works.
class _AllSettled extends StatelessWidget {
  const _AllSettled();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        EmptyStateWidget(
          iconData: Icons.check_circle_rounded,
          title: 'Everyone is settled up',
          subtitle: 'No debts left in this group. Add an expense to get going.',
        ),
      ],
    );
  }
}
