import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/cooldown_entities.dart';
import '../domain/cooldown_repository.dart';

class CooldownController extends ChangeNotifier {
  final ICooldownRepository _repository;
  
  List<CooldownItem> _items = [];
  Timer? _ticker;
  bool _loading = true;

  final Set<int> _justBecameAvailable = {};

  List<CooldownItem> get items => _items;
  bool get loading => _loading;
  Set<int> get justBecameAvailable => _justBecameAvailable;

  CooldownController({required ICooldownRepository repository}) : _repository = repository;

  List<CooldownItem> get available =>
      _items.where((i) => !i.isOnCooldown).toList();

  List<CooldownItem> get onCooldown =>
      _items.where((i) => i.isOnCooldown).toList()
        ..sort((a, b) => a.cooldownEnd!.compareTo(b.cooldownEnd!));

  Future<void> init() async {
    await _repository.init();
    await loadItems();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkTransitions();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _repository.dispose();
    super.dispose();
  }

  Future<void> loadItems() async {
    final items = await _repository.getAllItems();
    _items = items;
    _loading = false;
    notifyListeners();
  }

  void _checkTransitions() {
    for (final item in _items) {
      if (item.cooldownEnd != null &&
          !item.isOnCooldown &&
          !_justBecameAvailable.contains(item.id)) {
        _justBecameAvailable.add(item.id!);
        Future.delayed(const Duration(seconds: 2), () {
          _justBecameAvailable.remove(item.id);
          notifyListeners();
        });
      }
    }
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
}
