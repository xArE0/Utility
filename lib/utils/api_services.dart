import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiServices {
  static const String openMeteoUrl =
      'https://api.open-meteo.com/v1/forecast?latitude=27.7278&longitude=85.3782&daily=weather_code&timezone=auto';
  static const String zenQuotesUrl = 'https://zenquotes.io/api/today';

  static String _getWeatherEmoji(int code) {
    if (code == 0) return '☀️';
    if (code == 1 || code == 2) return '⛅';
    if (code == 3) return '☁️';
    if (code == 45 || code == 48) return '🌫️';
    if (code >= 51 && code <= 55) return '🌧️';
    if (code >= 61 && code <= 65) return '☔';
    if (code >= 71 && code <= 77) return '❄️';
    if (code >= 80 && code <= 82) return '🌦️';
    if (code >= 85 && code <= 86) return '🌨️';
    if (code >= 95 && code <= 99) return '🌩️';
    return '';
  }

  /// Fetches a 7-day weather forecast and maps standard 'yyyy-MM-dd' to weather emojis
  static Future<Map<String, String>> fetchKathmanduWeather() async {
    final Map<String, String> weatherMap = {};
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(openMeteoUrl));
      final res = await req.close();

      if (res.statusCode == 200) {
        final text = await res.transform(utf8.decoder).join();
        final data = json.decode(text);
        final List dates = data['daily']['time'];
        final List codes = data['daily']['weather_code'];

        for (int i = 0; i < dates.length && i < codes.length; i++) {
          final String dateStr = dates[i].toString();
          final int code = codes[i] as int;
          weatherMap[dateStr] = _getWeatherEmoji(code);
        }
      }
      client.close();
    } catch (_) {
      // Fail silently to prevent interrupting UX
    }
    return weatherMap;
  }

  /// Fetches the daily ZenQuote, caching it locally for 24 hours.
  /// Returns a formatted string: "Quote" - Author
  static Future<String?> fetchDailyQuote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String todayKey = DateTime.now().toIso8601String().substring(0, 10);
      
      final cachedDate = prefs.getString('cached_quote_date');
      final cachedQuote = prefs.getString('cached_quote_text');

      // If we already fetched a quote today, return it immensely fast
      if (cachedDate == todayKey && cachedQuote != null) {
        return cachedQuote;
      }

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(zenQuotesUrl));
      final res = await req.close();

      if (res.statusCode == 200) {
        final text = await res.transform(utf8.decoder).join();
        final data = json.decode(text);
        if (data.isNotEmpty) {
          final q = data[0]['q'];
          final a = data[0]['a'];
          final formattedQuote = '"$q" - $a';
          
          await prefs.setString('cached_quote_date', todayKey);
          await prefs.setString('cached_quote_text', formattedQuote);
          return formattedQuote;
        }
      }
      client.close();

      // If offline, return the last cached quote even if it's expired
      return cachedQuote; 
    } catch (_) {
      // Offline fail-safe
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('cached_quote_text');
      } catch (_) {
        return null;
      }
    }
  }
}
