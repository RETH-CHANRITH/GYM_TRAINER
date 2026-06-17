import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccentColorPreset {
  blue('Blue', Color(0xFF2563EB), Color(0xFF3B82F6)),
  lime('Lime', Color(0xFF16A34A), Color(0xFFCBFF47)), // lime/green matching the screenshot
  purple('Purple', Color(0xFF896CFE), Color(0xFFA78BFA)),
  orange('Orange', Color(0xFFEA580C), Color(0xFFF97316)),
  red('Red', Color(0xFFDC2626), Color(0xFFEF4444)),
  teal('Teal', Color(0xFF0D9488), Color(0xFF14B8A6));

  final String name;
  final Color lightColor;
  final Color darkColor;
  const AccentColorPreset(this.name, this.lightColor, this.darkColor);

  Color color(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkColor : lightColor;
}

enum FontSizePreset {
  small('Small', 0.85),
  medium('Medium', 1.0),
  large('Large', 1.15),
  extraLarge('Extra Large', 1.30);

  final String name;
  final double scaleFactor;
  const FontSizePreset(this.name, this.scaleFactor);
}

class AppearanceState {
  final AccentColorPreset accentColor;
  final FontSizePreset fontSize;
  final bool dynamicMode;

  AppearanceState({
    this.accentColor = AccentColorPreset.lime, // default matching screenshot
    this.fontSize = FontSizePreset.medium,      // default matching screenshot
    this.dynamicMode = false,
  });

  AppearanceState copyWith({
    AccentColorPreset? accentColor,
    FontSizePreset? fontSize,
    bool? dynamicMode,
  }) {
    return AppearanceState(
      accentColor: accentColor ?? this.accentColor,
      fontSize: fontSize ?? this.fontSize,
      dynamicMode: dynamicMode ?? this.dynamicMode,
    );
  }
}

class AppearanceNotifier extends StateNotifier<AppearanceState> {
  AppearanceNotifier() : super(AppearanceState()) {
    _loadPreferences();
  }

  static const _accentKey = 'settings.accent_color';
  static const _fontKey = 'settings.font_size';
  static const _dynamicModeKey = 'settings.dynamic_mode';

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accentName = prefs.getString(_accentKey);
      final fontName = prefs.getString(_fontKey);
      final dynamicMode = prefs.getBool(_dynamicModeKey) ?? false;

      AccentColorPreset accent = AccentColorPreset.lime;
      if (accentName != null) {
        accent = AccentColorPreset.values.firstWhere(
          (e) => e.name == accentName || (e.name == 'Lime' && accentName == 'Green'),
          orElse: () => AccentColorPreset.lime,
        );
      }

      FontSizePreset fontSize = FontSizePreset.medium;
      if (fontName != null) {
        fontSize = FontSizePreset.values.firstWhere(
          (e) => e.name == fontName,
          orElse: () => FontSizePreset.medium,
        );
      }

      state = AppearanceState(
        accentColor: accent,
        fontSize: fontSize,
        dynamicMode: dynamicMode,
      );
    } catch (_) {}
  }

  Future<void> setAccentColor(AccentColorPreset preset) async {
    state = state.copyWith(accentColor: preset, dynamicMode: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, preset.name);
    await prefs.setBool(_dynamicModeKey, false);
  }

  Future<void> setFontSize(FontSizePreset preset) async {
    state = state.copyWith(fontSize: preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, preset.name);
  }

  Future<void> setDynamicMode(bool enabled) async {
    state = state.copyWith(dynamicMode: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dynamicModeKey, enabled);

    if (enabled) {
      // Dynamic mode picks Teal as placeholder system/wallpaper accent
      state = state.copyWith(accentColor: AccentColorPreset.teal);
      await prefs.setString(_accentKey, AccentColorPreset.teal.name);
    }
  }
}

final appearanceProvider = StateNotifierProvider<AppearanceNotifier, AppearanceState>((ref) {
  return AppearanceNotifier();
});
