import 'package:flutter/material.dart';

import 'app_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.profile,
    required this.isWide,
    required this.onBack,
    super.key,
  });

  final AppProfile profile;
  final bool isWide;
  final VoidCallback onBack;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isCardHovered = false;
  bool _isAvatarHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(widget.isWide ? 24 : 16, 8, 24, 8),
          child: Row(
            children: [
              IconButton(
                key: const Key('profile-back'),
                tooltip: 'Back to home',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Text(
                'About Profile',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, child) {
                    return Opacity(
                      opacity: progress,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - progress)),
                        child: child,
                      ),
                    );
                  },
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _isCardHovered = true),
                    onExit: (_) => setState(() => _isCardHovered = false),
                    child: AnimatedContainer(
                      key: const Key('profile-page-card'),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(
                              alpha: _isCardHovered ? 0.16 : 0.05,
                            ),
                            blurRadius: _isCardHovered ? 36 : 18,
                            offset: Offset(0, _isCardHovered ? 16 : 8),
                          ),
                        ],
                      ),
                      child: AnimatedScale(
                        scale: _isCardHovered ? 1.008 : 1,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: Card(
                          margin: EdgeInsets.zero,
                          color: colors.surfaceContainerLow,
                          elevation: _isCardHovered ? 4 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                            side: BorderSide(
                              color: _isCardHovered
                                  ? colors.primary.withValues(alpha: 0.35)
                                  : colors.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(widget.isWide ? 36 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 20,
                                  runSpacing: 16,
                                  children: [
                                    MouseRegion(
                                      onEnter: (_) => setState(
                                        () => _isAvatarHovered = true,
                                      ),
                                      onExit: (_) => setState(
                                        () => _isAvatarHovered = false,
                                      ),
                                      child: AnimatedScale(
                                        scale: _isAvatarHovered ? 1.06 : 1,
                                        duration: const Duration(
                                          milliseconds: 260,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        child: ClipOval(
                                          child: Image.network(
                                            widget.profile.profilePictureUrl,
                                            width: 112,
                                            height: 112,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    width: 112,
                                                    height: 112,
                                                    color:
                                                        colors.primaryContainer,
                                                    child: Icon(
                                                      Icons.person_rounded,
                                                      size: 64,
                                                      color: colors
                                                          .onPrimaryContainer,
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Username',
                                          style: textTheme.labelLarge?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.profile.displayName,
                                          style: textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'Local information',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final useTwoColumns =
                                        constraints.maxWidth >= 520;
                                    final entries = [
                                      (
                                        icon: Icons.desktop_windows_rounded,
                                        label: 'Platform',
                                        value: Theme.of(context).platform.name,
                                      ),
                                      (
                                        icon: Icons.apps_rounded,
                                        label: 'App',
                                        value: "Reyaansh's Things",
                                      ),
                                    ];

                                    final cards = entries
                                        .map(
                                          (entry) => _LocalInfoCard(
                                            icon: entry.icon,
                                            label: entry.label,
                                            value: entry.value,
                                          ),
                                        )
                                        .toList();

                                    if (useTwoColumns) {
                                      return GridView.count(
                                        crossAxisCount: 2,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 2.8,
                                        children: cards,
                                      );
                                    }

                                    return Column(
                                      children: [
                                        for (
                                          var i = 0;
                                          i < cards.length;
                                          i++
                                        ) ...[
                                          cards[i],
                                          if (i != cards.length - 1)
                                            const SizedBox(height: 12),
                                        ],
                                      ],
                                    );
                                  },
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
        ),
      ],
    );
  }
}

class _LocalInfoCard extends StatefulWidget {
  const _LocalInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  State<_LocalInfoCard> createState() => _LocalInfoCardState();
}

class _LocalInfoCardState extends State<_LocalInfoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        constraints: const BoxConstraints(minHeight: 92),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        transform: Matrix4.diagonal3Values(
          _isHovered ? 1.015 : 1,
          _isHovered ? 1.015 : 1,
          1,
        ),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isHovered
              ? colors.primaryContainer.withValues(alpha: 0.45)
              : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? colors.primary.withValues(alpha: 0.55)
                : colors.outlineVariant,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _isHovered ? colors.primary : colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: _isHovered
                    ? colors.onPrimary
                    : colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
