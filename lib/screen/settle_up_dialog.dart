import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/common_widgets.dart';

/// Records a payment between two people so balances can be squared up.
///
/// Presented as a bottom sheet — it is a short form, and a sheet keeps the
/// keyboard and the amount field comfortably in view on a phone.
class SettleUpDialog extends StatefulWidget {
  final String? initialGroupId;
  const SettleUpDialog({super.key, this.initialGroupId});

  /// Opens the sheet. Returns true when a payment was recorded.
  static Future<bool?> show(BuildContext context, {String? groupId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SettleUpDialog(initialGroupId: groupId),
    );
  }

  @override
  State<SettleUpDialog> createState() => _SettleUpDialogState();
}

class _SettleUpDialogState extends State<SettleUpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _fromMemberId;
  String? _toMemberId;
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _groupId = widget.initialGroupId;
    final state = Provider.of<StateManager>(context, listen: false);

    // Default to someone else paying the signed-in user: pick the first other
    // member if there is one, rather than assuming a fixed id.
    final others = state.members
        .where((m) => m.id != state.currentUserId)
        .map((m) => m.id)
        .toList();
    _fromMemberId = others.isNotEmpty ? others.first : state.currentUserId;
    _toMemberId = state.currentUserId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save(StateManager state) {
    if (!_formKey.currentState!.validate()) return;

    if (_fromMemberId == _toMemberId) {
      showAppSnack(context, 'Payer and recipient cannot be the same person',
          success: false);
      return;
    }

    final amount = double.parse(_amountController.text.trim());

    final payment = Payment(
      id: 'p${state.payments.length + 1}',
      fromMemberId: _fromMemberId!,
      toMemberId: _toMemberId!,
      amount: amount,
      date: DateTime.now(),
      groupId: _groupId,
    );

    state.addPayment(payment);
    state.pushNotification(
      kind: ActivityKind.settled,
      title: 'Payment of ${formatMoney(amount)} recorded',
      subtitle: 'Balances updated',
    );

    Navigator.pop(context, true);
    showAppSnack(context, 'Recorded ${formatMoney(amount)}');
  }

  String _nameFor(List<Member> members, String? id) {
    for (final m in members) {
      if (m.id == id) return m.name;
    }
    return 'Select';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final members = state.members;
    final groups = state.groups;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Record a payment',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                'Log money that has already changed hands.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),

              // Who paid whom, shown as a single visual transfer row.
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PersonPicker(
                        label: 'From',
                        name: _nameFor(members, _fromMemberId),
                        members: members,
                        onSelected: (id) =>
                            setState(() => _fromMemberId = id),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 17, color: AppColors.muted),
                    ),
                    Expanded(
                      child: _PersonPicker(
                        label: 'To',
                        name: _nameFor(members, _toMemberId),
                        members: members,
                        onSelected: (id) => setState(() => _toMemberId = id),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              PSTextField(
                label: 'Amount',
                placeholder: '0',
                controller: _amountController,
                autofocus: true,
                prefixText: '₹ ',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter amount';
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              _GroupDropdown(
                groups: groups,
                value: _groupId,
                onChanged: (v) => setState(() => _groupId = v),
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: PSButton(
                      label: 'Cancel',
                      variant: PSButtonVariant.secondary,
                      size: PSButtonSize.medium,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: PSButton(
                      label: 'Save payment',
                      size: PSButtonSize.medium,
                      onPressed: () => _save(state),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar + name that opens a member picker when tapped.
class _PersonPicker extends StatelessWidget {
  final String label;
  final String name;
  final List<Member> members;
  final ValueChanged<String> onSelected;

  const _PersonPicker({
    required this.label,
    required this.name,
    required this.members,
    required this.onSelected,
  });

  Future<void> _pick(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
              child: Text(label == 'From' ? 'Who paid?' : 'Who received?',
                  style: Theme.of(sheetContext).textTheme.headlineSmall),
            ),
            for (final m in members)
              ListTile(
                onTap: () => Navigator.pop(sheetContext, m.id),
                leading: AvatarWidget.forName(m.name, size: 36),
                title: Text(m.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
    if (id != null) onSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Column(
          children: [
            AvatarWidget.forName(name, size: 42),
            const SizedBox(height: 6),
            OverlineLabel(label),
            const SizedBox(height: 1),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDropdown extends StatelessWidget {
  final List<Group> groups;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _GroupDropdown({
    required this.groups,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Group (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, color: AppColors.muted),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No group'),
            ),
            for (final g in groups)
              DropdownMenuItem<String?>(
                value: g.id,
                child: Text(g.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
