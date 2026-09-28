import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const Color _seedColor = Color(0xFF6366F1); // Brand Indigo

  // Reactive notifier for theme mode changes across the app
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static const String _themePrefKey = 'is_dark_mode';

  /// Initialize theme mode from SharedPreferences on app launch
  static Future<void> initializeTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_themePrefKey) ?? false;
      themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      themeModeNotifier.value = ThemeMode.light;
    }
  }

  /// Toggle theme between light and dark, persisting to SharedPreferences
  static Future<void> toggleTheme() async {
    final nextMode =
        themeModeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    themeModeNotifier.value = nextMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePrefKey, nextMode == ThemeMode.dark);
    } catch (_) {}
  }

  /// Check if the current app state is in dark mode
  static bool isDark(BuildContext context) {
    if (themeModeNotifier.value == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return themeModeNotifier.value == ThemeMode.dark;
  }

  // ---------------- LIGHT THEME ----------------
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: const Color(0xFF0F172A),
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFAFAFC),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFF1F5F9),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF6366F1),
        selectionColor: Color(0xFFC7D2FE),
        selectionHandleColor: Color(0xFF6366F1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: Color(0xFF334155),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2.0),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE0E7FF),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Color(0xFF4338CA),
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            );
          }
          return const TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          );
        }),
      ),
    );
  }

  // ---------------- DARK THEME ----------------
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF1E293B), // Slate 800
      onSurface: const Color(0xFFF8FAFC), // Slate 50
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
      cardColor: const Color(0xFF1E293B), // Slate 800
      dividerColor: const Color(0xFF334155), // Slate 700
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF818CF8),
        selectionColor: Color(0xFF3730A3),
        selectionHandleColor: Color(0xFF818CF8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        labelStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2.0),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E293B),
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF312E81),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Color(0xFFA5B4FC),
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            );
          }
          return const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          );
        }),
      ),
    );
  }
}
