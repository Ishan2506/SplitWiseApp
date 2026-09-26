import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../models/models.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/pie_chart_widget.dart';

/// A vivid, high-contrast palette just for charts — deliberately bolder than
/// AppColors.avatarInk (that one is tuned for soft avatar backgrounds, which
/// reads as muted/dull once it is filling a whole pie slice).
///
/// Colours are picked dynamically: a label (category name or payer name)
/// hashes to one of these, so any category — the five built-in ones or a
/// custom/legacy value — and any payer always lands on the same distinct
/// colour everywhere it appears, with no fixed lookup table to maintain.
const _chartPalette = <Color>[
  Color(0xFFEF476F), // pink-red
  Color(0xFF118AB2), // blue
  Color(0xFFFFB703), // amber
  Color(0xFF06D6A0), // teal-green
  Color(0xFF9B5DE5), // purple
  Color(0xFFFF6B35), // orange
  Color(0xFF3A86FF), // azure
  Color(0xFF06A77D), // deep green
];

Color _chartColorFor(String label) {
  if (label.isEmpty) return _chartPalette.first;
  final hash = label.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return _chartPalette[hash % _chartPalette.length];
}

/// Two views on the same money: what it went on, and who fronted it.
///
/// Reads straight from the already-loaded expense list rather than a
/// separate endpoint — a group's spending history is exactly the same data
/// [GroupDetailScreen]'s "Recent expenses" list uses, just added up
/// differently.
class GroupChartsScreen extends StatelessWidget {
  final String groupId;

  const GroupChartsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final group = context.watch<GroupProvider>().groupById(groupId);
    final state = context.watch<StateManager>();

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

    final expenses =
        state.expenses.where((e) => e.groupId == groupId).toList();
    final symbol = group.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending insights'),
      ),
      body: expenses.isEmpty
          ? const EmptyStateWidget(
              iconData: Icons.pie_chart_outline_rounded,
              title: 'Nothing to chart yet',
              subtitle: 'Add an expense to this group to see where the '
                  'money goes.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              children: [
                PageContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Total spent',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'By category'),
                      PSCard(
                        child: PSPieChart(
                          slices: _byCategory(expenses),
                          currencySymbol: symbol,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'Who paid'),
                      PSCard(
                        child: PSPieChart(
                          slices: _byPayer(expenses, group),
                          currencySymbol: symbol,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<PieSlice> _byCategory(List<Expense> expenses) {
    final totals = <String, double>{};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }

    final categories = totals.keys.toList();
    return [
      for (final category in categories)
        PieSlice(
          label: category,
          value: totals[category]!,
          color: _chartColorFor(category),
        ),
    ];
  }

  List<PieSlice> _byPayer(List<Expense> expenses, GroupModel group) {
    final totals = <String, double>{};
    for (final e in expenses) {
      // A split payment credits each actual contributor for what they
      // fronted, not the whole expense to whoever paid the most.
      for (final entry in e.payers.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }

    return totals.entries.map((entry) {
      final name = _memberName(group, entry.key);
      return PieSlice(
        label: name,
        value: entry.value,
        color: _chartColorFor(name),
      );
    }).toList();
  }

  String _memberName(GroupModel group, String memberId) {
    for (final m in group.members) {
      if (m.id == memberId) return m.name;
    }
    return 'Someone';
  }
}
