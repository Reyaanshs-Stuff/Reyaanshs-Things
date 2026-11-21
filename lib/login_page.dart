import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.onStartUsing, super.key});

  final Future<void> Function(
    String displayName,
    String profilePictureUrl,
  ) onStartUsing;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _displayNameController = TextEditingController();
  final _profilePictureUrlController = TextEditingController();
  String? _profilePictureUrl;
  String? _displayNameError;
  String? _profilePictureError;
  bool _isProfilePictureHovered = false;
  bool _isStartButtonHovered = false;
  bool _isCardHovered = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _profilePictureUrlController.dispose();
    super.dispose();
  }

  bool _isValidPictureUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
  }

  void _onProfilePictureUrlChanged(String value) {
    final isValid = _isValidPictureUrl(value);
    setState(() {
      _profilePictureUrl = isValid ? value.trim() : null;
      if (_profilePictureError != null) {
        _profilePictureError = value.trim().isEmpty
            ? 'Enter a profile picture URL.'
            : isValid
                ? null
                : 'Enter a valid image URL.';
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _startUsing() async {
    final displayName = _displayNameController.text.trim();
    final hasDisplayName = displayName.isNotEmpty;
    final pictureUrl = _profilePictureUrlController.text.trim();
    final hasProfilePicture = _isValidPictureUrl(pictureUrl);

    setState(() {
      _displayNameError =
          hasDisplayName ? null : 'Enter a display name.';
      _profilePictureError = hasProfilePicture
          ? null
          : pictureUrl.isEmpty
              ? 'Enter a profile picture URL.'
              : 'Enter a valid image URL.';
    });

    if (!hasDisplayName || !hasProfilePicture) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      await widget.onStartUsing(displayName, pictureUrl);
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('Could not save your profile: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _setProfilePictureHovered(bool isHovered) {
    if (_isProfilePictureHovered == isHovered) return;
    setState(() {
      _isProfilePictureHovered = isHovered;
    });
  }

  void _setStartButtonHovered(bool isHovered) {
    if (_isStartButtonHovered == isHovered) return;
    setState(() {
      _isStartButtonHovered = isHovered;
    });
  }

  void _setCardHovered(bool isHovered) {
    if (_isCardHovered == isHovered) return;
    setState(() {
      _isCardHovered = isHovered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                    colors.primaryContainer.withValues(alpha: 0.45),
                    colors.tertiaryContainer.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -110,
            right: -70,
            child: _GlowOrb(
              size: 300,
              color: colors.primary.withValues(alpha: 0.09),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -90,
            child: _GlowOrb(
              size: 340,
              color: colors.tertiary.withValues(alpha: 0.08),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 36 : 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight > 48
                          ? constraints.maxHeight - 48
                          : 0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 480),
                          curve: Curves.easeOutCubic,
                          builder: (context, progress, child) => Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - progress)),
                              child: child,
                            ),
                          ),
                          child: _ProfileCard(
                            profilePictureUrl: _profilePictureUrl,
                            profilePictureUrlController:
                                _profilePictureUrlController,
                            displayNameController: _displayNameController,
                            displayNameError: _displayNameError,
                            profilePictureError: _profilePictureError,
                            isSaving: _isSaving,
                            isPictureHovered: _isProfilePictureHovered,
                            isStartButtonHovered: _isStartButtonHovered,
                            isCardHovered: _isCardHovered,
                            onProfilePictureUrlChanged:
                                _onProfilePictureUrlChanged,
                            onDisplayNameChanged: (value) {
                              if (_displayNameError != null &&
                                  value.trim().isNotEmpty) {
                                setState(() {
                                  _displayNameError = null;
                                });
                              }
                            },
                            onPictureHover: _setProfilePictureHovered,
                            onStartButtonHover: _setStartButtonHovered,
                            onCardHover: _setCardHovered,
                            onStartUsing: _startUsing,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profilePictureUrl,
    required this.profilePictureUrlController,
    required this.displayNameController,
    required this.displayNameError,
    required this.profilePictureError,
    required this.isSaving,
    required this.isPictureHovered,
    required this.isStartButtonHovered,
    required this.isCardHovered,
    required this.onProfilePictureUrlChanged,
    required this.onDisplayNameChanged,
    required this.onPictureHover,
    required this.onStartButtonHover,
    required this.onCardHover,
    required this.onStartUsing,
  });

  final String? profilePictureUrl;
  final TextEditingController profilePictureUrlController;
  final TextEditingController displayNameController;
  final String? displayNameError;
  final String? profilePictureError;
  final bool isSaving;
  final bool isPictureHovered;
  final bool isStartButtonHovered;
  final bool isCardHovered;
  final ValueChanged<String> onProfilePictureUrlChanged;
  final ValueChanged<String> onDisplayNameChanged;
  final ValueChanged<bool> onPictureHover;
  final ValueChanged<bool> onStartButtonHover;
  final ValueChanged<bool> onCardHover;
  final VoidCallback onStartUsing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => onCardHover(true),
      onExit: (_) => onCardHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(
                alpha: isCardHovered ? 0.14 : 0.04,
              ),
              blurRadius: isCardHovered ? 36 : 18,
              offset: Offset(0, isCardHovered ? 16 : 8),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          color: colors.surfaceContainerLow,
          elevation: isCardHovered ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width >= 700 ? 40 : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _BrandMark(size: 48),
                    const SizedBox(width: 14),
                    Text(
                      "Reyaansh's Things",
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Your profile',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                MouseRegion(
                  onEnter: (_) => onPictureHover(true),
                  onExit: (_) => onPictureHover(false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: isPictureHovered
                          ? colors.primaryContainer.withValues(alpha: 0.3)
                          : colors.surface,
                      border: Border.all(
                        color: profilePictureError != null
                            ? colors.error
                            : isPictureHovered
                                ? colors.primary
                                : colors.outlineVariant,
                        width: isPictureHovered ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      key: const Key('profile-picture-url'),
                      controller: profilePictureUrlController,
                      onChanged: onProfilePictureUrlChanged,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Profile picture URL',
                        hintText: 'https://example.com/image.jpg',
                        prefixIcon: Icon(
                          Icons.link_rounded,
                          color: isPictureHovered ? colors.primary : null,
                        ),
                        errorText: profilePictureError,
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                if (profilePictureUrl != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.94, end: 1).animate(
                            animation,
                          ),
                          child: child,
                        ),
                      ),
                      child: ClipOval(
                        key: ValueKey(profilePictureUrl),
                        child: Image.network(
                          profilePictureUrl!,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 68,
                            height: 68,
                            color: colors.primaryContainer,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  key: const Key('display-name'),
                  controller: displayNameController,
                  onChanged: onDisplayNameChanged,
                  onSubmitted: (_) => onStartUsing(),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    errorText: displayNameError,
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                MouseRegion(
                  onEnter: (_) => onStartButtonHover(true),
                  onExit: (_) => onStartButtonHover(false),
                  child: AnimatedScale(
                    scale: isStartButtonHovered && !isSaving ? 1.015 : 1,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    child: FilledButton.icon(
                      onPressed: isSaving ? null : onStartUsing,
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Start Using The App'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: colors.onPrimaryContainer,
        size: size * 0.55,
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
