import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, dark, highContrast }

class ThemeController extends ChangeNotifier {
  ThemeController._internal();

  static final ThemeController _instance = ThemeController._internal();

  factory ThemeController() => _instance;

  static const String _preferenceKey = 'preferred_theme';

  final Map<AppTheme, ThemeData> _themes = {
    AppTheme.light: _buildTheme(
      brightness: Brightness.light,
      seed: const Color(0xFF3F51B5),
    ),
    AppTheme.dark: _buildTheme(
      brightness: Brightness.dark,
      seed: const Color(0xFF3F51B5),
    ),
    AppTheme.highContrast: _buildHighContrastTheme(),
  };

  AppTheme _currentTheme = AppTheme.light;
  SharedPreferences? _prefs;
  bool _initialized = false;

  AppTheme get currentTheme => _currentTheme;

  ThemeData get themeData => _themes[_currentTheme]!;

  Iterable<AppTheme> get availableThemes => _themes.keys;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getString(_preferenceKey);
    if (stored != null) {
      _currentTheme = AppTheme.values.firstWhere(
        (theme) => theme.name == stored,
        orElse: () => AppTheme.light,
      );
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_currentTheme == theme) {
      return;
    }

    _currentTheme = theme;
    notifyListeners();
    await _ensurePrefs();
    await _prefs?.setString(_preferenceKey, theme.name);
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color seed,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData.fromDefaults(
        brightness: brightness,
        secondaryColor: colorScheme.primary,
        labelStyle: TextStyle(color: colorScheme.onSurface),
      ),
    );
  }

  static ThemeData _buildHighContrastTheme() {
    const primary = Color(0xFF0A0A0A);
    const accent = Color(0xFF00B8D9);

    const highContrastScheme = ColorScheme(
      brightness: Brightness.light,
      primary: accent,
      onPrimary: Colors.black,
      secondary: Colors.black,
      onSecondary: Colors.white,
      error: Color(0xFFB00020),
      onError: Colors.white,
      background: Colors.white,
      onBackground: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
      primaryContainer: accent,
      onPrimaryContainer: Colors.black,
      secondaryContainer: Colors.black,
      onSecondaryContainer: Colors.white,
      tertiary: primary,
      onTertiary: Colors.white,
      tertiaryContainer: Colors.black,
      onTertiaryContainer: Colors.white,
      outline: Colors.black,
      outlineVariant: Color(0xFF3C3C3C),
      shadow: Colors.black,
      surfaceTint: accent,
      inverseSurface: Colors.black,
      onInverseSurface: Colors.white,
      inversePrimary: Colors.white,
      scrim: Colors.black,
      surfaceVariant: Colors.white,
      onSurfaceVariant: Colors.black,
      errorContainer: Color(0xFFFFCDD2),
      onErrorContainer: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: highContrastScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      textTheme: ThemeData(brightness: Brightness.light)
          .textTheme
          .apply(bodyColor: Colors.black, displayColor: Colors.black),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selectedColor: accent,
        disabledColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        labelStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
        brightness: Brightness.light,
      ),
    );
  }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
}
