import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../model/group_model.dart';
import '../../network/api_service.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'invite_screen.dart';

/// Create a group: name it, say what kind it is, and pick who is in it.
class CreateGroupScreen extends StatefulWidget {
  final String? existingGroupId;
  const CreateGroupScreen({super.key, this.existingGroupId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();

  GroupType _selectedType = GroupType.trip;

  bool _isLoading = false;
  bool _isLoadingUsers = true;
  String _search = '';
  final Map<String, bool> _selectedMembers = {};
  List<Member> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      final state = Provider.of<StateManager>(context, listen: false);
      final result = await ApiService.getUsers();

      if (result['success'] == true && result['users'] != null) {
        final users = List<Map<String, dynamic>>.from(result['users']);
        _availableUsers = users
            .where((u) => u['_id'] != state.currentUserId)
            .map((u) => Member(
                  id: u['_id'] ?? '',
                  name: u['name'] ?? 'Unknown',
                  email: u['email'] ?? '',
                  avatarUrl: u['avatarUrl'] ?? '',
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  int get _selectedCount =>
      _selectedMembers.values.where((v) => v).length;

  List<Member> get _visibleUsers {
    if (_search.trim().isEmpty) return _availableUsers;
    final q = _search.toLowerCase();
    return _availableUsers
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final groupName = _groupNameController.text.trim();
    final memberIds = _selectedMembers.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    try {
      final result = await ApiService.createGroup(
        name: groupName,
        description: _selectedType.label,
        type: _selectedType,
        memberIds: memberIds,
      );

      if (!mounted) return;

      if (result['success'] == true && result['group'] != null) {
        final createdGroup = result['group'] as GroupModel;

        await Provider.of<GroupProvider>(context, listen: false)
            .loadGroups(silent: true);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InviteScreen(groupId: createdGroup.id),
          ),
        );
      } else {
        showAppSnack(context, result['message'] ?? 'Failed to create group',
            success: false);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, 'Error: $e', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  PSTextField(
                    label: 'Group name',
                    placeholder: 'Goa Trip 2026',
                    controller: _groupNameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Give your group a name'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Text(
                    'What kind of group?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TypeGrid(
                    selected: _selectedType,
                    onSelected: (t) => setState(() => _selectedType = t),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  SectionHeader(
                    title: 'Add people',
                    subtitle: _selectedCount == 0
                        ? 'You can also invite them later with a link'
                        : '$_selectedCount selected',
                  ),
                  PSSearchField(
                    hint: 'Search by name or email',
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MemberPicker(
                    isLoading: _isLoadingUsers,
                    users: _visibleUsers,
                    hasAnyUsers: _availableUsers.isNotEmpty,
                    selected: _selectedMembers,
                    onToggle: (id, v) =>
                        setState(() => _selectedMembers[id] = v),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  PSButton(
                    label: 'Create group',
                    onPressed: _isLoading ? null : _createGroup,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'You can invite more people once the group exists.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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

/// Group types as a wrapping set of cards rather than a plain dropdown.
class _TypeGrid extends StatelessWidget {
  final GroupType selected;
  final ValueChanged<GroupType> onSelected;

  const _TypeGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 480 ? 3 : 2;
        const gap = AppSpacing.xs;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final type in GroupType.values)
              SizedBox(
                width: width,
                child: _TypeCard(
                  type: type,
                  isSelected: type == selected,
                  onTap: () => onSelected(type),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TypeCard extends StatelessWidget {
  final GroupType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color:
                isSelected ? AppColors.primaryAccent : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: type.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              alignment: Alignment.center,
              child: Icon(type.icon, size: 16, color: type.color),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                type.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The list of people who can be added to the group.
class _MemberPicker extends StatelessWidget {
  final bool isLoading;
  final bool hasAnyUsers;
  final List<Member> users;
  final Map<String, bool> selected;
  final void Function(String id, bool value) onToggle;

  const _MemberPicker({
    required this.isLoading,
    required this.hasAnyUsers,
    required this.users,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        children: const [
          SkeletonCard(),
          SizedBox(height: AppSpacing.xs),
          SkeletonCard(),
        ],
      );
    }

    if (users.isEmpty) {
      return PSCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: EmptyStateWidget(
          iconData: hasAnyUsers
              ? Icons.search_off_rounded
              : Icons.person_add_alt_rounded,
          title: hasAnyUsers ? 'No matches' : 'No one to add yet',
          subtitle: hasAnyUsers
              ? 'Try a different name or email.'
              : 'Create the group and share the invite link instead.',
          compact: true,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < users.length; i++) ...[
            _row(users[i]),
            if (i != users.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 58),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(Member user) {
    final isOn = selected[user.id] ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onToggle(user.id, !isOn),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            children: [
              AvatarWidget.forName(user.name, size: 38),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (user.email.isNotEmpty)
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              Checkbox(
                value: isOn,
                onChanged: (v) => onToggle(user.id, v ?? false),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                side:
                    const BorderSide(color: AppColors.borderStrong, width: 1.5),
                activeColor: AppColors.primaryAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
