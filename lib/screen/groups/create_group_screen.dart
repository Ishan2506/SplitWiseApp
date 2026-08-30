import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../model/group_model.dart';
import '../../network/api_service.dart';
import '../../state/group_provider.dart';
import '../../state/state_manager.dart';
import 'group_widgets.dart';

/// Creates a new group, or edits an existing one when [existing] is given.
///
/// Everything the group feature offers up front lives here: the type, a photo,
/// a description, the per-member balance limit, and the starting members.
class CreateGroupScreen extends StatefulWidget {
  final GroupModel? existing;

  const CreateGroupScreen({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _limitController = TextEditingController();

  GroupType _type = GroupType.friends;
  String _photoUrl = '';
  bool _limitEnabled = false;
  bool _saving = false;

  /// Users available to add, and the ones ticked.
  List<GroupMember> _people = [];
  final Set<String> _selectedIds = {};
  bool _loadingPeople = true;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _descriptionController.text = existing.description;
      _type = existing.type;
      _photoUrl = existing.photoUrl;
      _limitEnabled = existing.hasBalanceLimit;
      if (existing.hasBalanceLimit) {
        _limitController.text = existing.balanceLimit.toStringAsFixed(
          existing.balanceLimit.truncateToDouble() == existing.balanceLimit ? 0 : 2,
        );
      }
    }

    // Members can only be picked while creating; editing manages them on the
    // group's own members screen.
    if (widget.isEditing) {
      _loadingPeople = false;
    } else {
      _loadPeople();
    }
  }

  Future<void> _loadPeople() async {
    final result = await ApiService.searchUsers();
    if (!mounted) return;
    final currentUserId = context.read<StateManager>().currentUserId;
    setState(() {
      _people = result['success'] == true
          ? (result['users'] as List<GroupMember>)
              .where((u) => u.id != currentUserId)
              .toList()
          : [];
      _loadingPeople = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  /// Picks a photo and stores it inline as a data URI, which is what the API
  /// accepts for `photoUrl`. Images are downscaled first to keep it small.
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      // Keep well inside a sane document size.
      if (bytes.lengthInBytes > 900 * 1024) {
        showGroupSnack(context, 'That image is too large — pick a smaller one',
            success: false);
        return;
      }

      setState(() {
        _photoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (e) {
      if (mounted) {
        showGroupSnack(context, 'Could not open the picker: $e', success: false);
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GroupColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GroupColors.surfaceAlt,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library, color: GroupColors.accent),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: GroupColors.accent),
              title: const Text('Take a photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            if (_photoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: GroupColors.negative),
                title: const Text('Remove photo',
                    style: TextStyle(color: GroupColors.negative)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _photoUrl = '');
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final provider = context.read<GroupProvider>();
    final limit = _limitEnabled
        ? double.tryParse(_limitController.text.trim()) ?? 0.0
        : 0.0;

    final result = widget.isEditing
        ? await provider.updateGroup(
            groupId: widget.existing!.id,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            type: _type,
            photoUrl: _photoUrl,
            balanceLimit: limit,
          )
        : await provider.createGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            type: _type,
            photoUrl: _photoUrl,
            balanceLimit: limit,
            memberIds: _selectedIds.toList(),
          );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      final group = result['group'] as GroupModel;
      Navigator.pop(context, group);
      showGroupSnack(
        context,
        widget.isEditing
            ? 'Saved changes to "${group.name}"'
            : 'Created "${group.name}"',
      );
    } else {
      showGroupSnack(context, result['message'] ?? 'Something went wrong',
          success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GroupColors.background,
      appBar: AppBar(
        backgroundColor: GroupColors.surface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.isEditing ? 'Edit group' : 'New group',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _buildPhotoPicker(),
            const SizedBox(height: 24),
            _buildTypePicker(),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: groupFieldDecoration(
                label: 'Group name',
                hint: 'e.g. Goa Trip 2026',
                prefix: const Icon(Icons.label_outline, color: GroupColors.muted),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Give the group a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              maxLength: 280,
              textCapitalization: TextCapitalization.sentences,
              decoration: groupFieldDecoration(
                label: 'Description',
                hint: 'What is this group for?',
              ),
            ),
            const SizedBox(height: 8),
            _buildBalanceLimit(),
            if (!widget.isEditing) ...[
              const SizedBox(height: 24),
              _buildMemberPicker(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: GroupColors.primary,
                disabledBackgroundColor: GroupColors.surfaceAlt,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.isEditing ? 'Save changes' : 'Create group',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              GroupAvatar.raw(type: _type, photoUrl: _photoUrl, size: 96, radius: 24),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: GroupColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _showPhotoOptions,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.camera_alt,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _showPhotoOptions,
            child: Text(
              _photoUrl.isEmpty ? 'Add a group photo' : 'Change photo',
              style: const TextStyle(color: GroupColors.accent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Group type',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          _type.hint,
          style: const TextStyle(color: GroupColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: GroupType.values.map((type) {
            final selected = _type == type;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _type = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 100,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? type.color.withValues(alpha: 0.18)
                      : GroupColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? type.color : GroupColors.surfaceAlt,
                    width: selected ? 1.8 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(type.icon,
                        color: selected ? type.color : GroupColors.muted,
                        size: 24),
                    const SizedBox(height: 6),
                    Text(
                      type.label,
                      style: TextStyle(
                        color: selected ? type.color : GroupColors.muted,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBalanceLimit() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GroupColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: GroupColors.accent, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance limit',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Cap how much any one member can owe',
                      style: TextStyle(color: GroupColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _limitEnabled,
                activeThumbColor: GroupColors.primary,
                onChanged: (value) => setState(() => _limitEnabled = value),
              ),
            ],
          ),
          if (_limitEnabled) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _limitController,
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: groupFieldDecoration(
                label: 'Maximum owed per member',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 8),
                  child: Text('₹',
                      style: TextStyle(
                          color: GroupColors.muted, fontSize: 16)),
                ),
                helper:
                    'Expenses that push someone past this are blocked until they settle up.',
              ),
              validator: (value) {
                if (!_limitEnabled) return null;
                final parsed = double.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter an amount greater than zero';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Add members',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            if (_selectedIds.isNotEmpty)
              Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(color: GroupColors.accent, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'You can also invite people later with a link or QR code.',
          style: TextStyle(color: GroupColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (_loadingPeople)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: GroupColors.primary),
            ),
          )
        else if (_people.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GroupColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_add_alt, color: GroupColors.muted, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nobody else is on the app yet. Create the group and share '
                    'its invite link or QR code.',
                    style: TextStyle(color: GroupColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: GroupColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: _people.map((person) {
                final selected = _selectedIds.contains(person.id);
                return CheckboxListTile(
                  value: selected,
                  activeColor: GroupColors.primary,
                  checkColor: Colors.white,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: MemberAvatar(member: person, radius: 18),
                  title: Text(person.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14)),
                  subtitle: person.email != null
                      ? Text(person.email!,
                          style: const TextStyle(
                              color: GroupColors.muted, fontSize: 11))
                      : null,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedIds.add(person.id);
                      } else {
                        _selectedIds.remove(person.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
