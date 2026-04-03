import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../domain/pot_entities.dart';
import '../domain/pot_repository.dart';

class LocalPotRepository implements IPotRepository {
  Database? _db;

  @override
  Future<void> init() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'pottracker_session.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE IF NOT EXISTS session (key TEXT PRIMARY KEY, value TEXT)');
    });
  }

  @override
  Future<Map<String, dynamic>?> loadLatestSession() async {
    if (_db == null) return null;
    final rows = await _db!.query('session', where: 'key = ?', whereArgs: ['latest']);
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String;
    return jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> saveSession(List<Player> players, double ante, List<RoundRecord> history) async {
    if (_db == null) return;
    final map = {
      'players': players.map((p) => p.toMap()).toList(),
      'ante': ante,
      'history': history.map((r) => r.toMap()).toList(),
    };
    final jsonStr = jsonEncode(map);
    await _db!.insert(
      'session', 
      {'key': 'latest', 'value': jsonStr}, 
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
  }
}
