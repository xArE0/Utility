abstract class IExportImportRepository {
  Future<bool> exportDatabase(String dbName);
  Future<bool> importDatabase(String dbName);
  Future<bool> checkDatabaseExists(String dbName);

  /// Encrypts the vault DB with [password] and shares the .vault file.
  Future<bool> exportEncryptedVault(String dbName, String password);

  /// Decrypts a .vault file with [password] and overwrites the vault DB.
  Future<bool> importEncryptedVault(String dbName, String password);
}
