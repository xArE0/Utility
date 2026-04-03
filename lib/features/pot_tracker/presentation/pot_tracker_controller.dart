import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/pot_entities.dart';
import '../domain/pot_repository.dart';

class PotTrackerController extends ChangeNotifier {
  final IPotRepository _repository;
  
  final List<Player> _players = [];
  double _ante = 0.0;
  final List<RoundRecord> _history = [];

  List<Player> get players => _players;
  double get ante => _ante;
  List<RoundRecord> get history => _history;

  PotTrackerController({required IPotRepository repository}) : _repository = repository;

  Future<void> init() async {
    await _repository.init();
    await loadSession();
  }

  Future<void> loadSession() async {
    final map = await _repository.loadLatestSession();
    if (map == null) return;
    
    final loadedPlayers = (map['players'] as List).map((e) => Player.fromMap(e as Map)).toList();
    final loadedAnte = (map['ante'] as num).toDouble();
    final loadedHistory = (map['history'] as List).map((e) => RoundRecord.fromMap(e as Map)).toList();
    
    _players.clear();
    _players.addAll(loadedPlayers);
    _ante = loadedAnte;
    _history.clear();
    _history.addAll(loadedHistory);
    
    notifyListeners();
  }

  Future<void> saveSession() async {
    await _repository.saveSession(_players, _ante, _history);
  }

  String generateDefaultName() {
    final regex = RegExp(r'^Player (\d+)$');
    var maxN = 0;
    for (final p in _players) {
      final m = regex.firstMatch(p.name);
      if (m != null) {
        final n = int.tryParse(m.group(1) ?? '') ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return 'Player ${maxN + 1}';
  }

  void addPlayer(String name) {
    final useName = (name.trim().isEmpty) ? generateDefaultName() : name.trim();
    _players.add(Player(name: useName));
    saveSession();
    notifyListeners();
  }

  void renamePlayer(int index, String newName) {
    if (newName.trim().isNotEmpty) {
      _players[index].name = newName.trim();
      saveSession();
      notifyListeners();
    }
  }

  void removePlayer(int index) {
    _players.removeAt(index);
    saveSession();
    notifyListeners();
  }

  void setAnte(double value) {
    _ante = double.parse(value.toStringAsFixed(2));
    saveSession();
    notifyListeners();
  }

  void settleWinner(int winnerIndex) {
    final n = _players.length;
    for (var i = 0; i < n; i++) {
      if (i == winnerIndex) continue;
      _players[i].net = double.parse((_players[i].net - _ante).toStringAsFixed(2));
    }
    _players[winnerIndex].net = double.parse((_players[winnerIndex].net + _ante * (n - 1)).toStringAsFixed(2));
    _history.insert(
      0,
      RoundRecord(time: DateTime.now(), winners: [_players[winnerIndex].name], ante: _ante, playerCount: n),
    );
    saveSession();
    notifyListeners();
  }

  void resetTransactions() {
    for (final p in _players) {
      p.net = 0.0;
    }
    _history.clear();
    saveSession();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    saveSession();
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
