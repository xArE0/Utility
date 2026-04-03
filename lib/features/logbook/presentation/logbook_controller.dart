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
    if (days < 30) return '$days days ago';
    if (days < 365) {
      final months = days ~/ 30;
      final remainDays = days % 30;
      if (remainDays == 0) return '$months month${months > 1 ? 's' : ''} ago';
      return '$months mo, $remainDays d ago';
    }
    final years = days ~/ 365;
    final remainDays = days % 365;
    final months = remainDays ~/ 30;
    if (months == 0) return '$years year${years > 1 ? 's' : ''} ago';
    return '$years y, $months mo ago';
  }

  /// Returns a structured breakdown for the hero display on cards.
  /// {value: '2', unit: 'years', sub: '3 mo'}
  Map<String, String> formatElapsedHero(int days) {
    if (days == 0) return {'value': '0', 'unit': 'days', 'sub': 'today'};
    if (days < 7) return {'value': '$days', 'unit': days == 1 ? 'day' : 'days', 'sub': ''};
    if (days < 30) {
      final weeks = days ~/ 7;
      final rem = days % 7;
      return {
        'value': '$weeks',
        'unit': weeks == 1 ? 'week' : 'weeks',
        'sub': rem > 0 ? '$rem d' : '',
      };
    }
    if (days < 365) {
      final months = days ~/ 30;
      final rem = days % 30;
      return {
        'value': '$months',
        'unit': months == 1 ? 'month' : 'months',
        'sub': rem > 0 ? '$rem d' : '',
      };
    }
    final years = days ~/ 365;
    final remDays = days % 365;
    final months = remDays ~/ 30;
    return {
      'value': '$years',
      'unit': years == 1 ? 'year' : 'years',
      'sub': months > 0 ? '$months mo' : '',
    };
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
