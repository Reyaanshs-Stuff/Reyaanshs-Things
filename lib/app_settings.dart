import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BackgroundStyle { gradient, aurora, soft }

class AppSettingsController extends ChangeNotifier {
  AppSettingsController() {
    _load();
  }

  static const _themeModeKey = 'theme_mode';
  static const _seedColorKey = 'seed_color';
  static const _reduceMotionKey = 'reduce_motion';
  static const _compactSidebarKey = 'compact_sidebar';
  static const _backgroundStyleKey = 'background_style';
  static const _interfaceScaleKey = 'interface_scale';
  static const _cardRadiusKey = 'card_radius';
  static const _highContrastKey = 'high_contrast';
  static const _backgroundIntensityKey = 'background_intensity';
  static const _cardElevationKey = 'card_elevation';
  static const _tintedSurfacesKey = 'tinted_surfaces';

  static const defaultSeedColor = Color(0xFF6750A4);

  ThemeMode themeMode = ThemeMode.system;
  Color seedColor = defaultSeedColor;
  bool reduceMotion = false;
  bool compactSidebar = false;
  BackgroundStyle backgroundStyle = BackgroundStyle.gradient;
  double interfaceScale = 1.0;
  double cardRadius = 18;
  bool highContrast = false;
  double backgroundIntensity = 1.0;
  double cardElevation = 1.0;
  bool tintedSurfaces = true;

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    themeMode = ThemeMode
        .values[preferences.getInt(_themeModeKey) ?? ThemeMode.system.index];
    seedColor = Color(
      preferences.getInt(_seedColorKey) ?? defaultSeedColor.toARGB32(),
    );
    reduceMotion = preferences.getBool(_reduceMotionKey) ?? false;
    compactSidebar = preferences.getBool(_compactSidebarKey) ?? false;
    backgroundStyle =
        BackgroundStyle.values[preferences.getInt(_backgroundStyleKey) ?? 0];
    interfaceScale = preferences.getDouble(_interfaceScaleKey) ?? 1.0;
    cardRadius = preferences.getDouble(_cardRadiusKey) ?? 18;
    highContrast = preferences.getBool(_highContrastKey) ?? false;
    backgroundIntensity = preferences.getDouble(_backgroundIntensityKey) ?? 1.0;
    cardElevation = preferences.getDouble(_cardElevationKey) ?? 1.0;
    tintedSurfaces = preferences.getBool(_tintedSurfacesKey) ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_themeModeKey, value.index);
  }

  Future<void> setSeedColor(Color value) async {
    seedColor = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_seedColorKey, value.toARGB32());
  }

  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_reduceMotionKey, value);
  }

  Future<void> setCompactSidebar(bool value) async {
    compactSidebar = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_compactSidebarKey, value);
  }

  Future<void> setBackgroundStyle(BackgroundStyle value) async {
    backgroundStyle = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_backgroundStyleKey, value.index);
  }

  Future<void> setInterfaceScale(double value) async {
    interfaceScale = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_interfaceScaleKey, value);
  }

  Future<void> setCardRadius(double value) async {
    cardRadius = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_cardRadiusKey, value);
  }

  Future<void> setHighContrast(bool value) async {
    highContrast = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_highContrastKey, value);
  }

  Future<void> setBackgroundIntensity(double value) async {
    backgroundIntensity = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_backgroundIntensityKey, value);
  }

  Future<void> setCardElevation(double value) async {
    cardElevation = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_cardElevationKey, value);
  }

  Future<void> setTintedSurfaces(bool value) async {
    tintedSurfaces = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_tintedSurfacesKey, value);
  }

  Future<void> reset() async {
    themeMode = ThemeMode.system;
    seedColor = defaultSeedColor;
    reduceMotion = false;
    compactSidebar = false;
    backgroundStyle = BackgroundStyle.gradient;
    interfaceScale = 1.0;
    cardRadius = 18;
    highContrast = false;
    backgroundIntensity = 1.0;
    cardElevation = 1.0;
    tintedSurfaces = true;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_themeModeKey);
    await preferences.remove(_seedColorKey);
    await preferences.remove(_reduceMotionKey);
    await preferences.remove(_compactSidebarKey);
    await preferences.remove(_backgroundStyleKey);
    await preferences.remove(_interfaceScaleKey);
    await preferences.remove(_cardRadiusKey);
    await preferences.remove(_highContrastKey);
    await preferences.remove(_backgroundIntensityKey);
    await preferences.remove(_cardElevationKey);
    await preferences.remove(_tintedSurfacesKey);
  }

  ThemeData themeFor(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      cardTheme: CardThemeData(
        color: tintedSurfaces
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      visualDensity: VisualDensity(
        horizontal: (interfaceScale - 1) * 2,
        vertical: (interfaceScale - 1) * 2,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: cardElevation,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tintedSurfaces
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface,
        elevation: cardElevation,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
    );
  }
}
