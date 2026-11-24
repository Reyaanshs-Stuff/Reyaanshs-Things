import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_updater.dart';
import 'physics_chaos_board.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({required this.isWide, required this.onBack, super.key});

  final bool isWide;
  final VoidCallback onBack;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();
  bool _isPhysicsMode = false;
  int _logoTapCount = 0;

  void _handleLogoTap() {
    if (_isPhysicsMode) {
      setState(() {
        _isPhysicsMode = false;
        _logoTapCount = 0;
      });
      return;
    }

    _logoTapCount++;
    if (_logoTapCount >= 4) {
      setState(() {
        _isPhysicsMode = true;
        _logoTapCount = 0;
      });
    }
  }

  List<PhysicsElement> _buildPhysicsElements(
    BuildContext context,
    double availableWidth,
  ) {
    final colors = Theme.of(context).colorScheme;
    final cardWidth = math
        .min(280.0, math.max(200.0, availableWidth - 64))
        .toDouble();

    return [
      PhysicsElement(
        id: 'app-logo',
        size: const Size(120, 120),
        builder: (key) => _AppLogo(onTap: _handleLogoTap, tapTargetKey: key),
      ),
      PhysicsElement(
        id: 'app-name',
        size: Size(cardWidth, 72),
        builder: (key) => Card(
          key: key,
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: const Center(child: _AppName()),
        ),
      ),
      PhysicsElement(
        id: 'author',
        size: Size(cardWidth, 90),
        builder: (key) => _AboutInfoCard(
          key: key,
          label: 'Author',
          value: 'Reyaanshs-Stuff',
          leading: _OrganizationAvatar(colors: colors),
        ),
      ),
      PhysicsElement(
        id: 'website',
        size: Size(cardWidth, 90),
        builder: (key) => _AboutInfoCard(
          key: key,
          label: 'Website',
          value: 'reyaanshs-stuff.github.io',
          leading: _WebsiteIcon(colors: colors),
        ),
      ),
      PhysicsElement(
        id: 'version',
        size: Size(cardWidth, 90),
        builder: (key) => FutureBuilder<PackageInfo>(
          key: key,
          future: _packageInfoFuture,
          builder: (context, snapshot) {
            final version = snapshot.hasData
                ? _formatAppVersion(snapshot.data!)
                : snapshot.hasError
                ? 'Unable to load version'
                : 'Loading...';

            return _AboutInfoCard(
              label: 'Version',
              value: version,
              leading: _VersionIcon(colors: colors),
            );
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(widget.isWide ? 24 : 16, 8, 24, 8),
          child: Row(
            children: [
              IconButton(
                key: const Key('about-back'),
                tooltip: 'Back to home',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Text(
                'About App',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isPhysicsMode
              ? LayoutBuilder(
                  builder: (context, constraints) => PhysicsChaosBoard(
                    elements: _buildPhysicsElements(
                      context,
                      constraints.maxWidth,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    widget.isWide ? 24 : 16,
                    16,
                    widget.isWide ? 24 : 16,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 480),
                        curve: Curves.easeOutCubic,
                        builder: (context, progress, child) => Opacity(
                          opacity: progress,
                          child: Transform.translate(
                            offset: Offset(0.0, 16 * (1 - progress)),
                            child: child,
                          ),
                        ),
                        child: _AboutCard(
                          packageInfoFuture: _packageInfoFuture,
                          isWide: widget.isWide,
                          onLogoTap: _handleLogoTap,
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

class _AboutCard extends StatefulWidget {
  const _AboutCard({
    required this.packageInfoFuture,
    required this.isWide,
    required this.onLogoTap,
  });

  final Future<PackageInfo> packageInfoFuture;
  final bool isWide;
  final VoidCallback onLogoTap;

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  bool _isBrandHovered = false;
  final AppUpdater _updater = AppUpdater();
  bool _isCheckingForUpdates = false;
  bool _isDownloadingUpdate = false;
  bool _updateCheckFailed = false;
  double? _downloadProgress;
  String? _updateMessage;

  bool get _supportsApkUpdates =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_supportsApkUpdates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_checkForUpdates());
        }
      });
    } else {
      _updateMessage = 'In-app APK updates are available on Android.';
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingForUpdates || _isDownloadingUpdate || !_supportsApkUpdates) {
      return;
    }

    setState(() {
      _isCheckingForUpdates = true;
      _updateCheckFailed = false;
      _updateMessage = 'Checking GitHub Releases...';
    });

    try {
      final packageInfo = await widget.packageInfoFuture;
      final currentVersion = _formatAppVersion(packageInfo);
      final latestRelease = await _updater.fetchLatestRelease();

      if (!mounted) return;

      if (AppUpdater.compareVersions(latestRelease.version, currentVersion) >
          0) {
        setState(() {
          _updateMessage =
              'Version $currentVersion is outdated. Version '
              '${latestRelease.version} is available.';
        });

        final shouldDownload = await _showUpdateDialog(
          currentVersion: currentVersion,
          latestVersion: latestRelease.version,
        );
        if (shouldDownload && mounted) {
          await _downloadAndInstall(latestRelease);
        }
      } else {
        setState(() {
          _updateMessage = "You're up to date (v$currentVersion).";
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _updateCheckFailed = true;
          _updateMessage = 'Update check failed: ${_errorMessage(error)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingForUpdates = false);
      }
    }
  }

  Future<bool> _showUpdateDialog({
    required String currentVersion,
    required String latestVersion,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              Icons.system_update_alt_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
            title: const Text('Update available'),
            content: Text(
              'Your current version ($currentVersion) is outdated.\n\n'
              'Download the latest version ($latestVersion)? '
              'The APK will be saved temporarily, then Android will open '
              'the package installer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _downloadAndInstall(AppUpdateRelease release) async {
    setState(() {
      _isDownloadingUpdate = true;
      _downloadProgress = null;
      _updateCheckFailed = false;
      _updateMessage = 'Downloading version ${release.version}...';
    });

    try {
      await _updater.downloadAndInstall(
        release,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );
      if (mounted) {
        setState(() {
          _updateMessage =
              'Installer opened. Follow the prompts to install the update.';
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _updateCheckFailed = true;
          _updateMessage = 'Update download failed: ${_errorMessage(error)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingUpdate = false);
      }
    }
  }

  String _errorMessage(Exception error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.surfaceContainerLow,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.isWide ? 36 : 24),
        child: Column(
          children: [
            MouseRegion(
              key: const Key('about-brand-hover'),
              onEnter: (_) => setState(() => _isBrandHovered = true),
              onExit: (_) => setState(() => _isBrandHovered = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: _isBrandHovered
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : const [],
                ),
                child: AnimatedScale(
                  key: const Key('about-brand-scale'),
                  scale: _isBrandHovered ? 1.04 : 1.0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: Column(
                    children: [
                      _AppLogo(
                        onTap: widget.onLogoTap,
                        tapTargetKey: const Key('about-app-logo'),
                      ),
                      const SizedBox(height: 18),
                      const _AppName(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _AboutInfoCard(
              label: 'Author',
              value: 'Reyaanshs-Stuff',
              leading: _OrganizationAvatar(colors: colors),
            ),
            const SizedBox(height: 12),
            _AboutInfoCard(
              label: 'Website',
              value: 'reyaanshs-stuff.github.io',
              leading: _WebsiteIcon(colors: colors),
            ),
            const SizedBox(height: 12),
            FutureBuilder<PackageInfo>(
              future: widget.packageInfoFuture,
              builder: (context, snapshot) {
                final version = snapshot.hasData
                    ? _formatAppVersion(snapshot.data!)
                    : snapshot.hasError
                    ? 'Unable to load version'
                    : 'Loading...';

                return _AboutInfoCard(
                  label: 'Version',
                  value: version,
                  leading: _VersionIcon(colors: colors),
                );
              },
            ),
            const SizedBox(height: 16),
            _AboutUpdateCard(
              isAndroid: _supportsApkUpdates,
              isChecking: _isCheckingForUpdates,
              isDownloading: _isDownloadingUpdate,
              hasError: _updateCheckFailed,
              progress: _downloadProgress,
              message: _updateMessage,
              onCheckForUpdates: _checkForUpdates,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatAppVersion(PackageInfo packageInfo) {
  final buildNumber = packageInfo.buildNumber.trim();
  return buildNumber.isEmpty
      ? packageInfo.version
      : '${packageInfo.version}+$buildNumber';
}

class _AboutUpdateCard extends StatefulWidget {
  const _AboutUpdateCard({
    required this.isAndroid,
    required this.isChecking,
    required this.isDownloading,
    required this.hasError,
    required this.progress,
    required this.message,
    required this.onCheckForUpdates,
  });

  final bool isAndroid;
  final bool isChecking;
  final bool isDownloading;
  final bool hasError;
  final double? progress;
  final String? message;
  final VoidCallback onCheckForUpdates;

  @override
  State<_AboutUpdateCard> createState() => _AboutUpdateCardState();
}

class _AboutUpdateCardState extends State<_AboutUpdateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isBusy = widget.isChecking || widget.isDownloading;
    final statusColor = widget.hasError
        ? colors.error
        : colors.onSurfaceVariant;
    final statusIcon = widget.hasError
        ? Icons.error_outline_rounded
        : widget.message?.startsWith("You're up to date") == true
        ? Icons.check_circle_outline_rounded
        : Icons.info_outline_rounded;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _isHovered
                ? colors.primaryContainer.withValues(alpha: 0.45)
                : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered
                  ? colors.primary.withValues(alpha: 0.55)
                  : colors.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App updates',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.isAndroid
                              ? 'Check for the latest Android release'
                              : 'Android APK updates',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: widget.isAndroid && !isBusy
                      ? widget.onCheckForUpdates
                      : null,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          widget.isAndroid
                              ? Icons.refresh_rounded
                              : Icons.android_rounded,
                        ),
                  label: Text(
                    !widget.isAndroid
                        ? 'Android only'
                        : widget.isDownloading
                        ? 'Downloading update...'
                        : widget.isChecking
                        ? 'Checking for updates...'
                        : 'Check for updates',
                  ),
                ),
              ),
              if (widget.isDownloading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: widget.progress),
              ],
              if (widget.message != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(statusIcon, size: 18, color: statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.message!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: statusColor, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.onTap, required this.tapTargetKey});

  final VoidCallback onTap;
  final Key tapTargetKey;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: tapTargetKey,
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Image.asset(
            'web/icons/Icon-512.png',
            width: 112,
            height: 112,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _AppName extends StatelessWidget {
  const _AppName();

  @override
  Widget build(BuildContext context) {
    return Text(
      "Reyaansh's Things",
      key: const Key('about-app-name'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _OrganizationAvatar extends StatelessWidget {
  const _OrganizationAvatar({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.network(
        'https://avatars.githubusercontent.com/u/359068371?v=4',
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => CircleAvatar(
          radius: 22,
          backgroundColor: colors.primaryContainer,
          child: Text(
            'R',
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionIcon extends StatelessWidget {
  const _VersionIcon({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.sell_outlined, color: colors.onPrimaryContainer),
    );
  }
}

class _WebsiteIcon extends StatelessWidget {
  const _WebsiteIcon({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.language_outlined, color: colors.onPrimaryContainer),
    );
  }
}

class _AboutInfoCard extends StatefulWidget {
  const _AboutInfoCard({
    required this.label,
    required this.value,
    required this.leading,
    super.key,
  });

  final String label;
  final String value;
  final Widget leading;

  @override
  State<_AboutInfoCard> createState() => _AboutInfoCardState();
}

class _AboutInfoCardState extends State<_AboutInfoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          key: Key('about-info-${widget.label.toLowerCase()}'),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? colors.primaryContainer.withValues(alpha: 0.45)
                : colors.surface,
            borderRadius: BorderRadius.circular(18),
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
              widget.leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.value,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
