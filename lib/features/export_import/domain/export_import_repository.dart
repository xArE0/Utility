abstract class IExportImportRepository {
  Future<bool> exportDatabase(String dbName);
  Future<bool> importDatabase(String dbName);
  Future<bool> checkDatabaseExists(String dbName);
}
