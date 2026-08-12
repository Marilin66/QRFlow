import 'package:flutter/material.dart';

/// État global de l'application QRFlow (thème, et plus tard historique…).
class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }
}
