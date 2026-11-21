import 'package:flutter/material.dart';

import 'app_profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.profile, super.key});

  final AppProfile profile;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSidebarCollapsed = false;

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
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
                      ),
                    Expanded(
                      child: _HomeContent(
                        isWide: isWide,
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
  });

  final AppProfile profile;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  State<_ProfileSidebar> createState() => _ProfileSidebarState();
}

class _ProfileSidebarState extends State<_ProfileSidebar> {
  bool _isProfileHovered = false;

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
        border: Border(
          right: BorderSide(color: colors.outlineVariant),
        ),
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
          const Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.isCollapsed ? 8 : 16,
              12,
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
                child: AnimatedContainer(
                  key: const Key('sidebar-profile'),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.profile.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
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
        ],
      ),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent({required this.isWide});

  final bool isWide;

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  bool _isWorkCardHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (!widget.isWide)
          Align(
            alignment: Alignment.centerLeft,
            child: Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Open sidebar',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isWorkCardHovered = true),
                  onExit: (_) => setState(() => _isWorkCardHovered = false),
                  child: AnimatedContainer(
                    key: const Key('home-work-card'),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(
                            alpha: _isWorkCardHovered ? 0.18 : 0.05,
                          ),
                          blurRadius: _isWorkCardHovered ? 40 : 20,
                          offset: Offset(0, _isWorkCardHovered ? 16 : 8),
                        ),
                      ],
                    ),
                    child: AnimatedScale(
                      scale: _isWorkCardHovered ? 1.015 : 1,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: Card(
                        color: colors.surfaceContainerLow.withValues(
                          alpha: 0.94,
                        ),
                        elevation: _isWorkCardHovered ? 6 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                          side: BorderSide(
                            color: _isWorkCardHovered
                                ? colors.primary.withValues(alpha: 0.4)
                                : colors.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 48,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer.withValues(
                                    alpha: _isWorkCardHovered ? 0.9 : 0.55,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: AnimatedRotation(
                                    turns: _isWorkCardHovered ? 0.035 : 0,
                                    duration: const Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                    child: AnimatedScale(
                                      scale: _isWorkCardHovered ? 1.12 : 1,
                                      duration: const Duration(
                                        milliseconds: 320,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      child: Icon(
                                        Icons.construction_rounded,
                                        size: 44,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'This Page Is Work In Progress :>',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
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
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.pictureUrl,
    required this.radius,
  });

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
