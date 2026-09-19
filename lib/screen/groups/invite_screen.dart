import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'group_widgets.dart';

/// Everything needed to get someone into a group: a scannable QR code, a
/// shareable link, the raw code to read out, and invites by email.
class InviteScreen extends StatefulWidget {
  final String groupId;

  const InviteScreen({super.key, required this.groupId});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _contactController = TextEditingController();
  bool _sendingInvite = false;
  bool _busyWithCode = false;

  @override
  void initState() {
    super.initState();
    // Make sure we are showing the code the server currently considers valid.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().refreshInvite(widget.groupId);
    });
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) showGroupSnack(context, '$label copied');
  }

  Future<void> _share(GroupModel group, GroupInvite invite) async {
    final text = 'Join "${group.name}" on PaisaSplit.\n\n'
        '${invite.link}\n\n'
        'Or enter this code in the app: ${invite.code}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Join ${group.name} on PaisaSplit'),
      );
    } catch (e) {
      if (mounted) {
        // Sharing is unavailable here — fall back to the clipboard.
        await _copy(text, 'Invite');
      }
    }
  }

  Future<void> _rotate(GroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generate a new code?'),
        content: const Text(
          'The current link and QR code will stop working straight away. '
          'Anyone who has not joined yet will need the new one.',
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
            label: 'Generate',
            size: PSButtonSize.small,
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyWithCode = true);
    final result = await context.read<GroupProvider>().rotateInvite(group.id);
    if (!mounted) return;
    setState(() => _busyWithCode = false);

    showGroupSnack(
      context,
      result['success'] == true
          ? 'A new invite code is ready'
          : result['message'] ?? 'Could not generate a new code',
      success: result['success'] == true,
    );
  }

  Future<void> _toggleEnabled(GroupModel group, bool enabled) async {
    setState(() => _busyWithCode = true);
    final result = await context
        .read<GroupProvider>()
        .setInviteEnabled(groupId: group.id, enabled: enabled);
    if (!mounted) return;
    setState(() => _busyWithCode = false);

    if (result['success'] != true) {
      showGroupSnack(context, result['message'] ?? 'Could not update joining',
          success: false);
    }
  }

  Future<void> _sendInvite(GroupModel group) async {
    final raw = _contactController.text.trim();
    if (raw.isEmpty) return;

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(raw)) {
      showGroupSnack(context, 'Enter a valid email address', success: false);
      return;
    }

    setState(() => _sendingInvite = true);
    final result = await context.read<GroupProvider>().inviteByEmail(
          groupId: group.id,
          email: raw,
        );
    if (!mounted) return;
    setState(() => _sendingInvite = false);

    if (result['success'] == true) {
      _contactController.clear();
      showGroupSnack(context, result['message'] ?? 'Invite sent');
    } else {
      showGroupSnack(context, result['message'] ?? 'Could not send the invite',
          success: false);
    }
  }

  Future<void> _revoke(GroupModel group, PendingInvite invite) async {
    final result = await context
        .read<GroupProvider>()
        .revokeInvite(groupId: group.id, inviteId: invite.id);
    if (!mounted) return;
    showGroupSnack(
      context,
      result['success'] == true
          ? 'Invite for ${invite.contact} withdrawn'
          : result['message'] ?? 'Could not withdraw the invite',
      success: result['success'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final stateManager = context.watch<StateManager>();

    // Only GroupProvider holds the API-backed GroupModel (with its invite);
    // StateManager's list is the legacy local model and cannot serve here.
    final group = provider.groupById(widget.groupId);

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

    final currentUserId = stateManager.currentUserId;
    final isCreator = group.isCreatedBy(currentUserId);
    final invite = group.invite;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite members'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Done'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                _GroupSummary(group: group),
                const SizedBox(height: AppSpacing.md),
                if (invite == null)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _QrCard(
                    group: group,
                    invite: invite,
                    onShare: () => _share(group, invite),
                    onCopyCode: () => _copy(invite.code, 'Code'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _LinkCard(
                    invite: invite,
                    onCopy: () => _copy(invite.link, 'Link'),
                  ),
                  if (isCreator) ...[
                    const SizedBox(height: AppSpacing.md),
                    _CodeControls(
                      invite: invite,
                      busy: _busyWithCode,
                      onToggle: (v) => _toggleEnabled(group, v),
                      onRotate: () => _rotate(group),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(
                  title: 'Invite by email',
                  subtitle: 'We will email them a link and the invite code',
                ),
                _ContactInvite(
                  controller: _contactController,
                  sending: _sendingInvite,
                  onSend: () => _sendInvite(group),
                ),

                if (group.pendingInvites.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Pending invites',
                    subtitle: '${group.pendingInvites.length} waiting to join',
                  ),
                  for (final pending in group.pendingInvites) ...[
                    _PendingRow(
                      invite: pending,
                      onRevoke: () => _revoke(group, pending),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSummary extends StatelessWidget {
  final GroupModel group;
  const _GroupSummary({required this.group});

  @override
  Widget build(BuildContext context) {
    return PSCard(
      child: Row(
        children: [
          GroupAvatar(group: group, size: 44),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${group.members.length} member'
                  '${group.members.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The QR code plus the human-readable code beneath it.
class _QrCard extends StatelessWidget {
  final GroupModel group;
  final GroupInvite invite;
  final VoidCallback onShare;
  final VoidCallback onCopyCode;

  const _QrCard({
    required this.group,
    required this.invite,
    required this.onShare,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    final active = invite.isActive;

    return PSCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          if (!active)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: StatusBadge(
                label: invite.isExpired ? 'Code expired' : 'Joining is off',
                tone: BadgeTone.warning,
                icon: Icons.info_outline_rounded,
              ),
            ),
          Opacity(
            opacity: active ? 1 : 0.4,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: QrImageView(
                data: invite.qrPayload,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const OverlineLabel('Invite code'),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onCopyCode,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  invite.code,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.copy_rounded, size: 16, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PSButton(
            label: 'Share invite',
            icon: Icons.ios_share_rounded,
            size: PSButtonSize.medium,
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final GroupInvite invite;
  final VoidCallback onCopy;

  const _LinkCard({required this.invite, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return PSCard(
      onTap: onCopy,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.bgSubtle,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.link_rounded,
                size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OverlineLabel('Invite link'),
                const SizedBox(height: 2),
                Text(
                  invite.link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.copy_rounded, size: 17, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// Owner-only controls: turn joining off, or roll the code.
class _CodeControls extends StatelessWidget {
  final GroupInvite invite;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRotate;

  const _CodeControls({
    required this.invite,
    required this.busy,
    required this.onToggle,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    return PSCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allow joining',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 1),
                    Text(
                      'Turn off to stop new people using the link or code',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: invite.enabled,
                onChanged: busy ? null : onToggle,
              ),
            ],
          ),
          const Divider(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: busy ? null : onRotate,
              icon: const Icon(Icons.autorenew_rounded, size: 17),
              label: const Text('Generate a new code'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactInvite extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _ContactInvite({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: PSTextField(
            label: 'Email',
            showLabel: false,
            placeholder: 'name@example.com',
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            enabled: !sending,
            textInputAction: TextInputAction.send,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          height: 54,
          width: 54,
          child: PSButton(
            label: '',
            icon: sending ? null : Icons.send_rounded,
            isLoading: sending,
            variant: PSButtonVariant.accent,
            onPressed: sending ? null : onSend,
          ),
        ),
      ],
    );
  }
}

class _PendingRow extends StatelessWidget {
  final PendingInvite invite;
  final VoidCallback onRevoke;

  const _PendingRow({required this.invite, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    return PSCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.warningLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.schedule_rounded,
                size: 17, color: AppColors.warning),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.contact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 1),
                Text('Invitation pending',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: onRevoke,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }
}
