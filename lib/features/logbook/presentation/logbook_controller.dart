import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/logbook_entities.dart';
import '../domain/logbook_repository.dart';

class LogbookController extends ChangeNotifier {
  final ILogbookRepository _repository;
  List<LogEntry> _entries = [];
  bool _initialized = false;

  LogbookController({required ILogbookRepository repository})
      : _repository = repository;

  List<LogEntry> get entries => _entries;
  bool get initialized => _initialized;

  Future<void> init() async {
    await _repository.init();
    await _loadEntries();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadEntries() async {
    _entries = await _repository.getAllEntries();
    // Sort by elapsed days ascending (most urgent/longest first)
    _entries.sort((a, b) => b.elapsedDays.compareTo(a.elapsedDays));
    notifyListeners();
  }

  Future<void> addEntry(LogEntry entry) async {
    await _repository.insertEntry(entry);
    await _loadEntries();
  }

  Future<void> updateEntry(LogEntry entry) async {
    await _repository.updateEntry(entry);
    await _loadEntries();
  }

  Future<void> deleteEntry(int id) async {
    await _repository.deleteEntry(id);
    await _loadEntries();
  }

  Future<void> checkpoint(LogEntry entry, {String? note}) async {
    final cp = LogCheckpoint(
      entryId: entry.id!,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      note: note,
    );
    await _repository.insertCheckpoint(cp);
    await _loadEntries();
  }

  Future<void> deleteCheckpoint(int id) async {
    await _repository.deleteCheckpoint(id);
    await _loadEntries();
  }

  String formatElapsed(int days) {
    if (days == 0) return 'Today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }

  /// Returns a structured breakdown for the hero display on cards.
  /// {value: '2', unit: 'months', sub: '3 d'}
  Map<String, String> formatElapsedHero(int totalDays) {
    if (totalDays == 0) return {'value': '0', 'unit': 'days', 'sub': 'today'};
    
    if (totalDays < 7) {
      return {'value': '$totalDays', 'unit': totalDays == 1 ? 'day' : 'days', 'sub': ''};
    } else if (totalDays < 30) {
      final weeks = totalDays ~/ 7;
      final remDays = totalDays % 7;
      return {
        'value': '$weeks',
        'unit': weeks == 1 ? 'week' : 'wks',
        'sub': remDays == 0 ? '' : '$remDays d',
      };
    } else if (totalDays < 365) {
      final months = totalDays ~/ 30;
      final remDays = totalDays % 30;
      return {
        'value': '$months',
        'unit': months == 1 ? 'month' : 'mos',
        'sub': remDays == 0 ? '' : '$remDays d',
      };
    } else {
      final years = totalDays ~/ 365;
      final remDays = totalDays % 365;
      final months = remDays ~/ 30;
      return {
        'value': '$years',
        'unit': years == 1 ? 'year' : 'yrs',
        'sub': months == 0 ? '' : '$months mo',
      };
    }
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
