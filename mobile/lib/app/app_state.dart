import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/history_entry.dart';
import '../core/services/history_service.dart';

/// État global de l'application QRFlow : thème, historique, préférences.
class AppState extends ChangeNotifier {
  static const String _kThemeMode = 'themeMode';
  static const String _kKeepHistory = 'keepHistory';

  final HistoryService historyService = HistoryService();

  ThemeMode _themeMode = ThemeMode.system;
  bool _keepHistory = true;
  List<HistoryEntry> _history = const [];
  bool _historyLoaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get keepHistory => _keepHistory;
  List<HistoryEntry> get history => _history;
  bool get historyLoaded => _historyLoaded;

  set themeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setString(
        _kThemeMode,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
    });
  }

  set keepHistory(bool value) {
    if (value == _keepHistory) return;
    _keepHistory = value;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((SharedPreferences prefs) => prefs.setBool(_kKeepHistory, value));
  }

  /// Chargement au démarrage (préférences puis historique). Résistant aux
  /// échecs (tests, persistance indisponible) : jamais de crash à l'init.
  Future<void> init() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _themeMode = switch (prefs.getString(_kThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _keepHistory = prefs.getBool(_kKeepHistory) ?? true;
    } catch (_) {
      // Persistance indisponible : valeurs par défaut.
    }
    try {
      await refreshHistory();
    } catch (_) {
      _history = const [];
      _historyLoaded = true;
    }
    notifyListeners();
  }

  Future<void> refreshHistory() async {
    _history = await historyService.getAll();
    _historyLoaded = true;
    notifyListeners();
  }

  /// Enregistre un scan dans l'historique (sauf si désactivé).
  Future<void> recordScan({
    required String type,
    required String source,
    required String raw,
  }) async {
    if (!_keepHistory) return;
    try {
      await historyService.add(
        HistoryEntry(
          date: DateTime.now(),
          type: type,
          source: source,
          raw: raw,
        ),
      );
      await refreshHistory();
    } catch (_) {
      // L'historique ne doit jamais faire échouer le flux de scan.
    }
  }

  Future<void> deleteEntry(int id) async {
    try {
      await historyService.delete(id);
      await refreshHistory();
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    try {
      await historyService.clear();
      await refreshHistory();
    } catch (_) {}
  }
}
