import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/vault_entities.dart';
import '../domain/vault_repository.dart';

class DataVaultController extends ChangeNotifier {
  final IVaultRepository _repository;
  
  List<VaultItem> _items = [];
  final Set<int> _visibleIds = {}; 
  String _searchQuery = '';

  List<VaultItem> get items => _items;
  Set<int> get visibleIds => _visibleIds;
  String get searchQuery => _searchQuery;

  final List<String> categories = ['Passwords', 'IDs', 'Cards', 'Bank Accounts'];

  DataVaultController({required IVaultRepository repository}) : _repository = repository;

  set searchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> init() async {
    await _repository.init();
    await loadItems();
  }

  Future<void> loadItems() async {
    final data = await _repository.getAllItems();
    _items = data;
    notifyListeners();
  }

  void toggleVisibility(int id) {
    if (_visibleIds.contains(id)) {
      _visibleIds.remove(id);
    } else {
      _visibleIds.add(id);
    }
    notifyListeners();
  }

  Future<void> deleteItem(int id) async {
    await _repository.deleteItem(id);
    await loadItems();
  }

  Future<void> addItem(String label, String value, String category) async {
    final item = VaultItem(label: label, value: value, category: category);
    await _repository.addItem(item);
    await loadItems();
  }

  Future<void> updateItem(int id, String label, String value, String category) async {
    final item = VaultItem(id: id, label: label, value: value, category: category);
    await _repository.updateItem(item);
    await loadItems();
  }

  List<VaultItem> get filteredItems {
    return _items.where((item) {
      final label = item.label.toLowerCase();
      final category = item.category.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return label.contains(query) || category.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
