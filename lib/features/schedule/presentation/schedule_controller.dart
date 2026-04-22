import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../domain/schedule_entities.dart';
import '../domain/schedule_repository.dart';
import '../../../services/notification_service.dart';
import '../../../utils/ics_parser.dart';
import '../../../utils/api_services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ScheduleView { timeline, week, month }

class ScheduleController extends ChangeNotifier {
  final IScheduleRepository _repository;

  ScheduleView _viewMode = ScheduleView.timeline;
  late final DateTime _baseDate;

  static const int initialIndex = 10000;
  static final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat dayFormat = DateFormat('EEE');
  static final DateFormat numFormat = DateFormat('d');
  static final DateFormat monthFormat = DateFormat('MMM');

  final double itemExtent = 125.0;

  List<Event> _allEvents = [];
  List<Event> _allBirthdays = [];
  List<Event> _allExams = [];
  List<Event> _repeatingEvents = []; 
  List<Event> _multiDayEvents = [];
  Set<String> _eventDates = {};
  Map<String, List<Event>> _eventsByDate = {};
  
  late DateTime _selectedDate;
  bool _isDragging = false;

  // Cache for Nepali dates
  final Map<String, NepaliDateTime> _nepaliDateCache = {};
  final Map<String, String> _nepaliMonthCache = {};
  final Map<String, String> _nepaliDayCache = {};
  
  // Memoization cache for _eventsForDate to prevent recalculation
  final Map<String, List<Event>> _eventsForDateCache = {};
  
  Map<String, Map<String, String>> weatherMap = {};
  int? currentAqi;

  bool _isLoadingNepaliDates = false;

  ScrollController? _scrollController;

