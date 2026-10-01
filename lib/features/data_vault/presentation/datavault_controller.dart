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
  String? _categoryFilter;
  bool _showAllPasswords = false;
  bool _initialized = false;

  List<VaultItem> get items => _items;
  Set<int> get visibleIds => _visibleIds;
  Set<int> get expandedIds => _expandedIds;
  Set<int> get historyExpandedIds => _historyExpandedIds;
  String get searchQuery => _searchQuery;

  /// The category the list is narrowed to; null shows all, grouped.
  String? get categoryFilter => _categoryFilter;
  bool get showAllPasswords => _showAllPasswords;
  bool get initialized => _initialized;

  final List<String> categories = ['Passwords', 'IDs', 'Cards', 'Bank Accounts'];

  DataVaultController({required IVaultRepository repository}) : _repository = repository;

  set searchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  set categoryFilter(String? value) {
    _categoryFilter = value;
    notifyListeners();
  }

  int countFor(String category) => _items.where((i) => i.category == category).length;

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
      _visibleIds.remove(id);
    } else {
      // Opened with the password still masked; the eye reveals it.
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

  /// Collapses and masks everything (used when the vault locks again).
  void hideAll() {
    _showAllPasswords = false;
    _expandedIds.clear();
    _visibleIds.clear();
    _historyExpandedIds.clear();
    notifyListeners();
  }

  void toggleShowAll() {
    _showAllPasswords = !_showAllPasswords;
    if (_showAllPasswords) {
      for (final item in _items) {
        if (item.id != null) {
          _expandedIds.add(item.id!);
          _visibleIds.add(item.id!);
        }
      }
    } else {
      _expandedIds.clear();
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

  Future<void> deleteHistory(int historyId, int vaultItemId) async {
    await _repository.deleteHistory(historyId);
    // Refresh the cache for this item
    await loadHistory(vaultItemId);
  }

  Future<void> deleteItem(int id) async {
    await _repository.deleteItem(id);
    _visibleIds.remove(id);
    _expandedIds.remove(id);
    _historyExpandedIds.remove(id);
    _historyCache.remove(id);
    await loadItems();
  }

   Future<void> addItem(
    String label,
    String value,
    String category, {
    String tags = '',
    String username = '',
    String website = '',
    String note = '',
    List<VaultCustomField> customFields = const [],
  }) async {
    final item = VaultItem(
      label: label,
      value: value,
      category: category,
      tags: tags,
      username: username,
      website: website,
      note: note,
      customFields: customFields,
    );
    await _repository.addItem(item);
    await loadItems();
  }

  Future<void> updateItem(
    int id,
    String label,
    String value,
    String category, {
    String tags = '',
    String username = '',
    String website = '',
    String note = '',
    List<VaultCustomField> customFields = const [],
  }) async {
    final item = VaultItem(
      id: id,
      label: label,
      value: value,
      category: category,
      tags: tags,
      username: username,
      website: website,
      note: note,
      customFields: customFields,
    );
    await _repository.updateItem(item);
    // Refresh history cache for this item
    _historyCache.remove(id);
    if (_historyExpandedIds.contains(id)) {
      await loadHistory(id);
    }
    await loadItems();
  }

  List<VaultItem> get filteredItems {
    final inCategory = _categoryFilter == null
        ? _items
        : _items.where((i) => i.category == _categoryFilter).toList();
    final rawQuery = _searchQuery.toLowerCase().trim();
    if (rawQuery.isEmpty) return List.of(inCategory);

    // When query starts with '#', search tags only
    if (rawQuery.startsWith('#')) {
      final tagQuery = rawQuery.substring(1).trim();
      if (tagQuery.isEmpty) return List.of(inCategory);
      return inCategory.where((item) {
        return item.tags.toLowerCase().contains(tagQuery);
      }).toList();
    }

    // Everything visible on an entry except the secrets themselves.
    return inCategory.where((item) {
      final haystack = [
        item.label,
        item.category,
        item.tags,
        item.username,
        item.website,
        item.note,
        for (final f in item.customFields) f.name,
      ].join('\n').toLowerCase();
      return haystack.contains(rawQuery);
    }).toList();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
