import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/vault_entities.dart';
import '../domain/vault_repository.dart';

class DataVaultController extends ChangeNotifier {
  final IVaultRepository _repository;
  
  List<VaultItem> _items = [];
  final Set<int> _visibleIds = {}; 
  final Set<int> _expandedIds = {};
  final Set<int> _historyExpandedIds = {};
  final Map<int, List<VaultHistory>> _historyCache = {};
  String _searchQuery = '';
  bool _showAllPasswords = false;
  bool _initialized = false;

  List<VaultItem> get items => _items;
  Set<int> get visibleIds => _visibleIds;
  Set<int> get expandedIds => _expandedIds;
  Set<int> get historyExpandedIds => _historyExpandedIds;
  String get searchQuery => _searchQuery;
  bool get showAllPasswords => _showAllPasswords;
  bool get initialized => _initialized;

  final List<String> categories = ['Passwords', 'IDs', 'Cards', 'Bank Accounts'];

  DataVaultController({required IVaultRepository repository}) : _repository = repository;

  set searchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> init() async {
    await _repository.init();
    await loadItems();
    _initialized = true;
    notifyListeners();
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

  void toggleExpand(int id) {
    if (_expandedIds.contains(id)) {
      _expandedIds.remove(id);
    } else {
      _expandedIds.add(id);
    }
    notifyListeners();
  }

  void toggleHistoryExpand(int id) {
    if (_historyExpandedIds.contains(id)) {
      _historyExpandedIds.remove(id);
    } else {
      _historyExpandedIds.add(id);
      // Load history on first expand
      if (!_historyCache.containsKey(id)) {
        loadHistory(id);
      }
    }
    notifyListeners();
  }

  void toggleShowAll() {
    _showAllPasswords = !_showAllPasswords;
    if (_showAllPasswords) {
      for (final item in _items) {
        if (item.id != null) _visibleIds.add(item.id!);
      }
    } else {
      _visibleIds.clear();
    }
    notifyListeners();
  }

  Future<void> loadHistory(int itemId) async {
    final history = await _repository.getHistory(itemId);
    _historyCache[itemId] = history;
    notifyListeners();
  }

  List<VaultHistory> getHistory(int itemId) {
    return _historyCache[itemId] ?? [];
  }

  Future<void> deleteItem(int id) async {
    await _repository.deleteItem(id);
    _visibleIds.remove(id);
    _expandedIds.remove(id);
    _historyExpandedIds.remove(id);
    _historyCache.remove(id);
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
    // Refresh history cache for this item
    _historyCache.remove(id);
    if (_historyExpandedIds.contains(id)) {
      await loadHistory(id);
    }
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
