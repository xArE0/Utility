import 'logbook_entities.dart';

abstract class ILogbookRepository {
  Future<void> init();
  Future<List<LogEntry>> getAllEntries();
  Future<int> insertEntry(LogEntry entry);
  Future<void> updateEntry(LogEntry entry);
  Future<void> deleteEntry(int id);
  Future<int> insertCheckpoint(LogCheckpoint checkpoint);
  Future<List<LogCheckpoint>> getCheckpoints(int entryId);
  Future<void> deleteCheckpoint(int id);
  Future<void> dispose();
}
