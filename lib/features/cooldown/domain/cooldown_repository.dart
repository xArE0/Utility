import 'cooldown_entities.dart';

abstract class ICooldownRepository {
  Future<void> init();
  Future<List<CooldownItem>> getAllItems();
  Future<void> addItem(CooldownItem item);
  Future<void> updateItem(CooldownItem item);
  Future<void> deleteItem(int id);
  Future<List<CooldownCategory>> getAllCategories();
  Future<CooldownCategory> addCategory(CooldownCategory category);
  Future<void> updateCategory(CooldownCategory category);
  Future<void> deleteCategory(int id);
  Future<void> dispose();
}
