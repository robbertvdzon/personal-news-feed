import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class AppearanceState {
  final bool fontSizeLarge;
  const AppearanceState({this.fontSizeLarge = false});

  double get textScale => fontSizeLarge ? 1.2 : 1.0;

  AppearanceState copyWith({bool? fontSizeLarge}) =>
      AppearanceState(fontSizeLarge: fontSizeLarge ?? this.fontSizeLarge);
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class AppearanceNotifier extends Notifier<AppearanceState> {
  static const _keyFontLarge = 'appearance_font_large';

  @override
  AppearanceState build() {
    _loadFromPrefs();
    return const AppearanceState();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final large = prefs.getBool(_keyFontLarge) ?? false;
    state = state.copyWith(fontSizeLarge: large);
  }

  Future<void> setFontSizeLarge(bool large) async {
    state = state.copyWith(fontSizeLarge: large);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFontLarge, large);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearanceState>(
  AppearanceNotifier.new,
);
