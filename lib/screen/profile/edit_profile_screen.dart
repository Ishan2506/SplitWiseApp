import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../state/state_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';

/// Edit the signed-in user's profile: name, phone and preferred currency.
///
/// Saving sends only the fields that actually changed, so an untouched phone
/// number is never re-submitted — the server rejects a duplicate mobile even
/// when it belongs to the same account.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  /// The values we started from, used to send only what changed.
  late final String _initialName;
  late final String _initialPhone;

  @override
  void initState() {
    super.initState();
    final user = context.read<StateManager>().currentUserModel;

    _initialName = user?.name ?? '';
    _initialPhone = user?.mobileNumber ?? '';

    _nameController = TextEditingController(text: _initialName);
    _phoneController = TextEditingController(text: _initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _nameController.text.trim() != _initialName ||
      _phoneController.text.trim() != _initialPhone;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    final state = context.read<StateManager>();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    final result = await state.updateProfile(
      name: name != _initialName ? name : null,
      // Unchanged fields are passed as null and dropped from the request, so
      // an untouched number is never re-submitted (the server rejects a
      // duplicate mobile even when it is the user's own). A cleared field
      // still sends '', which is what removes the number.
      mobileNumber: phone != _initialPhone ? phone : null,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      showAppSnack(context, 'Profile updated');
      Navigator.pop(context);
    } else {
      showAppSnack(
        context,
        (result['message'] ?? 'Could not update your profile').toString(),
        success: false,
      );
    }
  }

  /// Asks where to take the photo from, then uploads it.
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      // Downscaling here keeps the upload well under the server's 5MB cap and
      // avoids sending a 12MP photo to render a 84px circle.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final result = await context.read<StateManager>().uploadAvatar(
            bytes: bytes,
            filename: picked.name,
          );

      if (!mounted) return;
      if (result['success'] == true) {
        showAppSnack(context, 'Photo updated');
      } else {
        showAppSnack(
          context,
          (result['message'] ?? 'Could not upload the photo').toString(),
          success: false,
        );
      }
    } catch (e) {
      // A denied camera/gallery permission surfaces here.
      if (mounted) {
        showAppSnack(context, 'Could not open that source', success: false);
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _confirmRemovePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text(
            'Your avatar will go back to showing your initials.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    final result = await context.read<StateManager>().removeAvatar();
    if (!mounted) return;
    setState(() => _isUploadingPhoto = false);

    showAppSnack(
      context,
      result['success'] == true
          ? 'Photo removed'
          : (result['message'] ?? 'Could not remove the photo').toString(),
      success: result['success'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateManager>();
    final name = state.currentUser.name;
    final photoUrl = state.currentUserModel?.avatarUrl ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  Center(
                    child: _AvatarPicker(
                      // Falls back to the name-generated avatar when there is
                      // no photo, and follows the name as it is typed.
                      name: _nameController.text.trim().isEmpty
                          ? name
                          : _nameController.text.trim(),
                      photoUrl: photoUrl,
                      isBusy: _isUploadingPhoto,
                      onTap: _isUploadingPhoto ? null : _pickPhoto,
                    ),
                  ),
                  if (photoUrl.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: TextButton(
                        onPressed:
                            _isUploadingPhoto ? null : _confirmRemovePhoto,
                        child: const Text('Remove photo'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  PSTextField(
                    label: 'Full name',
                    placeholder: 'Your name',
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Your name cannot be empty'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  PSTextField(
                    label: 'Phone (optional)',
                    placeholder: '9876543210',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    prefixText: '+91 ',
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => setState(() {}),
                    // Matches the server's rule: a 10-digit Indian mobile
                    // starting 6-9, or nothing at all.
                    validator: (val) {
                      final v = (val ?? '').trim();
                      if (v.isEmpty) return null;
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                        return 'Enter a 10-digit number starting with 6-9';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  const SizedBox(height: AppSpacing.md),

                  PSButton(
                    label: 'Save changes',
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
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

/// The profile photo with a camera badge, tappable to change it.
class _AvatarPicker extends StatelessWidget {
  final String name;
  final String photoUrl;
  final bool isBusy;
  final VoidCallback? onTap;

  const _AvatarPicker({
    required this.name,
    required this.photoUrl,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: photoUrl.isEmpty ? 'Add a profile photo' : 'Change profile photo',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AvatarWidget.forName(
                name,
                size: 96,
                showBorder: true,
                imageUrl: photoUrl.isEmpty ? null : photoUrl,
              ),
              if (isBusy)
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgPrimary, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
