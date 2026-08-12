import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/history_entry.dart';

/// Historique local des scans, stocké en SQLite sur l'appareil.
class HistoryService {
  static const String _dbName = 'qrflow_history.db';

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final String path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            source TEXT NOT NULL,
            raw TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> add(HistoryEntry entry) async {
    final Database db = await _database;
    return db.insert('history', entry.toMap());
  }

  Future<List<HistoryEntry>> getAll() async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows =
        await db.query('history', orderBy: 'date DESC');
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<List<HistoryEntry>> search(String query) async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'history',
      where: 'raw LIKE ? OR type LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final Database db = await _database;
    await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final Database db = await _database;
    await db.delete('history');
  }
}
