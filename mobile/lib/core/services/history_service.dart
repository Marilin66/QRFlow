import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/history_entry.dart';

/// Historique local des analyses.
///
/// Sur les plateformes natives (Android, iOS, desktop), l'historique est
/// stocké dans une base SQLite (sqflite). Sur le web, sqflite n'a pas
/// d'implémentation : l'historique est conservé en mémoire pour la session,
/// ce qui évite de faire planter le démarrage de l'application.
class HistoryService extends ChangeNotifier {
  static const _dbName = 'qrflow_history.db';
  static const _table = 'history';

  Database? _db;
  List<HistoryEntry> _entries = [];

  /// Sur le web, aucune base SQLite n'est disponible : on utilise la mémoire.
  bool get _usesMemoryStore => kIsWeb;

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    if (_usesMemoryStore) {
      _entries = [];
      notifyListeners();
      return;
    }

    final path = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts INTEGER NOT NULL,
            type TEXT NOT NULL,
            raw TEXT NOT NULL,
            method TEXT NOT NULL,
            summary TEXT,
            action TEXT
          )
        ''');
      },
    );
    await _reload();
  }

  Future<void> _reload() async {
    final db = _db;
    if (db == null) return;
    final rows = await db.query(_table, orderBy: 'ts DESC');
    _entries = rows.map(HistoryEntry.fromMap).toList();
    notifyListeners();
  }

  /// Ajoute une analyse à l'historique.
  Future<void> add(HistoryEntry entry) async {
    final db = _db;
    if (db == null) {
      _entries.insert(
        0,
        HistoryEntry(
          id: DateTime.now().microsecondsSinceEpoch,
          timestamp: entry.timestamp,
          type: entry.type,
          raw: entry.raw,
          method: entry.method,
          summary: entry.summary,
          action: entry.action,
        ),
      );
      notifyListeners();
      return;
    }
    await db.insert(_table, entry.toMap());
    await _reload();
  }

  /// Recherche dans l'historique (type, contenu, résumé).
  List<HistoryEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries.where((e) {
      return e.type.toLowerCase().contains(q) ||
          e.raw.toLowerCase().contains(q) ||
          (e.summary?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// Enregistre l'action effectuée sur une entrée existante.
  Future<void> updateAction(int id, String action) async {
    final db = _db;
    if (db == null) {
      final index = _entries.indexWhere((e) => e.id == id);
      if (index != -1) {
        final e = _entries[index];
        _entries[index] = HistoryEntry(
          id: e.id,
          timestamp: e.timestamp,
          type: e.type,
          raw: e.raw,
          method: e.method,
          summary: e.summary,
          action: action,
        );
        notifyListeners();
      }
      return;
    }
    await db.update(_table, {'action': action}, where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  Future<void> delete(int id) async {
    final db = _db;
    if (db == null) {
      _entries.removeWhere((e) => e.id == id);
      notifyListeners();
      return;
    }
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  Future<void> clear() async {
    final db = _db;
    if (db == null) {
      _entries = [];
      notifyListeners();
      return;
    }
    await db.delete(_table);
    await _reload();
  }

  /// Supprime les entrées plus anciennes que [olderThan].
  Future<void> pruneOlderThan(Duration olderThan) async {
    final db = _db;
    if (db == null) {
      final limit = DateTime.now().subtract(olderThan).millisecondsSinceEpoch;
      _entries.removeWhere((e) => e.timestamp.millisecondsSinceEpoch < limit);
      notifyListeners();
      return;
    }
    final limit = DateTime.now().subtract(olderThan).millisecondsSinceEpoch;
    await db.delete(_table, where: 'ts < ?', whereArgs: [limit]);
    await _reload();
  }
}
