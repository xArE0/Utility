import 'dart:io';
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://calendar.google.com/calendar/ical/en.np%23holiday%40group.v.calendar.google.com/public/basic.ics');
  
  try {
    final client = HttpClient();
    final request = await client.getUrl(url);
    final response = await request.close();
    
    if (response.statusCode == 200) {
      final content = await response.transform(utf8.decoder).join();
      final lines = content.split('\n');
      
      final upcomingEvents = <Map<String, dynamic>>[];
      
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
              
              if (dateObj.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
                upcomingEvents.add({
                  'date': dateObj,
                  'name': currentSummary,
                });
              }
            } catch (_) {}
          }
          currentDate = null;
          currentSummary = null;
        }
      }
      
      upcomingEvents.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      
      print('=== UPCOMING DASHAIN / TIHAR IN NEPAL ===');
      for (var ev in upcomingEvents) {
        final name = (ev['name'] as String).toLowerCase();
        if (name.contains('dashain') || name.contains('tihar') || name.contains('nawami') || name.contains('phulpati') || name.contains('bhai') || name.contains('l लक्ष्मी')) {
          final dt = ev['date'] as DateTime;
          print('${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}: ${ev['name']}');
        }
      }
    }
    client.close();
  } catch (e) {
    print("Error: $e");
  }
}
