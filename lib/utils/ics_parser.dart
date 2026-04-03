import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../features/schedule/domain/schedule_entities.dart';

class IcsParser {
  static const String googleHolidaysUrl = 
      'https://calendar.google.com/calendar/ical/en.np%23holiday%40group.v.calendar.google.com/public/basic.ics';

  /// Fetches Google Calendar ICS feed and parses it into lightweight app Events.
  static Future<List<Event>> fetchNepalHolidays() async {
    final url = Uri.parse(googleHolidaysUrl);
    final upcomingEvents = <Event>[];

    try {
      final client = HttpClient();
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final lines = content.split('\n');

        String? currentDate;
        String? currentSummary;

        for (var line in lines) {
          line = line.trim();
          if (line.startsWith('DTSTART;VALUE=DATE:')) {
            currentDate = line.substring('DTSTART;VALUE=DATE:'.length);
          } else if (line.startsWith('SUMMARY:')) {
            currentSummary = line.substring('SUMMARY:'.length);
          } else if (line == 'END:VEVENT') {
            if (currentDate != null && currentSummary != null) {
              try {
                final year = int.parse(currentDate.substring(0, 4));
                final month = int.parse(currentDate.substring(4, 6));
                final day = int.parse(currentDate.substring(6, 8));
                final dateObj = DateTime(year, month, day);

                // We only care about events from the current year onwards to prevent DB bloat
                if (dateObj.isAfter(DateTime(DateTime.now().year - 1, 1, 1))) {
                  final formattedDate = DateFormat('yyyy-MM-dd').format(dateObj);
                  
                  upcomingEvents.add(Event(
                    date: formattedDate,
                    task: currentSummary.trim(),
                    type: 'festival',
                    remindMe: false,
                    repeat: 'none',
                  ));
                }
              } catch (_) {
                // Ignore parse errors on specific weird lines
              }
            }
            currentDate = null;
            currentSummary = null;
          }
        }
      }
      client.close();
    } catch (e) {
      // Return empty list on failure, no need to crash
    }

    return upcomingEvents;
  }
}