  ScheduleController({required IScheduleRepository repository}) : _repository = repository {
    final now = DateTime.now();
    _baseDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: initialIndex));
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  // Getters

  ScheduleView get viewMode => _viewMode;
  DateTime get selectedDate => _selectedDate;
  bool get isDragging => _isDragging;
  bool get isLoadingNepaliDates => _isLoadingNepaliDates;
  DateTime get baseDate => _baseDate;
  ScrollController? get scrollController => _scrollController;
  List<Event> get allEvents => _allEvents;

  // Setters


  set viewMode(ScheduleView value) {
    if (_viewMode != value) {
      _viewMode = value;
      if (_viewMode == ScheduleView.timeline && _scrollController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController!.hasClients) {
            final idx = indexFromDate(_selectedDate);
            _scrollController!.jumpTo(idx * itemExtent);
          }
        });
      }
      notifyListeners();
    }
  }

  set selectedDate(DateTime value) {
    if (!isSameDay(_selectedDate, value)) {
      _selectedDate = value;
      notifyListeners();
    }
  }

  set isDragging(bool value) {
    if (_isDragging != value) {
      _isDragging = value;
      notifyListeners();
    }
  }

  void setScrollController(ScrollController controller) {
    _scrollController = controller;
  }

  Future<void> init() async {
    await _repository.init();
    await preloadEvents();
    precomputeNepaliDates(_selectedDate);
    
    // Fetch weather asynchronously so it doesn't block UI
    ApiServices.fetchKathmanduWeather().then((fetched) {
      if (fetched.isNotEmpty) {
        weatherMap = fetched;
        notifyListeners();
      }
    });
    ApiServices.fetchKathmanduAQI().then((fetched) {
      if (fetched != null) {
        currentAqi = fetched;
        notifyListeners();
        updateHomeWidget();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController != null && _scrollController!.hasClients) {
        final idx = indexFromDate(_selectedDate);
        _scrollController!.jumpTo(idx * itemExtent);
      }
      notifyListeners();
    });
  }

  Future<void> preloadEvents() async {
    _allEvents = await _repository.getAllEvents();
    _allBirthdays = _allEvents.where((e) => e.type == 'birthday').toList();
    _allExams = _allEvents.where((e) => e.type == 'exam').toList();
    
    _repeatingEvents = _allEvents.where((e) => 
      e.type != 'birthday' && 
      e.type != 'exam' && 
      e.repeat != null && 
      e.repeat != "none"
    ).toList();
    
    _multiDayEvents = _allEvents.where((e) => 
      e.type != 'birthday' && 
      e.type != 'exam' && 
      (e.repeat == null || e.repeat == "none") &&
      e.durationDays != null && 
      e.durationDays! > 1
    ).toList();

    _eventDates = _allEvents
        .where((e) => e.type != 'birthday')
        .map((e) => e.date)
        .toSet();

    _eventsByDate = {};
    for (var event in _allEvents) {
      if (event.type == 'birthday' || 
          event.type == 'exam' || 
          (event.repeat != null && event.repeat != "none") ||
          (event.durationDays != null && event.durationDays! > 1)) {
        continue;
      }
      
      final dateStr = event.date;
      if (!_eventsByDate.containsKey(dateStr)) {
        _eventsByDate[dateStr] = [];
      }
      _eventsByDate[dateStr]!.add(event);
    }

    _eventsForDateCache.clear();
    await updateHomeWidget();

    notifyListeners();
  }

  DateTime dateFromIndex(int index) {
    return _baseDate.add(Duration(days: index));
  }

  int indexFromDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.difference(_baseDate).inDays;
  }

  Map<String, String> getNepaliDateInfo(DateTime date) {

    final dateKey = dateFormat.format(date);

    if (!_nepaliMonthCache.containsKey(dateKey) || !_nepaliDayCache.containsKey(dateKey)) {
      try {
        final nepaliDate = date.toNepaliDateTime();
        _nepaliDateCache[dateKey] = nepaliDate;
        _nepaliMonthCache[dateKey] = NepaliUnicode.convert(NepaliDateFormat('MMMM').format(nepaliDate));
        _nepaliDayCache[dateKey] = NepaliUnicode.convert(NepaliDateFormat('d').format(nepaliDate));
      } catch (e) {
        _nepaliMonthCache[dateKey] = monthFormat.format(date);
        _nepaliDayCache[dateKey] = numFormat.format(date);
      }
    }

    return {
      'month': _nepaliMonthCache[dateKey]!,
      'day': _nepaliDayCache[dateKey]!,
    };
  }

  void clearOldCache() {
    if (_nepaliDateCache.length > 200) {
      final keysToRemove = _nepaliDateCache.keys.take(50).toList();
      for (final key in keysToRemove) {
        _nepaliDateCache.remove(key);
        _nepaliMonthCache.remove(key);
        _nepaliDayCache.remove(key);
      }
    }
  }
  
  Future<void> precomputeNepaliDates(DateTime centerDate) async {
    _isLoadingNepaliDates = true;
    notifyListeners();
    
    try {
      final datesToCompute = <String>[];
      for (int i = -30; i <= 30; i++) {
        final date = centerDate.add(Duration(days: i));
        final key = dateFormat.format(date);
        if (!_nepaliMonthCache.containsKey(key)) {
          datesToCompute.add(key);
        }
      }
      
      if (datesToCompute.isNotEmpty) {
        final results = await compute(_computeNepaliDatesBatch, datesToCompute);
        
        for (final entry in results.entries) {
          _nepaliMonthCache[entry.key] = entry.value['month']!;
          _nepaliDayCache[entry.key] = entry.value['day']!;
        }
      }
    } catch (e) {
      debugPrint('Error precomputing Nepali dates: $e');
    } finally {
      _isLoadingNepaliDates = false;
      notifyListeners();
    }
  }
  
  static Map<String, Map<String, String>> _computeNepaliDatesBatch(List<String> dateKeys) {
    final results = <String, Map<String, String>>{};
    
    for (final key in dateKeys) {
      try {
        final date = DateTime.parse(key);
        final nepaliDate = date.toNepaliDateTime();
        results[key] = {
          'month': NepaliUnicode.convert(NepaliDateFormat('MMMM').format(nepaliDate)),
          'day': NepaliUnicode.convert(NepaliDateFormat('d').format(nepaliDate)),
        };
      } catch (e) {
        results[key] = {'month': '', 'day': ''};
      }
    }
    
    return results;
  }

  Future<void> updateHomeWidget() async {
    try {
      final now = DateTime.now();
      
      // Date Display
      final dateStr = DateFormat('EEEE, MMM d').format(now);
      
      final dateStrForWeather = DateFormat('yyyy-MM-dd').format(now);
      final todayWeather = weatherMap[dateStrForWeather];
      final weatherEmoji = todayWeather?['emoji'] ?? '';

      // AQI Display
      String aqiStr = "Air Quality: --";
      if (currentAqi != null) {
        aqiStr = "$weatherEmoji   Air Quality: $currentAqi".trim();
      } else if (weatherEmoji.isNotEmpty) {
        aqiStr = weatherEmoji;
      }

      // Tasks Display
      String tasksStr = "No tasks scheduled for today. You're free!";
      final todayEvents = eventsForDate(now);
      if (todayEvents.isNotEmpty) {
        tasksStr = todayEvents.map((e) {
          String time = e.remindTime != null ? "${e.remindTime} - " : "";
           return "• $time${e.task}";
        }).join("\n");
      }

      // Quotes Display
      final prefs = await SharedPreferences.getInstance();
      final String? quoteStr = prefs.getString('cached_quote_text');

      await HomeWidget.saveWidgetData<String>('widget_date', dateStr);
      await HomeWidget.saveWidgetData<String>('widget_aqi', aqiStr);
      await HomeWidget.saveWidgetData<String>('widget_tasks', tasksStr);
      await HomeWidget.saveWidgetData<String>('widget_quote', quoteStr ?? "");
      
      await HomeWidget.updateWidget(
        name: 'ScheduleWidgetProvider',
        androidName: 'ScheduleWidgetProvider',
      );
    } catch (_) {
      // Fail silently if widget not ready
    }
  }

  List<Event> eventsForDate(DateTime date) {
    final dateKey = dateFormat.format(date);
    if (_eventsForDateCache.containsKey(dateKey)) {
      return _eventsForDateCache[dateKey]!;
    }

    if (_eventsByDate.isEmpty && _allBirthdays.isEmpty && _allExams.isEmpty && _repeatingEvents.isEmpty && _multiDayEvents.isEmpty) return [];

    List<Event> events = [];

    if (_eventsByDate.containsKey(dateKey)) {
      events.addAll(_eventsByDate[dateKey]!);
    }
    
    events.addAll(_multiDayEvents.where((e) {
      return e.spansDate(date);
    }));

    events.addAll(_repeatingEvents.where((e) {
      final eventDate = DateTime.parse(e.date);
      if (date.isBefore(eventDate)) return false;
      switch (e.repeat) {
        case "daily":
          return true;
        case "weekly":
          return date.weekday == eventDate.weekday;
        case "monthly":
          return date.day == eventDate.day;
        case "yearly":
          return date.month == eventDate.month && date.day == eventDate.day;
        case "custom":
          final interval = e.repeatInterval ?? 1;
          return date.difference(eventDate).inDays % interval == 0;
        default:
          return false;
      }
    }));

    final bdays = _allBirthdays.where((e) {
      final d = DateTime.parse(e.date);
      return d.month == date.month && d.day == date.day;
    }).toList();

    final exams = _allExams.where((e) => e.date == dateKey).toList();

    final result = [...events, ...bdays, ...exams];
    _eventsForDateCache[dateKey] = result;

    return result;
  }

  int? findNearestEventIndex(int from, int direction) {
    final Set<int> normalIndices = _eventDates.map((d) {
      return indexFromDate(DateTime.parse(d));
    }).toSet();

    final birthdayIndices = <int>{};
    for (var e in _allBirthdays) {
      final original = DateTime.parse(e.date);
      for (int y = _selectedDate.year - 2; y <= _selectedDate.year + 2; y++) {
        try {
          final recurring = DateTime(y, original.month, original.day);
          final idx = indexFromDate(recurring);
          birthdayIndices.add(idx);
        } catch (_) {
          continue;
        }
      }
    }

    final examIndices = _allExams.map((e) {
      return indexFromDate(DateTime.parse(e.date));
    }).toSet();

    final allIndices = {...normalIndices, ...birthdayIndices, ...examIndices}..remove(from);
    if (allIndices.isEmpty) return null;

    final sorted = allIndices.toList()..sort();

    if (direction > 0) {
      final found = sorted.where((i) => i > from).toList();
      return found.isNotEmpty ? found.first : null;
    } else {
      final found = sorted.where((i) => i < from).toList();
      return found.isNotEmpty ? found.last : null;
    }
  }

  Future<void> jumpToEvent(int direction) async {
    final currentIndex = indexFromDate(_selectedDate);
    final idx = findNearestEventIndex(currentIndex, direction);
    if (idx != null && idx != currentIndex && _scrollController != null) {
      await _scrollController!.animateTo(
        idx * itemExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      final date = dateFromIndex(idx);
      _selectedDate = date;
      notifyListeners();
    }
  }

  void jumpToDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final idx = indexFromDate(normalizedDate);
    _selectedDate = normalizedDate;
    notifyListeners();
    if (_scrollController != null && _scrollController!.hasClients) {
      _scrollController!.animateTo(
        idx * itemExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> moveEvent(Event event, DateTime newDate) async {
    final newDateString = dateFormat.format(newDate);

    if (event.id != null && event.remindMe) {
      await NotificationService().cancelEventNotification(event.id!);
    }

    final updatedEvent = Event(
      id: event.id,
      date: newDateString,
      task: event.task,
      type: event.type,
      remindMe: event.remindMe,
      remindDaysBefore: event.remindDaysBefore,
      remindTime: event.remindTime,
      repeat: event.repeat,
      repeatInterval: event.repeatInterval,
      durationDays: event.durationDays,
    );

    await _repository.updateEvent(updatedEvent);

    if (event.id != null && event.remindMe && event.remindTime != null) {
      await NotificationService().scheduleEventNotification(updatedEvent);
    }

    await preloadEvents();
  }

  Future<void> deleteEvent(Event event) async {
    await _repository.deleteEvent(event.id!);

    if (event.id != null) {
      await NotificationService().cancelEventNotification(event.id!);
    }
    
    await preloadEvents();
  }

  Future<void> addEvent(Event newEvent, BuildContext context) async {
    final eventId = await _repository.insertEvent(newEvent);
    
    if (newEvent.remindMe && newEvent.remindTime != null) {
      final eventWithId = Event(
        id: eventId,
        date: newEvent.date,
        task: newEvent.task,
        type: newEvent.type,
        remindMe: newEvent.remindMe,
        remindDaysBefore: newEvent.remindDaysBefore,
        remindTime: newEvent.remindTime,
        repeat: newEvent.repeat,
        repeatInterval: newEvent.repeatInterval,
        durationDays: newEvent.durationDays,
      );
      await NotificationService().scheduleEventNotification(eventWithId);
    }
    
    await preloadEvents();
    _selectedDate = DateTime.parse(newEvent.date);
    notifyListeners();
  }

  Future<bool> syncAllApiData() async {
    try {
      // 1. Sync Weather
      final fetchedWeather = await ApiServices.fetchKathmanduWeather();
      final fetchedAqi = await ApiServices.fetchKathmanduAQI();

      if (fetchedWeather.isEmpty && fetchedAqi == null) {
        return false;
      }

      if (fetchedWeather.isNotEmpty) {
        weatherMap = fetchedWeather;
        notifyListeners();
      }
      
      if (fetchedAqi != null) {
        currentAqi = fetchedAqi;
        notifyListeners();
      }

      // 2. Sync Quote
      await ApiServices.fetchDailyQuote();

      // 3. Sync Holidays
      final fetchedHolidays = await IcsParser.fetchNepalHolidays();
      if (fetchedHolidays.isEmpty) {
        return false;
      }

      int addedCount = 0;
      for (final holiday in fetchedHolidays) {
        bool exists = false;
        if (_eventsByDate.containsKey(holiday.date)) {
          exists = _eventsByDate[holiday.date]!.any((e) => e.task == holiday.task);
        }
        
        if (!exists) {
          await _repository.insertEvent(holiday);
          addedCount++;
        }
      }

      await preloadEvents();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
