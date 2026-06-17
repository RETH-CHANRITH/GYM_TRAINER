import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  static const _themeKey = 'settings.theme_mode';

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_themeKey) ?? true;
      state = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      // Fallback silently if shared preferences fail
    }
  }

  Future<void> toggleTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state == ThemeMode.dark) {
        state = ThemeMode.light;
        await prefs.setBool(_themeKey, false);
      } else {
        state = ThemeMode.dark;
        await prefs.setBool(_themeKey, true);
      }
    } catch (_) {
      // Toggle local state even if shared preferences fail
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
