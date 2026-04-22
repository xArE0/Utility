import 'vault_entities.dart';

abstract class IVaultRepository {
  Future<void> init();
  Future<List<VaultItem>> getAllItems();
  Future<void> addItem(VaultItem item);
  Future<void> deleteItem(int id);
  Future<void> updateItem(VaultItem item);
  Future<List<VaultHistory>> getHistory(int vaultItemId);
  Future<void> addHistory(VaultHistory history);
  Future<void> dispose();
}
