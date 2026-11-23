import 'package:flutter/material.dart';

import 'about_page.dart';
import 'app_profile.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.profile, super.key});

  final AppProfile profile;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSidebarCollapsed = false;
  bool _showProfilePage = false;
  bool _showAboutPage = false;

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _openProfile() {
    setState(() {
      _showProfilePage = true;
      _showAboutPage = false;
    });
  }

  void _openAbout() {
    setState(() {
      _showProfilePage = false;
      _showAboutPage = true;
    });
  }

  void _closeProfile() {
    setState(() {
      _showProfilePage = false;
      _showAboutPage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final sidebarWidth = _isSidebarCollapsed ? 88.0 : 280.0;

        return Scaffold(
          drawer: isWide
              ? null
              : Drawer(
                  width: sidebarWidth,
                  child: SafeArea(
                    child: _ProfileSidebar(
                      profile: widget.profile,
                      isCollapsed: _isSidebarCollapsed,
                      onToggle: _toggleSidebar,
                      onHomeSelected: () {
                        Navigator.of(context).pop();
                        _closeProfile();
                      },
                      onProfileSelected: () {
                        Navigator.of(context).pop();
                        _openProfile();
                      },
                      onAboutSelected: () {
                        Navigator.of(context).pop();
                        _openAbout();
                      },
                    ),
                  ),
                ),
          body: Stack(
            children: [
              const Positioned.fill(child: _PageBackground()),
              SafeArea(
                child: Row(
                  children: [
                    if (isWide)
                      _ProfileSidebar(
                        profile: widget.profile,
                        isCollapsed: _isSidebarCollapsed,
                        onToggle: _toggleSidebar,
                        onHomeSelected: _closeProfile,
                        onProfileSelected: _openProfile,
                        onAboutSelected: _openAbout,
                      ),
                    Expanded(
                      child: _showProfilePage
                          ? ProfilePage(
                              profile: widget.profile,
                              isWide: isWide,
                              onBack: _closeProfile,
                            )
                          : _showAboutPage
                          ? AboutPage(
                              isWide: isWide,
                              onBack: _closeProfile,
                            )
                          : _HomeContent(
                              isWide: isWide,
                              profile: widget.profile,
                              onProfileSelected: _openProfile,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileSidebar extends StatefulWidget {
  const _ProfileSidebar({
    required this.profile,
    required this.isCollapsed,
    required this.onToggle,
    required this.onHomeSelected,
    required this.onProfileSelected,
    required this.onAboutSelected,
  });

  final AppProfile profile;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final VoidCallback onHomeSelected;
  final VoidCallback onProfileSelected;
  final VoidCallback onAboutSelected;

  @override
  State<_ProfileSidebar> createState() => _ProfileSidebarState();
}

class _ProfileSidebarState extends State<_ProfileSidebar> {
  bool _isProfileHovered = false;
  bool _isHomeHovered = false;
  bool _isAboutHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = widget.isCollapsed ? 88.0 : 280.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.96),
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        children: [
          Align(
            alignment: widget.isCollapsed
                ? Alignment.center
                : Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                tooltip: widget.isCollapsed
                    ? 'Expand sidebar'
                    : 'Collapse sidebar',
                onPressed: widget.onToggle,
                icon: AnimatedRotation(
                  turns: widget.isCollapsed ? 0.5 : 0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  child: const Icon(Icons.keyboard_double_arrow_left_rounded),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.isCollapsed ? 8 : 16,
              0,
              widget.isCollapsed ? 8 : 16,
              8,
            ),
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHomeHovered = true),
              onExit: (_) => setState(() => _isHomeHovered = false),
              child: Tooltip(
                message: 'Home',
                child: InkWell(
                  key: const Key('sidebar-home'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onHomeSelected,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    height: 48,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isCollapsed ? 8 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: _isHomeHovered
                          ? colors.primaryContainer.withValues(alpha: 0.8)
                          : colors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: widget.isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        AnimatedScale(
                          scale: _isHomeHovered ? 1.1 : 1,
                          duration: const Duration(milliseconds: 260),
                          child: Icon(
                            Icons.home_rounded,
                            color: _isHomeHovered
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        if (!widget.isCollapsed) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Home',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.isCollapsed ? 8 : 16,
              12,
              widget.isCollapsed ? 8 : 16,
              0,
            ),
            child: MouseRegion(
              onEnter: (_) => setState(() => _isAboutHovered = true),
              onExit: (_) => setState(() => _isAboutHovered = false),
              child: Tooltip(
                message: 'About App',
                child: InkWell(
                  key: const Key('sidebar-about'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onAboutSelected,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    height: 48,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isCollapsed ? 8 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: _isAboutHovered
                          ? colors.primaryContainer.withValues(alpha: 0.8)
                          : colors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: widget.isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        AnimatedScale(
                          scale: _isAboutHovered ? 1.1 : 1,
                          duration: const Duration(milliseconds: 260),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: _isAboutHovered
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        if (!widget.isCollapsed) ...[
                          const SizedBox(width: 12),
                          Text(
                            'About App',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.isCollapsed ? 8 : 16,
              8,
              widget.isCollapsed ? 8 : 16,
              20,
            ),
            child: MouseRegion(
              onEnter: (_) => setState(() => _isProfileHovered = true),
              onExit: (_) => setState(() => _isProfileHovered = false),
              child: Tooltip(
                message: widget.isCollapsed
                    ? 'My Profile: ${widget.profile.displayName}'
                    : 'My Profile',
                child: InkWell(
                  key: const Key('sidebar-profile'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: widget.onProfileSelected,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.all(widget.isCollapsed ? 8 : 12),
                    decoration: BoxDecoration(
                      color: _isProfileHovered
                          ? colors.primaryContainer.withValues(alpha: 0.8)
                          : colors.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _isProfileHovered
                          ? [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : const [],
                    ),
                    child: Row(
                      mainAxisAlignment: widget.isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        AnimatedScale(
                          scale: _isProfileHovered ? 1.08 : 1,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: _ProfileAvatar(
                            pictureUrl: widget.profile.profilePictureUrl,
                            radius: 24,
                          ),
                        ),
                        if (!widget.isCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'My Profile',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.profile.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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

class _HomeContent extends StatefulWidget {
  const _HomeContent({
    required this.isWide,
    required this.profile,
    required this.onProfileSelected,
  });

  final bool isWide;
  final AppProfile profile;
  final VoidCallback onProfileSelected;

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  bool _isWelcomeHovered = false;
  bool _isProfileHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
          child: Row(
            children: [
              if (!widget.isWide)
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Open sidebar',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu_rounded),
                  ),
                ),
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isWelcomeHovered = true),
                  onExit: (_) => setState(() => _isWelcomeHovered = false),
                  child: AnimatedContainer(
                    key: const Key('home-welcome-card'),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _isWelcomeHovered
                          ? [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.18),
                                blurRadius: 28,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : const [],
                    ),
                    child: AnimatedScale(
                      scale: _isWelcomeHovered ? 1.015 : 1,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: Card(
                        color: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnimatedScale(
                              key: const Key('home-welcome-title'),
                              scale: _isWelcomeHovered ? 1.025 : 1,
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                style: textTheme.titleLarge!.copyWith(
                                  color: _isWelcomeHovered
                                      ? colors.primary
                                      : colors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                                child: const Text(
                                  "Welcome To Reyaansh's Things :>",
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              MouseRegion(
                onEnter: (_) => setState(() => _isProfileHovered = true),
                onExit: (_) => setState(() => _isProfileHovered = false),
                child: Tooltip(
                  message: 'My Profile',
                  child: InkWell(
                    key: const Key('home-profile-avatar'),
                    borderRadius: BorderRadius.circular(30),
                    onTap: widget.onProfileSelected,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: _isProfileHovered
                            ? [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.24),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : const [],
                      ),
                      child: AnimatedScale(
                        scale: _isProfileHovered ? 1.1 : 1,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: _ProfileAvatar(
                          pictureUrl: widget.profile.profilePictureUrl,
                          radius: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.pictureUrl, required this.radius});

  final String pictureUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ClipOval(
      child: Image.network(
        pictureUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: radius * 2,
          height: radius * 2,
          color: colors.primaryContainer,
          child: Icon(
            Icons.person_rounded,
            size: radius,
            color: colors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            colors.primaryContainer.withValues(alpha: 0.4),
            colors.tertiaryContainer.withValues(alpha: 0.32),
          ],
        ),
      ),
    );
  }
}
