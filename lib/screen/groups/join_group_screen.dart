import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../state/group_provider.dart';
import 'group_detail_screen.dart';
import '../../theme/app_theme.dart';
import 'group_widgets.dart';
import 'scan_qr_screen.dart';

/// Joining a group, whichever way the user got here: a scanned QR code, a
/// tapped invite link, or a code typed in by hand.
///
/// Pass [inviteCode] when it is already known — from a link or a scan — and the
/// screen goes straight to showing the group. Otherwise it asks for the code.
class JoinGroupScreen extends StatefulWidget {
  final String? inviteCode;

  const JoinGroupScreen({super.key, this.inviteCode});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeController = TextEditingController();

  InvitePreview? _preview;
  bool _loadingPreview = false;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null && widget.inviteCode!.isNotEmpty) {
      _codeController.text = widget.inviteCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Fetches what the invite points at, without joining yet.
  Future<void> _lookup() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the invite code');
      return;
    }

    setState(() {
      _loadingPreview = true;
      _error = null;
      _preview = null;
    });

    final result = await context.read<GroupProvider>().previewInvite(code);
    if (!mounted) return;

    setState(() {
      _loadingPreview = false;
      if (result['success'] == true) {
        _preview = result['preview'] as InvitePreview;
      } else {
        _error = result['message'] as String? ?? 'That code did not work';
      }
    });
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanQrScreen()),
    );
    if (code == null || !mounted) return;

    _codeController.text = code;
    await _lookup();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    setState(() => _joining = true);

    final provider = context.read<GroupProvider>();
    final result = await provider.joinByCode(code);
    if (!mounted) return;

    setState(() => _joining = false);

    if (result['success'] != true) {
      showGroupSnack(context, result['message'] ?? 'Could not join the group',
          success: false);
      return;
    }

    final group = result['group'] as GroupModel;
    // Replace this screen with the group, so Back does not return to the
    // invite the user has already accepted.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group.id)),
    );
    showGroupSnack(context, result['message'] ?? 'Joined ${group.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GroupColors.background,
      appBar: AppBar(
        backgroundColor: GroupColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text('Join a group',
            style:
                TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          _buildScanCard(),
          const SizedBox(height: 24),
          Row(
            children: const [
              Expanded(child: Divider(color: GroupColors.surfaceAlt)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or enter the code',
                    style:
                        TextStyle(color: GroupColors.muted, fontSize: 12)),
              ),
              Expanded(child: Divider(color: GroupColors.surfaceAlt)),
            ],
          ),
          const SizedBox(height: 24),
          _buildCodeField(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _buildError(_error!),
          ],
          if (_preview != null) ...[
            const SizedBox(height: 20),
            _buildPreview(_preview!),
          ],
        ],
      ),
    );
  }

  Widget _buildScanCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _scan,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: GroupColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GroupColors.primary, width: 1.4),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GroupColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_scanner,
                  size: 36, color: GroupColors.accent),
            ),
            const SizedBox(height: 14),
            const Text(
              'Scan a QR code',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Point your camera at the group’s invite code',
              style: TextStyle(color: GroupColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codeController,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              letterSpacing: 3,
              fontWeight: FontWeight.bold,
            ),
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 8,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              // The server matches codes case-insensitively, but showing them
              // uppercase matches how they are printed on the invite.
              TextInputFormatter.withFunction(
                (oldValue, newValue) => newValue.copyWith(
                  text: newValue.text.toUpperCase(),
                ),
              ),
            ],
            onSubmitted: (_) => _lookup(),
            decoration: groupFieldDecoration(
              label: 'Invite code',
              hint: 'ABCD2345',
            ).copyWith(counterText: ''),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _loadingPreview ? null : _lookup,
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupColors.primary,
              disabledBackgroundColor: GroupColors.surfaceAlt,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: _loadingPreview
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Find',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GroupColors.negative.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GroupColors.negative.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: GroupColors.negative, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style:
                  const TextStyle(color: GroupColors.negative, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(InvitePreview preview) {
    final canJoin = preview.active && !preview.alreadyMember;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          GroupAvatar.raw(
            type: preview.type,
            photoUrl: preview.photoUrl,
            size: 72,
            radius: 20,
          ),
          const SizedBox(height: 14),
          Text(
            preview.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GroupTypeChip(type: preview.type),
          if (preview.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              preview.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: GroupColors.muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline,
                  size: 16, color: GroupColors.muted),
              const SizedBox(width: 6),
              Text(
                '${preview.memberCount} '
                '${preview.memberCount == 1 ? 'member' : 'members'}',
                style:
                    const TextStyle(color: GroupColors.muted, fontSize: 12),
              ),
              if (preview.createdByName.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Text('•',
                    style: TextStyle(color: GroupColors.muted)),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'by ${preview.createdByName}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: GroupColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (preview.alreadyMember)
            _buildNotice(
              icon: Icons.check_circle_outline,
              color: GroupColors.positive,
              message: 'You are already in this group.',
            )
          else if (!preview.active)
            _buildNotice(
              icon: Icons.link_off,
              color: GroupColors.negative,
              message:
                  'This invite is no longer accepting new members. Ask for a fresh link.',
            ),
          if (preview.alreadyMember) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GroupDetailScreen(groupId: preview.groupId),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GroupColors.accent,
                  side: const BorderSide(color: GroupColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Open the group',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canJoin && !_joining ? _join : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GroupColors.primary,
                  disabledBackgroundColor: GroupColors.surfaceAlt,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _joining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        canJoin ? 'Join group' : 'Joining unavailable',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
