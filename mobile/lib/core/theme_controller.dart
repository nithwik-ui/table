import 'dart:ui';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'storage.dart';

/// Centralized controller for SRU Timetable 3.1.4 Appearance (System / Light / Dark).
/// Persists user preference in v3 Hive storage and updates semantic design tokens immediately.
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Brightness? _testPlatformBrightnessOverride;

  /// Loads saved theme mode from persistent storage on startup.
  void init() {
    final saved = StorageService.getThemeMode();
    _themeMode = _parseMode(saved);
    _syncAppConstantsBrightness();
  }

  /// Updates the active theme mode and persists it immediately.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _syncAppConstantsBrightness();
    await StorageService.setThemeMode(_modeToString(mode));
    notifyListeners();
  }

  /// String representation ('system', 'light', 'dark')
  String get themeModeKey => _modeToString(_themeMode);
  String get themeModeString => themeModeKey;

  Future<void> setThemeModeFromString(String raw) => setThemeMode(_parseMode(raw));

  bool get isDark => isDarkEffective;

  /// Human-readable label ('System', 'Light', 'Dark')
  String get themeModeLabel {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Called when OS/system brightness changes so System mode updates live.
  void onPlatformBrightnessChanged() {
    _syncAppConstantsBrightness();
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

  /// For deterministic testing of System theme adaptation.
  @visibleForTesting
  void setTestPlatformBrightness(Brightness? brightness) {
    _testPlatformBrightnessOverride = brightness;
    _syncAppConstantsBrightness();
    notifyListeners();
  }

  bool get isDarkEffective {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    final platformBrightness =
        _testPlatformBrightnessOverride ?? PlatformDispatcher.instance.platformBrightness;
    return platformBrightness == Brightness.dark;
  }

  void _syncAppConstantsBrightness() {
    AppConstants.isDark = isDarkEffective;
  }

  static ThemeMode _parseMode(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
