import 'package:flutter/material.dart';

import 'app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.isWide,
    required this.settings,
    required this.onBack,
    super.key,
  });

  final bool isWide;
  final AppSettingsController settings;
  final VoidCallback onBack;

  static const themeColors = <Color>[
    AppSettingsController.defaultSeedColor,
    Color(0xFF2563EB),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFEAB308),
    Color(0xFFEA580C),
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            child: Row(
              children: [
                if (!isWide)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingsSection(
                        title: 'Appearance',
                        icon: Icons.palette_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme mode',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                  icon: Icon(Icons.light_mode_outlined),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                  icon: Icon(Icons.dark_mode_outlined),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('System'),
                                  icon: Icon(Icons.settings_suggest_outlined),
                                ),
                              ],
                              selected: {settings.themeMode},
                              onSelectionChanged: (selection) =>
                                  settings.setThemeMode(selection.first),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Theme color',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final color in themeColors)
                                  _ColorChoice(
                                    color: color,
                                    selected:
                                        settings.seedColor.toARGB32() ==
                                        color.toARGB32(),
                                    onTap: () => settings.setSeedColor(color),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Background style',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<BackgroundStyle>(
                              segments: const [
                                ButtonSegment(
                                  value: BackgroundStyle.gradient,
                                  label: Text('Gradient'),
                                  icon: Icon(Icons.gradient_outlined),
                                ),
                                ButtonSegment(
                                  value: BackgroundStyle.aurora,
                                  label: Text('Aurora'),
                                  icon: Icon(Icons.auto_awesome_outlined),
                                ),
                                ButtonSegment(
                                  value: BackgroundStyle.soft,
                                  label: Text('Soft'),
                                  icon: Icon(Icons.blur_circular_outlined),
                                ),
                              ],
                              selected: {settings.backgroundStyle},
                              onSelectionChanged: (selection) =>
                                  settings.setBackgroundStyle(selection.first),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Interface size',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<double>(
                              segments: const [
                                ButtonSegment(
                                  value: 0.90,
                                  label: Text('Compact'),
                                ),
                                ButtonSegment(
                                  value: 1.0,
                                  label: Text('Default'),
                                ),
                                ButtonSegment(
                                  value: 1.10,
                                  label: Text('Large'),
                                ),
                              ],
                              selected: {settings.interfaceScale},
                              onSelectionChanged: (selection) =>
                                  settings.setInterfaceScale(selection.first),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Corner radius',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Slider(
                              value: settings.cardRadius,
                              min: 8,
                              max: 28,
                              divisions: 4,
                              label: settings.cardRadius.round().toString(),
                              onChanged: settings.setCardRadius,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Background intensity',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Slider(
                              value: settings.backgroundIntensity,
                              min: 0.25,
                              max: 1.5,
                              divisions: 5,
                              label:
                                  '${(settings.backgroundIntensity * 100).round()}%',
                              onChanged: settings.setBackgroundIntensity,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Card elevation',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Slider(
                              value: settings.cardElevation,
                              min: 0,
                              max: 6,
                              divisions: 6,
                              label: settings.cardElevation.round().toString(),
                              onChanged: settings.setCardElevation,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CustomizationPreview(settings: settings),
                      const SizedBox(height: 12),
                      _SettingsSection(
                        title: 'Comfort',
                        icon: Icons.tune_rounded,
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(Icons.contrast_rounded),
                              title: const Text('High contrast'),
                              subtitle: const Text(
                                'Increase separation between interface colors',
                              ),
                              value: settings.highContrast,
                              onChanged: settings.setHighContrast,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(Icons.layers_outlined),
                              title: const Text('Tinted surfaces'),
                              subtitle: const Text(
                                'Use subtly colored cards and panels',
                              ),
                              value: settings.tintedSurfaces,
                              onChanged: settings.setTintedSurfaces,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: settings.reset,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset appearance settings'),
                      ),
                      const SizedBox(height: 24),
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _CustomizationPreview extends StatelessWidget {
  const _CustomizationPreview({required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: settings.cardElevation,
      margin: EdgeInsets.zero,
      color: settings.tintedSurfaces
          ? colors.surfaceContainerLow
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(settings.cardRadius),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(settings.cardRadius * 0.7),
              ),
              child: Icon(
                Icons.auto_awesome_outlined,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Live preview',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(onPressed: () {}, child: const Text('Preview')),
          ],
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
