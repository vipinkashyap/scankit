import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App settings state
class AppSettings {
  final bool hapticFeedback;
  final bool saveToHistory;
  final bool autoOpenUrls;
  final ThemeMode themeMode;
  final String defaultOverlay; // 'standard', 'animated', 'glass'

  const AppSettings({
    this.hapticFeedback = true,
    this.saveToHistory = true,
    this.autoOpenUrls = false,
    this.themeMode = ThemeMode.system,
    this.defaultOverlay = 'standard',
  });

  AppSettings copyWith({
    bool? hapticFeedback,
    bool? saveToHistory,
    bool? autoOpenUrls,
    ThemeMode? themeMode,
    String? defaultOverlay,
  }) {
    return AppSettings(
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      saveToHistory: saveToHistory ?? this.saveToHistory,
      autoOpenUrls: autoOpenUrls ?? this.autoOpenUrls,
      themeMode: themeMode ?? this.themeMode,
      defaultOverlay: defaultOverlay ?? this.defaultOverlay,
    );
  }
}

/// Provider for app settings
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setHapticFeedback(bool value) {
    state = state.copyWith(hapticFeedback: value);
  }

  void setSaveToHistory(bool value) {
    state = state.copyWith(saveToHistory: value);
  }

  void setAutoOpenUrls(bool value) {
    state = state.copyWith(autoOpenUrls: value);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setDefaultOverlay(String overlay) {
    state = state.copyWith(defaultOverlay: overlay);
  }
}

/// Provider for theme mode (convenience)
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});
