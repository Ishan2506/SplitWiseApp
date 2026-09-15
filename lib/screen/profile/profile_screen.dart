import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/state_manager.dart';
import 'edit_profile_screen.dart';
import '../../state/group_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';

/// Profile and settings.
///
/// There is deliberately no appearance or theme setting: the app is light-mode
/// only, so offering a switch would be a control that does nothing.
class ProfileScreen extends StatefulWidget {
  /// True when shown as a tab inside the app shell, which supplies its own
  /// navigation — in that case this screen must not draw a back button.
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushNotifications = true;
  bool _emailSummary = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final groupCount = context.watch<GroupProvider>().groups.length;
    final user = state.currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        titleSpacing: widget.embedded
            ? AppBreakpoints.pagePadding(context)
            : null,
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                _IdentityCard(
                  name: user.name,
                  email: user.email,
                  photoUrl: state.currentUserModel?.avatarUrl ?? '',
                  onEdit: () => _openEditProfile(context),
                ),
                const SizedBox(height: AppSpacing.xl),

                const _GroupLabel('Preferences'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Currency',
                      trailing: const Text(
                        'INR',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () => showAppSnack(
                          context, 'More currencies are coming soon'),
                    ),
                    _SettingsRow(
                      icon: Icons.notifications_none_rounded,
                      label: 'Push notifications',
                      subtitle: 'Expenses, settlements and invites',
                      trailing: Switch(
                        value: _pushNotifications,
                        onChanged: (v) =>
                            setState(() => _pushNotifications = v),
                      ),
                      onTap: () => setState(
                          () => _pushNotifications = !_pushNotifications),
                    ),
                    _SettingsRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Weekly email summary',
                      subtitle: 'A recap of what you spent',
                      trailing: Switch(
                        value: _emailSummary,
                        onChanged: (v) => setState(() => _emailSummary = v),
                      ),
                      onTap: () =>
                          setState(() => _emailSummary = !_emailSummary),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                const _GroupLabel('Account'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.groups_outlined,
                      label: 'Your groups',
                      trailing: Text(
                        '$groupCount',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () => Navigator.maybePop(context),
                    ),
                    _SettingsRow(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & support',
                      onTap: () =>
                          showAppSnack(context, 'Support is coming soon'),
                    ),
                    _SettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy policy',
                      onTap: () =>
                          showAppSnack(context, 'Privacy policy is coming soon'),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      tone: AppColors.error,
                      showChevron: false,
                      isLast: true,
                      onTap: () => _confirmLogout(context, state),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'PaisaSplit · v1.0.0',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  Future<void> _confirmLogout(BuildContext context, StateManager state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You will need to sign in again to see your groups and balances.'),
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
            label: 'Log out',
            variant: PSButtonVariant.danger,
            size: PSButtonSize.small,
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await state.logout();
    if (!context.mounted) return;

    // The profile screen lives inside the dashboard shell, so popping is not
    // enough — clear the whole stack so the signed-out user cannot navigate
    // back into the previous session's screens.
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}

/// The user's name, email and avatar in a soft tinted panel.
class _IdentityCard extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onEdit;
  final String photoUrl;

  const _IdentityCard({
    required this.name,
    required this.email,
    required this.onEdit,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          AvatarWidget.forName(
            name,
            size: 58,
            imageUrl: photoUrl.isEmpty ? null : photoUrl,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Your name' : name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF96707E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          PSButton(
            label: 'Edit',
            size: PSButtonSize.small,
            expand: false,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.xxs, bottom: AppSpacing.xs),
      child: OverlineLabel(text),
    );
  }
}

/// A rounded container that groups related settings rows.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

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
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;
  final bool showChevron;
  final Color? tone;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
    this.showChevron = true,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.textPrimary;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            hoverColor: AppColors.bgSecondary,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tone != null
                          ? AppColors.primaryLight
                          : AppColors.bgSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 17, color: color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(subtitle!,
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                  if (showChevron && trailing is! Switch) ...[
                    const SizedBox(width: AppSpacing.xxs),
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.muted),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 58),
            child: Divider(height: 1),
          ),
      ],
    );
  }
}
