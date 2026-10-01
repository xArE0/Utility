import 'schedule_entities.dart';

abstract class IScheduleRepository {
  Future<void> init();
  Future<List<Event>> getAllEvents();
  Future<int> insertEvent(Event event);
  Future<void> updateEvent(Event event);
  Future<void> deleteEvent(int id);
  Future<void> dispose();
}
