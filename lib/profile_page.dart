import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_profile.dart';
import 'supabase_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.profile,
    required this.isWide,
    required this.service,
    required this.onBack,
    required this.onProfileUpdated,
    required this.onSignOut,
    super.key,
  });

  final AppProfile profile;
  final bool isWide;
  final SupabaseService service;
  final VoidCallback onBack;
  final ValueChanged<AppProfile> onProfileUpdated;
  final Future<void> Function() onSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _usernameController;
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarMimeType;
  String? _errorMessage;
  bool _isSaving = false;
  bool _isPickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.profile.displayName,
    );
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.displayName != widget.profile.displayName) {
      _usernameController.text = widget.profile.displayName;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() {
      _isPickingAvatar = true;
      _errorMessage = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size > 5 * 1024 * 1024) {
        throw const FormatException('Choose an image smaller than 5 MB.');
      }
      final mimeType = _imageMimeType(file.extension);
      if (file.bytes == null || file.bytes!.isEmpty || mimeType == null) {
        throw const FormatException('Choose a readable JPG, PNG, or WebP image.');
      }
      setState(() {
        _avatarBytes = file.bytes;
        _avatarFileName = file.name;
        _avatarMimeType = mimeType;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.length > 32) {
      setState(
        () => _errorMessage = 'Username must be between 1 and 32 characters.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final profile = await widget.service.updateProfile(
        username: username,
        avatarBytes: _avatarBytes,
        avatarFileName: _avatarFileName,
        avatarMimeType: _avatarMimeType,
      );
      widget.onProfileUpdated(profile);
      if (mounted) {
        setState(() {
          _avatarBytes = null;
          _avatarFileName = null;
          _avatarMimeType = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in with your email and password.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut == true) await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ImageProvider<Object>? avatar = _avatarBytes != null
        ? MemoryImage(_avatarBytes!)
        : widget.profile.profilePictureUrl == null
        ? null
        : NetworkImage(widget.profile.profilePictureUrl!);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(widget.isWide ? 24 : 16, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                key: const Key('profile-back'),
                tooltip: 'Back to home',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'My Profile',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              widget.isWide ? 24 : 16,
              8,
              widget.isWide ? 24 : 16,
              24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Card(
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(widget.isWide ? 36 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: colors.primaryContainer,
                              child: avatar == null
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: 48,
                                      color: colors.onPrimaryContainer,
                                    )
                                  : ClipOval(
                                      child: Image(
                                        image: avatar,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                                  Icons.person_rounded,
                                                  size: 48,
                                                  color: colors
                                                      .onPrimaryContainer,
                                                ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.profile.displayName,
                                    style: textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Signed in with Supabase',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _isPickingAvatar
                                        ? null
                                        : _pickAvatar,
                                    icon: _isPickingAvatar
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.upload_rounded),
                                    label: const Text('Upload profile photo'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _usernameController,
                          maxLength: 32,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: colors.error),
                          ),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Save profile'),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Account information',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _InfoChip(
                              icon: Icons.verified_user_outlined,
                              label: 'Supabase account',
                            ),
                            _InfoChip(
                              icon: Icons.desktop_windows_rounded,
                              label: Theme.of(context).platform.name,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

String? _imageMimeType(String? extension) {
  return switch (extension?.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => null,
  };
}
