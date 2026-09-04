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
import 'group_widgets.dart';

/// Everything needed to get someone into a group: a scannable QR code, a
/// shareable link, the raw code to read out, and invites by email or mobile.
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
    final text = 'Join "${group.name}" on Splitwise.\n\n'
        '${invite.link}\n\n'
        'Or enter this code in the app: ${invite.code}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Join ${group.name} on Splitwise'),
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
        backgroundColor: const Color(0xFF1A1A1E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Generate a new code?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'The current link and QR code will stop working straight away. '
          'Anyone who has not joined yet will need the new one.',
          style: TextStyle(color: GroupColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel',
                style: TextStyle(color: GroupColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: GroupColors.primary),
            child: const Text('Generate',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyWithCode = true);
    final result =
        await context.read<GroupProvider>().rotateInvite(group.id);
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

    final isEmail = raw.contains('@');
    final isMobile = RegExp(r'^[6-9]\d{9}$').hasMatch(raw);
    if (!isEmail && !isMobile) {
      showGroupSnack(
          context, 'Enter an email address or a 10-digit mobile number',
          success: false);
      return;
    }

    setState(() => _sendingInvite = true);
    final result = await context.read<GroupProvider>().inviteByContact(
          groupId: group.id,
          email: isEmail ? raw : null,
          mobileNumber: isEmail ? null : raw,
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
    final group = provider.groupById(widget.groupId);

    if (group == null) {
      return const Scaffold(
        backgroundColor: const Color(0xFF0E0E10),
        body: Center(
          child: Text('This group is no longer available',
              style: TextStyle(color: GroupColors.muted)),
        ),
      );
    }

    final currentUserId = context.read<StateManager>().currentUserId;
    final isCreator = group.isCreatedBy(currentUserId);
    final invite = group.invite;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E10),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Invite members',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
        centerTitle: false,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildGroupHeader(group),
          const SizedBox(height: 20),
          if (invite == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: GroupColors.primary),
              ),
            )
          else ...[
            _buildQrCard(group, invite),
            const SizedBox(height: 16),
            _buildLinkCard(group, invite),
            const SizedBox(height: 16),
            if (isCreator) _buildCodeControls(group, invite),
            if (isCreator) const SizedBox(height: 16),
          ],
          _buildContactInvite(group),
          if (group.pendingInvites.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPendingInvites(group),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupHeader(GroupModel group) {
    return Row(
      children: [
        GroupAvatar(group: group, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  GroupTypeChip(type: group.type, compact: true),
                  const SizedBox(width: 8),
                  Text(
                    '${group.members.length} '
                    '${group.members.length == 1 ? 'member' : 'members'}',
                    style: const TextStyle(
                        color: GroupColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrCard(GroupModel group, GroupInvite invite) {
    final active = invite.isActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'Scan to join',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Point the Splitwise scanner at this code',
            style: TextStyle(color: GroupColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Stack(
            alignment: Alignment.center,
            children: [
              // The QR is drawn on white so scanners read it reliably.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: invite.qrPayload,
                  version: QrVersions.auto,
                  size: 200,
                  gapless: false,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0F172A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              // Make it obvious when the code will not currently work.
              if (!active)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.72),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link_off,
                              color: GroupColors.negative, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            invite.isExpired
                                ? 'This code has expired'
                                : 'Joining is turned off',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          // The code itself, for reading out loud or typing in.
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _copy(invite.code, 'Invite code'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: GroupColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GroupColors.surfaceAlt),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    invite.code,
                    style: const TextStyle(
                      color: const Color(0xFFEE2B6C),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy, size: 16, color: GroupColors.muted),
                ],
              ),
            ),
          ),
          if (invite.expiresAt != null && !invite.isExpired) ...[
            const SizedBox(height: 10),
            Text(
              'Expires ${_formatExpiry(invite.expiresAt!)}',
              style: const TextStyle(color: GroupColors.warning, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkCard(GroupModel group, GroupInvite invite) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite link',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: GroupColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GroupColors.surfaceAlt),
            ),
            child: Text(
              invite.link,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: GroupColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(invite.link, 'Invite link'),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEE2B6C),
                    side: const BorderSide(color: Color(0xFFEE2B6C)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _share(group, invite),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEE2B6C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodeControls(GroupModel group, GroupInvite invite) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Allow joining',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Turn off to stop new people using the link or code',
                      style: TextStyle(color: GroupColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: invite.enabled,
                activeThumbColor: GroupColors.primary,
                onChanged: _busyWithCode
                    ? null
                    : (value) => _toggleEnabled(group, value),
              ),
            ],
          ),
          const Divider(color: GroupColors.surfaceAlt, height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _busyWithCode ? null : () => _rotate(group),
              icon: const Icon(Icons.autorenew, size: 18),
              label: const Text('Generate a new code'),
              style: TextButton.styleFrom(
                foregroundColor: GroupColors.warning,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInvite(GroupModel group) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite by email or mobile',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Anyone already on Splitwise joins straight away. Everyone else is '
            'kept as a pending invite.',
            style: TextStyle(color: GroupColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _contactController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _sendInvite(group),
                  decoration: groupFieldDecoration(
                    label: 'Email or mobile',
                    hint: 'friend@example.com',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _sendingInvite ? null : () => _sendInvite(group),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEE2B6C),
                    disabledBackgroundColor: GroupColors.surfaceAlt,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _sendingInvite
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInvites(GroupModel group) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending invites (${group.pendingInvites.length})',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...group.pendingInvites.map(
            (invite) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: GroupColors.surfaceAlt,
                child: Icon(Icons.hourglass_empty,
                    size: 16, color: GroupColors.warning),
              ),
              title: Text(invite.contact,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: const Text('Waiting to join',
                  style:
                      TextStyle(color: GroupColors.muted, fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.close,
                    size: 18, color: GroupColors.negative),
                tooltip: 'Withdraw invite',
                onPressed: () => _revoke(group, invite),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatExpiry(DateTime when) {
    final diff = when.difference(DateTime.now());
    if (diff.inDays > 0) {
      return 'in ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'}';
    }
    if (diff.inHours > 0) {
      return 'in ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'}';
    }
    if (diff.inMinutes > 0) return 'in ${diff.inMinutes} min';
    return 'shortly';
  }
}
