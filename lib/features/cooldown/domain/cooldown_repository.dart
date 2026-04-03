import 'cooldown_entities.dart';

abstract class ICooldownRepository {
  Future<void> init();
  Future<List<CooldownItem>> getAllItems();
  Future<void> addItem(CooldownItem item);
  Future<void> updateItem(CooldownItem item);
  Future<void> deleteItem(int id);
  Future<void> dispose();
}
