import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/history_entry.dart';

/// Historique local des analyses, stocké dans SQLite.
class HistoryService extends ChangeNotifier {
  static const _dbName = 'qrflow_history.db';
  static const _table = 'history';

  Database? _db;
  List<HistoryEntry> _entries = [];

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
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
    if (db == null) return;
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
    if (db == null) return;
    await db.update(_table, {'action': action}, where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  Future<void> delete(int id) async {
    final db = _db;
    if (db == null) return;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  Future<void> clear() async {
    final db = _db;
    if (db == null) return;
    await db.delete(_table);
    await _reload();
  }

  /// Supprime les entrées plus anciennes que [olderThan].
  Future<void> pruneOlderThan(Duration olderThan) async {
    final db = _db;
    if (db == null) return;
    final limit = DateTime.now().subtract(olderThan).millisecondsSinceEpoch;
    await db.delete(_table, where: 'ts < ?', whereArgs: [limit]);
    await _reload();
  }
}
