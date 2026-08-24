import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backs the Appearance setting on the profile screen.
///
/// Defaults to [ThemeMode.system] — the app should follow the phone unless the
/// person says otherwise, which is what every native app does.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(defaultMode);

  static const _key = 'appearance_mode';

  /// Flettra is dark by default, not dark as an option.
  ///
  /// The palette was chosen dark-first: the lime accent only works against a
  /// near-black ground, and the product is opened in a moving vehicle, often at
  /// night, often with a map on screen. Following the system would mean most
  /// people never see the app it was designed to be.
  ///
  /// Light remains available and is a real, legible theme — just not the
  /// starting point.
  static const ThemeMode defaultMode = ThemeMode.dark;

  /// Reads the stored preference. Safe to call before `runApp`; a failure here
  /// falls back to the default rather than blocking launch.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = _decode(prefs.getString(_key));
    } catch (_) {
      value = defaultMode;
    }
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == value) return;
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _encode(mode));
    } catch (_) {
      // Preference is cosmetic — losing it is not worth surfacing an error.
    }
  }

  static String label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        // No stored preference yet — a first launch gets Nightshift.
        _ => defaultMode,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

/// Single instance, read by [FlettraApp] and written by the Appearance setting.
final themeController = ThemeController();
