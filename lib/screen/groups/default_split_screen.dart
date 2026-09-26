import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';

/// Sets a remembered split ratio for a group (e.g. "always 60/40 between
/// these two roommates"), so a new expense there starts from it instead of
/// an even split — the split section on Add Expense still lets it be
/// adjusted per-expense afterwards.
class DefaultSplitScreen extends StatefulWidget {
  final String groupId;

  const DefaultSplitScreen({super.key, required this.groupId});

  @override
  State<DefaultSplitScreen> createState() => _DefaultSplitScreenState();
}

class _DefaultSplitScreenState extends State<DefaultSplitScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final group = context.read<GroupProvider>().groupById(widget.groupId);
    final members = group?.members ?? const <GroupMember>[];
    final existing = group?.defaultSplit;
    final evenShare = members.isEmpty ? 0.0 : 100.0 / members.length;

    for (final m in members) {
      final pct = existing?[m.id] ?? evenShare;
      _controllers[m.id] = TextEditingController(text: pct.toStringAsFixed(2));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _controllers.values.fold<double>(
        0,
        (sum, c) => sum + (double.tryParse(c.text.trim()) ?? 0),
      );

  Future<void> _save() async {
    final total = _total;
    if ((total - 100).abs() > 0.01) {
      showAppSnack(
        context,
        'Percentages must add up to 100% (currently ${total.toStringAsFixed(2)}%)',
        success: false,
      );
      return;
    }

    setState(() => _saving = true);
    final splits = {
      for (final entry in _controllers.entries)
        entry.key: double.tryParse(entry.value.text.trim()) ?? 0,
    };
    final result = await context
        .read<GroupProvider>()
        .setDefaultSplit(groupId: widget.groupId, splits: splits);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      showAppSnack(context, 'Default split saved');
      Navigator.pop(context);
    } else {
      showAppSnack(
        context,
        (result['message'] ?? 'Could not save the default split').toString(),
        success: false,
      );
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    final result = await context
        .read<GroupProvider>()
        .setDefaultSplit(groupId: widget.groupId, splits: null);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      showAppSnack(context, 'Default split cleared — back to an equal split');
      Navigator.pop(context);
    } else {
      showAppSnack(
        context,
        (result['message'] ?? 'Could not clear the default split').toString(),
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = context.watch<GroupProvider>().groupById(widget.groupId);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyStateWidget(
          iconData: Icons.link_off_rounded,
          title: 'Group unavailable',
          subtitle: 'This group may have been deleted.',
        ),
      );
    }

    final total = _total;
    final balanced = (total - 100).abs() < 0.01;

    return Scaffold(
      appBar: AppBar(title: const Text('Default split')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'New expenses in this group will start split this way — '
                  'still adjustable on each expense afterwards.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                PSCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < group.members.length; i++) ...[
                        _row(group.members[i]),
                        if (i != group.members.length - 1)
                          const Padding(
                            padding: EdgeInsets.only(left: 44),
                            child: Divider(height: 1),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: balanced
                        ? AppColors.successLight
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: balanced
                          ? AppColors.successBorder
                          : AppColors.primaryBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        balanced
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: balanced ? AppColors.success : AppColors.primaryDark,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          balanced
                              ? 'Adds up to 100%'
                              : '${(100 - total).toStringAsFixed(2)}% left to assign',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                balanced ? AppColors.success : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PSButton(
                  label: 'Save default split',
                  onPressed: _saving ? null : _save,
                  isLoading: _saving,
                ),
                if (group.hasDefaultSplit) ...[
                  const SizedBox(height: AppSpacing.sm),
                  PSButton(
                    label: 'Clear default (use equal split)',
                    variant: PSButtonVariant.secondary,
                    onPressed: _saving ? null : _clear,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(GroupMember member) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          AvatarWidget.forName(member.name, size: 32),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 84,
            child: TextField(
              controller: _controllers[member.id],
              onChanged: (_) => setState(() {}),
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                suffixText: '%',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
