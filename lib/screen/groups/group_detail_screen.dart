import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../model/group_model.dart';
import '../../models/models.dart';
import '../../network/api_service.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import '../../network/receipt_scanner.dart';
import '../add_expense_screen.dart';
import '../expense_detail_screen.dart';
import '../receipt/receipt_scan_screen.dart';
import 'create_group_screen.dart';
import 'group_charts_screen.dart';
import 'group_members_screen.dart';
import 'group_widgets.dart';
import 'invite_screen.dart';
import 'recurring_expenses_screen.dart';
import 'settle_up_screen.dart';
import 'who_owes_whom_screen.dart';

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
      if (!mounted) return;
      context.read<GroupProvider>().refreshGroup(widget.groupId);
      context.read<StateManager>().loadGroupExpenses(widget.groupId);
    });
  } 

  /// Downloads the group's expense history as a CSV and hands it to the
  /// OS share sheet. On web there is no filesystem to write to, so the CSV
  /// text goes straight to the share sheet instead of as a file attachment.
  Future<void> _exportCsv(GroupModel group) async {
    final result = await ApiService.exportGroupExpensesCsv(group.id);
    if (!mounted) return;

    if (result['success'] != true) {
      showAppSnack(
        context,
        result['message'] ?? 'Could not export expenses',
        success: false,
      );
      return;
    }

    final csv = result['csv'] as String;
    final subject = '${group.name} expenses';

    try {
      if (kIsWeb) {
        await SharePlus.instance.share(ShareParams(text: csv, subject: subject));
        return;
      }
      final dir = await getTemporaryDirectory();
      final filename =
          '${group.name.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}_expenses.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: subject),
      );
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Could not share the export: $e', success: false);
      }
    }
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

    // Watched, not read: the expense list below arrives after the first build.
    final state = context.watch<StateManager>();
    final currentUserId = state.currentUserId;
    final isCreator = group.isCreatedBy(currentUserId);
    final balances = provider.balancesFor(group.id);
    final userBalance = balances.balanceFor(currentUserId);

    // Newest first, and only this group's.
    final groupExpenses = state.expenses
        .where((e) => e.groupId == group.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Spending insights',
            icon: const Icon(Icons.pie_chart_outline_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupChartsScreen(groupId: group.id),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Invite people',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InviteScreen(groupId: group.id)),
            ),
          ),
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
              } else if (value == 'recurring') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecurringExpensesScreen(groupId: group.id),
                  ),
                );
              } else if (value == 'export') {
                _exportCsv(group);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'recurring',
                child: Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Recurring expenses'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              if (isCreator) ...[
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit group'),
                    ],
                  ),
                ),
                const PopupMenuItem(
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
                    currencySymbol: group.currencySymbol,
                    onSettle: () async {
                      final recorded = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettleUpScreen(groupId: group.id),
                        ),
                      );
                      if (recorded == true && context.mounted) {
                        provider.refreshGroup(group.id);
                      }
                    },
                    onAddExpense: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddExpenseScreen(groupId: group.id),
                        ),
                      );
                      // Pull the new expense and the balances it moved.
                      if (!context.mounted) return;
                      provider.refreshGroup(group.id);
                      context.read<StateManager>().loadGroupExpenses(group.id);
                    },
                    onScanReceipt: () async {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReceiptScanScreen(groupId: group.id),
                        ),
                      );
                      if (saved != true || !context.mounted) return;
                      provider.refreshGroup(group.id);
                      context.read<StateManager>().loadGroupExpenses(group.id);
                    },
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

                  SectionHeader(
                    title: 'Who pays whom',
                    actionLabel: 'See all',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WhoOwesWhomScreen(groupId: group.id),
                      ),
                    ),
                  ),
                  _SettlementList(
                    balances: balances,
                    currentUserId: currentUserId,
                    currencySymbol: group.currencySymbol,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  SectionHeader(
                    title: 'Recent expenses',
                    subtitle: groupExpenses.isEmpty
                        ? null
                        : '${groupExpenses.length} expense'
                            '${groupExpenses.length == 1 ? '' : 's'} · '
                            '${formatMoney(groupExpenses.fold<double>(0, (sum, e) => sum + e.amount), symbol: group.currencySymbol)} total',
                  ),
                  _GroupExpenseList(
                    expenses: groupExpenses,
                    group: group,
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

/// Square shortcut into the receipt scanner, sized to match the buttons it
/// sits beside so the action row keeps one baseline.
class _ScanReceiptButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanReceiptButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Scan a receipt',
      child: Material(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the signed-in user stands in this group, plus the main actions.
class _YourPosition extends StatelessWidget {
  final double balance;
  final String currencySymbol;
  final VoidCallback onSettle;
  final VoidCallback onAddExpense;
  final VoidCallback onScanReceipt;

  const _YourPosition({
    required this.balance,
    required this.currencySymbol,
    required this.onSettle,
    required this.onAddExpense,
    required this.onScanReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final settled = balance.abs() < 0.01;
    final owed = balance > 0;
    // A negative balance is money the user owes. The 0.01 threshold keeps a
    // rounding remainder of a paisa from counting as a real debt.
    final userOwes = !settled && balance < 0;

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
              formatMoney(balance.abs(), symbol: currencySymbol),
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
              // Settling up is paying someone back, so it only belongs here
              // when the user actually owes. Being owed money is squared up
              // by whoever owes it, not from this screen.
              if (userOwes) ...[
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
              // OCR is Android/iOS only, so the entry point is hidden rather
              // than offered and then refused on web.
              if (ReceiptScanner.isSupported) ...[
                const SizedBox(width: AppSpacing.xs),
                _ScanReceiptButton(onTap: onScanReceipt),
              ],
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
                '${formatMoney(group.balanceLimit, symbol: group.currencySymbol)} per member',
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
                amount: settled
                    ? '—'
                    : formatMoney(balance.abs(),
                        symbol: group.currencySymbol),
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
  final String currencySymbol;

  const _SettlementList({
    required this.balances,
    required this.currentUserId,
    required this.currencySymbol,
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
          _SettlementRow(
            suggestion: s,
            currentUserId: currentUserId,
            currencySymbol: currencySymbol,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _SettlementRow extends StatelessWidget {
  final SettlementSuggestion suggestion;
  final String currentUserId;
  final String currencySymbol;

  const _SettlementRow({
    required this.suggestion,
    required this.currentUserId,
    required this.currencySymbol,
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
            formatMoney(suggestion.amount,
                decimals: true, symbol: currencySymbol),
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

/// This group's expenses, newest first.
class _GroupExpenseList extends StatelessWidget {
  final List<Expense> expenses;
  final GroupModel group;
  final String currentUserId;

  const _GroupExpenseList({
    required this.expenses,
    required this.group,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return PSCard(
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 19, color: AppColors.muted),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'No expenses in this group yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final expense in expenses) ...[
          _GroupExpenseRow(
            expense: expense,
            group: group,
            currentUserId: currentUserId,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _GroupExpenseRow extends StatelessWidget {
  final Expense expense;
  final GroupModel group;
  final String currentUserId;

  const _GroupExpenseRow({
    required this.expense,
    required this.group,
    required this.currentUserId,
  });

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];

  /// Payer names come from the group's own roster, which is already loaded
  /// here, rather than the global member list.
  String _memberName(String memberId) {
    for (final m in group.members) {
      if (m.id == memberId) return m.name;
    }
    return 'Someone';
  }

  /// "You paid", "Priya paid", or for a split payment "You and 1 other
  /// paid".
  String _payersLabel() {
    if (!expense.hasMultiplePayers) {
      return expense.paidById == currentUserId ? 'You' : _memberName(expense.paidById);
    }
    final ids = expense.payers.keys.toList();
    final others = ids.where((id) => id != currentUserId).toList();
    if (ids.contains(currentUserId)) {
      return others.isEmpty
          ? 'You'
          : 'You and ${others.length} other${others.length == 1 ? '' : 's'}';
    }
    final remaining = ids.length - 1;
    return remaining <= 0
        ? _memberName(ids.first)
        : '${_memberName(ids.first)} and $remaining other${remaining == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final symbol = group.currencySymbol;
    final share = expense.splits[currentUserId] ?? 0;
    final myContribution = expense.payers[currentUserId] ?? 0;

    // Net of what you fronted against your share: positive means you're
    // owed, negative means you still owe — this holds for a sole payer
    // (contribution = the whole amount) just as much as a split payment.
    final net = myContribution - share;
    final youLabel = net >= 0 ? 'you lent' : 'your share';
    final youAmount = net.abs();

    return ExpenseItem(
      title: expense.description,
      subtitle: '${expense.category} · ${_payersLabel()} paid',
      amount: formatMoney(expense.amount, symbol: symbol),
      day: expense.date.day.toString().padLeft(2, '0'),
      month: _months[expense.date.month - 1],
      trailingLabel: youAmount.abs() < 0.01
          ? 'not involved'
          : '$youLabel ${formatMoney(youAmount, symbol: symbol)}',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(
            expenseId: expense.id,
            groupId: group.id,
          ),
        ),
      ),
    );
  }
}
