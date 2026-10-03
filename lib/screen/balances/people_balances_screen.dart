import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/currencies.dart';
import '../../widgets/common_widgets.dart';
import 'person_balance_screen.dart';

/// The net amount with one person, as text — e.g. "₹300". When groups in
/// different currencies couldn't be converted, each currency is listed.
String formatPersonNet(PersonBalance p, NetBalances all,
    {String separator = '  '}) {
  if (p.net != null) {
    return formatMoney(p.net!.abs(), symbol: all.currencySymbol);
  }
  return p.netByCurrency.entries
      .where((e) => e.value.abs() >= 0.01)
      .map((e) => '${e.value < 0 ? '−' : '+'}'
          '${formatMoney(e.value.abs(), symbol: currencySymbolFor(e.key))}')
      .join(separator);
}

/// "across 2 groups" / the single group's name.
String personGroupsCaption(PersonBalance p) {
  if (p.groups.length == 1) return p.groups.first.groupName;
  return 'across ${p.groups.length} groups';
}

/// Everyone the signed-in user has an open balance with, each netted across
/// every group they share — the "you owe / you're owed" by person view.
class PeopleBalancesScreen extends StatefulWidget {
  const PeopleBalancesScreen({super.key});

  @override
  State<PeopleBalancesScreen> createState() => _PeopleBalancesScreenState();
}

class _PeopleBalancesScreenState extends State<PeopleBalancesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GroupProvider>().loadNetBalances();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final net = provider.netBalances;
    final owedToYou = net.people.where((p) => p.theyOweYou).toList();
    final youOwe = net.people.where((p) => !p.theyOweYou).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Balances by person')),
      body: RefreshIndicator(
        color: AppColors.primaryAccent,
        onRefresh: () => provider.loadNetBalances(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Each person\'s balance is netted across every group you '
                    'share, so one payment can settle them all.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'You owe',
                          value: formatMoney(net.totalOwe,
                              symbol: net.currencySymbol),
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
                          value: formatMoney(net.totalOwed,
                              symbol: net.currencySymbol),
                          valueColor: AppColors.success,
                          background: AppColors.successLight,
                          borderColor: AppColors.successBorder,
                          labelColor: const Color(0xFF4F8A68),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (net.people.isEmpty)
                    const EmptyStateWidget(
                      iconData: Icons.handshake_outlined,
                      title: 'All square with everyone',
                      subtitle: 'Nobody owes you and you owe nobody, across '
                          'all your groups.',
                      compact: true,
                    )
                  else ...[
                    if (youOwe.isNotEmpty) ...[
                      const SectionHeader(title: 'You owe'),
                      PersonBalanceList(people: youOwe, all: net),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    if (owedToYou.isNotEmpty) ...[
                      const SectionHeader(title: 'Owes you'),
                      PersonBalanceList(people: owedToYou, all: net),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card of person rows; used here and on the dashboard.
class PersonBalanceList extends StatelessWidget {
  final List<PersonBalance> people;
  final NetBalances all;

  const PersonBalanceList({super.key, required this.people, required this.all});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < people.length; i++) ...[
            _PersonRow(person: people[i], all: all),
            if (i != people.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 64),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final PersonBalance person;
  final NetBalances all;

  const _PersonRow({required this.person, required this.all});

  @override
  Widget build(BuildContext context) {
    final owesYou = person.theyOweYou;
    final color = owesYou ? AppColors.success : AppColors.negative;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonBalanceScreen(userId: person.person.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            children: [
              AvatarWidget.forName(
                person.person.name,
                size: 40,
                imageUrl: person.person.avatarUrl.isEmpty
                    ? null
                    : person.person.avatarUrl,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      personGroupsCaption(person),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Flexible + scale-down: a lakh-sized figure, or one line per
              // currency, must shrink rather than push past the edge.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    OverlineLabel(owesYou ? 'Owes you' : 'You owe',
                        color: color),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatPersonNet(person, all, separator: '\n'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
