import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_profile.dart';
import 'supabase_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.service,
    required this.onAuthenticated,
    super.key,
  });

  final SupabaseService service;
  final ValueChanged<AppProfile> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarMimeType;
  String? _errorMessage;
  String? _informationMessage;
  bool _isSubmitting = false;
  bool _isPickingAvatar = false;
  bool _obscurePassword = true;

  Future<void> _copyError() async {
    final error = _errorMessage;
    if (error == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: error));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error copied to clipboard.')),
        );
      }
    } on Exception catch (copyError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not copy error: $copyError')),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() {
      _isPickingAvatar = true;
      _errorMessage = null;
    });
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final size = file.lengthSync() ?? await file.length();
      if (size == null || size > 5 * 1024 * 1024) {
        throw const FormatException('Choose an image smaller than 5 MB.');
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        throw const FormatException('The selected image could not be read.');
      }
      final mimeType = _imageMimeType(file.extension);
      if (mimeType == null) {
        throw const FormatException('Choose a JPG, PNG, or WebP image.');
      }
      setState(() {
        _avatarBytes = bytes;
        _avatarFileName = file.name;
        _avatarMimeType = mimeType;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  Future<void> _continue() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _errorMessage = 'Your password must be at least 6 characters.',
      );
      return;
    }
    if (username.length > 32) {
      setState(() => _errorMessage = 'Usernames can be up to 32 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _informationMessage = null;
    });
    try {
      final result = await widget.service.signInOrCreateAccount(
        email: email,
        password: password,
        username: username,
        avatarBytes: _avatarBytes,
        avatarFileName: _avatarFileName,
        avatarMimeType: _avatarMimeType,
      );
      if (result.profile != null) {
        widget.onAuthenticated(result.profile!);
      } else if (result.emailConfirmationRequired && mounted) {
        setState(() {
          _informationMessage =
              'Your account was created. Check your inbox for the email '
              'confirmation link, then sign in. You can add your profile photo '
              'after confirming.';
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surface,
                    colors.primaryContainer.withValues(alpha: 0.48),
                    colors.tertiaryContainer.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    color: colors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(color: colors.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  "Reyaansh's Things",
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Welcome back',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in, or create an account automatically if '
                            'your email is new.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _emailController,
                            key: const Key('login-email'),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            key: const Key('login-password'),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _usernameController,
                            key: const Key('login-username'),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _continue(),
                            maxLength: 32,
                            decoration: const InputDecoration(
                              labelText: 'Username (new accounts)',
                              helperText: 'Existing accounts keep their saved username.',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: colors.primaryContainer,
                                foregroundImage: _avatarBytes == null
                                    ? null
                                    : MemoryImage(_avatarBytes!),
                                child: _avatarBytes == null
                                    ? Icon(
                                        Icons.person_rounded,
                                        color: colors.onPrimaryContainer,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Profile photo',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Optional · JPG, PNG, or WebP · up to 5 MB',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                                label: Text(
                                  _avatarBytes == null ? 'Upload' : 'Change',
                                ),
                              ),
                            ],
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _MessageNotice(
                              message: _errorMessage!,
                              isError: true,
                              onCopy: _copyError,
                            ),
                          ],
                          if (_informationMessage != null) ...[
                            const SizedBox(height: 16),
                            _MessageNotice(message: _informationMessage!),
                          ],
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            key: const Key('login-continue'),
                            onPressed: _isSubmitting || _isPickingAvatar
                                ? null
                                : _continue,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              _isSubmitting ? 'Connecting…' : 'Continue',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your username and photo are used in channels and '
                            'messages. Never share your password.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
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
      ),
    );
  }
}

class _MessageNotice extends StatelessWidget {
  const _MessageNotice({
    required this.message,
    this.isError = false,
    this.onCopy,
  });

  final String message;
  final bool isError;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isError ? colors.errorContainer : colors.secondaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError
                    ? colors.onErrorContainer
                    : colors.onSecondaryContainer,
              ),
            ),
          ),
          if (isError && onCopy != null)
            IconButton(
              tooltip: 'Copy error',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
            ),
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
