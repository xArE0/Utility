import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiServices {
  static const String openMeteoUrl =
      'https://api.open-meteo.com/v1/forecast?latitude=27.7278&longitude=85.3782&daily=weather_code,sunrise,sunset&timezone=auto';
  static const String aqiUrl = 
      'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=27.7278&longitude=85.3782&current=us_aqi&timezone=auto';
  static const String zenQuotesUrl = 'https://zenquotes.io/api/random';

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

  /// Fetches a 7-day weather forecast and maps standard 'yyyy-MM-dd' to weather emoji and sunrise/sunset
  static Future<Map<String, Map<String, String>>> fetchKathmanduWeather() async {
    final Map<String, Map<String, String>> weatherMap = {};
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
        final List sunrises = data['daily']['sunrise'];
        final List sunsets = data['daily']['sunset'];

        for (int i = 0; i < dates.length && i < codes.length; i++) {
          final String dateStr = dates[i].toString();
          final int code = codes[i] as int;
          
          final String rawSunrise = sunrises[i].toString();
          final String rawSunset = sunsets[i].toString();
          
          String sunrise = rawSunrise.length >= 16 ? rawSunrise.substring(11, 16) : '';
          String sunset = rawSunset.length >= 16 ? rawSunset.substring(11, 16) : '';
          
          // Format times to 12-hour AM/PM if possible
          if (sunrise.length == 5) {
            int h = int.parse(sunrise.substring(0, 2));
            String m = sunrise.substring(3, 5);
            sunrise = "${h == 0 ? 12 : h > 12 ? h - 12 : h}:$m ${h >= 12 ? 'PM' : 'AM'}";
          }
          if (sunset.length == 5) {
            int h = int.parse(sunset.substring(0, 2));
            String m = sunset.substring(3, 5);
            sunset = "${h == 0 ? 12 : h > 12 ? h - 12 : h}:$m ${h >= 12 ? 'PM' : 'AM'}";
          }

          weatherMap[dateStr] = {
            'emoji': _getWeatherEmoji(code),
            'sunrise': sunrise,
            'sunset': sunset,
          };
        }
      }
      client.close();
    } catch (_) {
      // Fail silently to prevent interrupting UX
    }
    return weatherMap;
  }

  /// Fetches the current Air Quality Index (US AQI)
  static Future<int?> fetchKathmanduAQI() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(aqiUrl));
      final res = await req.close();

      if (res.statusCode == 200) {
        final text = await res.transform(utf8.decoder).join();
        final data = json.decode(text);
        final int aqi = data['current']['us_aqi'];
        return aqi;
      }
      client.close();
    } catch (_) {
      // Fail silently
    }
    return null;
  }

  /// Fetches the daily ZenQuote, caching it locally for 24 hours.
  /// Returns a formatted string: "Quote" - Author
  static Future<String?> fetchDailyQuote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String todayKey = DateTime.now().toIso8601String().substring(0, 10);
      
      final cachedDate = prefs.getString('cached_quote_date');
      final cachedQuote = prefs.getString('cached_quote_text');

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
