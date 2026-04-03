import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:path/path.dart';
import '../domain/expense_entities.dart';
import '../domain/expense_repository.dart';

class LocalExpenseRepository implements IExpenseRepository {
  sqlite.Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;
    _db = await sqlite.openDatabase(
      join(await sqlite.getDatabasesPath(), 'expense_tracker.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
                      CREATE TABLE people (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT
                      )
                    ''');
        await db.execute('''
                      CREATE TABLE transactions (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        personId INTEGER,
                        amount REAL,
                        note TEXT,
                        dateTime TEXT,
                        FOREIGN KEY (personId) REFERENCES people (id)
                      )
                    ''');
      },
    );
  }

  @override
  Future<List<Person>> getAllPeople() async {
    if (_db == null) await init();
    final List<Map<String, dynamic>> peopleMap = await _db!.query('people');
    final List<Person> people = peopleMap.map((map) => Person.fromMap(map)).toList();

    for (var person in people) {
      final transactionsMap = await _db!.query(
          'transactions',
          where: 'personId = ?',
          whereArgs: [person.id],
          orderBy: 'dateTime DESC'
      );
      person.transactions.addAll(
          transactionsMap.map((map) => Transaction.fromMap(map))
      );
    }
    return people;
  }

  @override
  Future<void> addPerson(String name) async {
    if (_db == null) await init();
    await _db!.insert('people', {'name': name});
  }

  @override
  Future<void> deletePerson(int id) async {
    if (_db == null) await init();
    await _db!.delete(
      'transactions',
      where: 'personId = ?',
      whereArgs: [id],
    );
    await _db!.delete(
      'people',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> addTransaction(Transaction transaction) async {
    if (_db == null) await init();
    await _db!.insert('transactions', transaction.toMap());
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
