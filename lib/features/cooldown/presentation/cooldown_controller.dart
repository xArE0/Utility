import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/cooldown_entities.dart';
import '../domain/cooldown_repository.dart';

class CooldownController extends ChangeNotifier {
  final ICooldownRepository _repository;
  
  List<CooldownItem> _items = [];
  List<CooldownCategory> _categories = [];
  Timer? _ticker;
  bool _loading = true;

  final Set<int> _justBecameAvailable = {};

  /// Items on cooldown at the last tick; one missing now has just become available.
  Set<int> _wasOnCooldown = {};
  bool _disposed = false;

  List<CooldownItem> get items => _items;
  List<CooldownCategory> get allCategories => _categories;
  bool get loading => _loading;
  Set<int> get justBecameAvailable => _justBecameAvailable;

  CooldownController({required ICooldownRepository repository}) : _repository = repository;

  List<CooldownItem> get available =>
      _items.where((i) => !i.isOnCooldown).toList();

  List<CooldownItem> get onCooldown =>
      _items.where((i) => i.isOnCooldown).toList()
        ..sort((a, b) => a.cooldownEnd!.compareTo(b.cooldownEnd!));

  List<String?> get categories {
    final cats = _items.map((i) => i.category).toSet().toList();
    cats.sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    });
    return cats;
  }

  List<CooldownItem> itemsForCategory(String? category) {
    return _items.where((i) => i.category == category).toList();
  }

  List<CooldownItem> itemsForCategoryId(int? categoryId) {
    return _items.where((i) => i.categoryId == categoryId).toList();
  }

  CooldownCategory? categoryForItem(CooldownItem item) {
    if (item.categoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == item.categoryId);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    await _repository.init();
    await loadItems();
    await loadCategories();
  }

  /// The once-a-second countdown only runs while something is actually counting down.
  void _syncTicker() {
    final needed = _items.any((i) => i.isOnCooldown);
    if (needed) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _checkTransitions();
        notifyListeners();
        _syncTicker();
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Set<int> _onCooldownIds() =>
      {for (final i in _items) if (i.isOnCooldown && i.id != null) i.id!};

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _repository.dispose();
    super.dispose();
  }

  Future<void> loadItems() async {
    final items = await _repository.getAllItems();
    _items = items;
    _wasOnCooldown = _onCooldownIds();
    _loading = false;
    notifyListeners();
    _syncTicker();
  }

  Future<void> loadCategories() async {
    _categories = await _repository.getAllCategories();
    notifyListeners();
  }

  void _checkTransitions() {
    final now = _onCooldownIds();
    for (final id in _wasOnCooldown.difference(now)) {
      _justBecameAvailable.add(id);
      Future.delayed(const Duration(seconds: 2), () {
        if (_disposed) return;
        _justBecameAvailable.remove(id);
        notifyListeners();
      });
    }
    _wasOnCooldown = now;
  }

  Future<void> addItem(CooldownItem item) async {
    await _repository.addItem(item);
    await loadItems();
  }

  Future<void> updateItem(CooldownItem item) async {
    await _repository.updateItem(item);
    await loadItems();
  }

  Future<void> deleteItem(int id) async {
    await _repository.deleteItem(id);
    await loadItems();
  }

  Future<void> startCooldown(CooldownItem item, DateTime cooldownEnd) async {
    await updateItem(item.copyWith(cooldownEnd: cooldownEnd, createdAt: DateTime.now()));
  }

  Future<void> clearCooldown(CooldownItem item) async {
    await updateItem(item.copyWith(clearCooldown: true));
  }

  Future<void> startCategoryCooldown(CooldownItem item) async {
    final cat = categoryForItem(item);
    if (cat == null) return;
    final cooldownEnd = DateTime.now().add(cat.cooldownDuration);
    await startCooldown(item, cooldownEnd);
  }

  Future<void> addCategory(CooldownCategory cat) async {
    await _repository.addCategory(cat);
    await loadCategories();
  }

  Future<void> updateCategoryData(CooldownCategory cat) async {
    await _repository.updateCategory(cat);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await _repository.deleteCategory(id);
    await loadCategories();
    await loadItems();
  }
}
