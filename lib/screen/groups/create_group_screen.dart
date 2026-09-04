import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';

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

  String _selectedCategory = 'Trip';
  final List<String> _categories = [
    'Trip',
    'Flatmates',
    'Couple',
    'Event',
    'Office',
    'Other'
  ];

  bool _isLoading = false;
  final Map<String, bool> _selectedMembers = {};
  List<Member> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  void _loadAvailableUsers() {
    final state = Provider.of<StateManager>(context, listen: false);
    _availableUsers = state.members
        .where((m) => m.id != state.currentUserId)
        .toList();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final state = Provider.of<StateManager>(context, listen: false);
    final groupName = _groupNameController.text.trim();
    final memberIds = [
      state.currentUserId,
      ..._selectedMembers.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList()
    ];

    try {
      state.addGroup(
        groupName,
        _selectedCategory,
        memberIds,
        _selectedCategory,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryAccent,
            content: Text('Group created successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      backgroundColor: AppColors.bgSecondary,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with back button
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: AppColors.textPrimary,
                          onPressed: () => Navigator.pop(context),
                          iconSize: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Text(
                        'Create a group',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Group Name
                  Text(
                    'Group name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PSTextField(
                    label: '',
                    placeholder: 'Goa Trip 2026',
                    controller: _groupNameController,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter group name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Category
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = category);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.textPrimary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: isSelected
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Members Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Members',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Add from contacts
                        },
                        child: Text(
                          'Add from contacts',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Search Members
                  PSTextField(
                    label: '',
                    placeholder: 'Search name, email or phone',
                    controller: _searchController,
                    onChanged: (val) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Selected Members List
                  if (_availableUsers.isNotEmpty)
                    Column(
                      children: _availableUsers
                          .where((u) => _searchController.text.isEmpty ||
                              u.name.toLowerCase().contains(
                                  _searchController.text.toLowerCase()))
                          .map((member) {
                        final isSelected = _selectedMembers[member.id] ?? false;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMembers[member.id] = !isSelected;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primaryAccent.withValues(alpha: 0.2),
                                        AppColors.primaryAccent.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                  ),
                                  child: Center(
                                    child: Text(
                                      member.initials,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryAccent,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                // Member Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        member.email,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Status
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.inputBg,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    isSelected ? 'Added' : 'Add',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? AppColors.primaryAccent
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Create Button
                  PSButton(
                    label: 'Create group',
                    onPressed: _isLoading ? () {} : _createGroup,
                    isLoading: _isLoading,
                    isPrimary: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Text(
                      'You can add more members later',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
