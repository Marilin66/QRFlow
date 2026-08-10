import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// État global de l'application, persisté dans [SharedPreferences].
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? 0];
    _confirmActions = _prefs.getBool(_kConfirmActions) ?? true;
    _warnSuspicious = _prefs.getBool(_kWarnSuspicious) ?? true;
    _keepHistory = _prefs.getBool(_kKeepHistory) ?? true;
    _retentionDays = _prefs.getInt(_kRetentionDays) ?? 90;
    _multiQr = _prefs.getBool(_kMultiQr) ?? true;
    _bubbleSize = _prefs.getDouble(_kBubbleSize) ?? 80.0;
    _bubbleOpacity = _prefs.getDouble(_kBubbleOpacity) ?? 0.90;
  }

  static const _kThemeMode = 'theme_mode';
  static const _kConfirmActions = 'confirm_actions';
  static const _kWarnSuspicious = 'warn_suspicious';
  static const _kKeepHistory = 'keep_history';
  static const _kRetentionDays = 'retention_days';
  static const _kMultiQr = 'multi_qr';
  static const _kBubbleSize = 'bubble_size';
  static const _kBubbleOpacity = 'bubble_opacity';

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;
  late bool _confirmActions;
  late bool _warnSuspicious;
  late bool _keepHistory;
  late int _retentionDays;
  late bool _multiQr;
  late double _bubbleSize;
  late double _bubbleOpacity;

  ThemeMode get themeMode => _themeMode;
  bool get confirmActions => _confirmActions;
  bool get warnSuspicious => _warnSuspicious;
  bool get keepHistory => _keepHistory;
  int get retentionDays => _retentionDays;
  bool get multiQr => _multiQr;
  double get bubbleSize => _bubbleSize;
  double get bubbleOpacity => _bubbleOpacity;

  set themeMode(ThemeMode value) {
    _themeMode = value;
    _prefs.setInt(_kThemeMode, value.index);
    notifyListeners();
  }

  set confirmActions(bool value) {
    _confirmActions = value;
    _prefs.setBool(_kConfirmActions, value);
    notifyListeners();
  }

  set warnSuspicious(bool value) {
    _warnSuspicious = value;
    _prefs.setBool(_kWarnSuspicious, value);
    notifyListeners();
  }

  set keepHistory(bool value) {
    _keepHistory = value;
    _prefs.setBool(_kKeepHistory, value);
    notifyListeners();
  }

  set retentionDays(int value) {
    _retentionDays = value;
    _prefs.setInt(_kRetentionDays, value);
    notifyListeners();
  }

  set multiQr(bool value) {
    _multiQr = value;
    _prefs.setBool(_kMultiQr, value);
    notifyListeners();
  }

  set bubbleSize(double value) {
    _bubbleSize = value;
    _prefs.setDouble(_kBubbleSize, value);
    notifyListeners();
  }

  set bubbleOpacity(double value) {
    _bubbleOpacity = value;
    _prefs.setDouble(_kBubbleOpacity, value);
    notifyListeners();
  }
}
