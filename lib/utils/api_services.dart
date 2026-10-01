import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/weather_location.dart';

class ApiServices {
  static const String zenQuotesUrl = 'https://zenquotes.io/api/random';

  /// Last good results, so a slow or failed request (or no network) keeps the previous data on
  /// screen instead of blanking it. One entry each, for the location they were fetched for.
  static const String _weatherCacheKey = 'weather_cache';
  static const String _aqiCacheKey = 'aqi_cache';

  /// Air quality changes through the day; an older reading is dropped rather than shown as current.
  static const Duration _aqiMaxAge = Duration(hours: 3);

  /// Weather and AQI younger than this aren't fetched again on app start (Sync always fetches).
  static const Duration freshFor = Duration(hours: 1);

  /// Responses bigger than this are dropped instead of read into memory.
  static const int _maxResponseBytes = 5 * 1024 * 1024;

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

  /// HTTPS GET; the body as text, or null on any failure. Always closes the client.
  static Future<String?> getText(Uri uri) async {
    if (uri.scheme != 'https') return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = null; // no client/version fingerprint
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      if (res.contentLength > _maxResponseBytes) return null;
      final bytes = <int>[];
      await for (final chunk in res.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > _maxResponseBytes) return null;
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// GET and decode JSON; null on any failure.
  static Future<dynamic> _getJson(Uri uri) async {
    final text = await getText(uri);
    if (text == null) return null;
    try {
      return json.decode(text);
    } catch (_) {
      return null;
    }
  }

  /// Coordinates as sent to the weather services: ~1 km, as precise as the forecasts are.
  static String _coord(double value) => value.toStringAsFixed(2);

  /// "05:48" → "5:48 AM"
  static String _to12h(String raw) {
    final hm = raw.length >= 16 ? raw.substring(11, 16) : '';
    if (hm.length != 5) return '';
    final h = int.tryParse(hm.substring(0, 2));
    if (h == null) return '';
    return "${h == 0 ? 12 : h > 12 ? h - 12 : h}:${hm.substring(3, 5)} ${h >= 12 ? 'PM' : 'AM'}";
  }

  /// 7-day forecast keyed by 'yyyy-MM-dd' → emoji, sunrise, sunset (local time at [location]).
  /// Null when the request fails; a success is cached for [cachedWeather].
  static Future<Map<String, Map<String, String>>?> fetchWeather(WeatherLocation location) async {
    final data = await _getJson(Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': _coord(location.latitude),
      'longitude': _coord(location.longitude),
      'daily': 'weather_code,sunrise,sunset',
      'timezone': 'auto',
    }));
    try {
      final daily = data['daily'];
      final List dates = daily['time'];
      final List codes = daily['weather_code'];
      final List sunrises = daily['sunrise'];
      final List sunsets = daily['sunset'];
      final weatherMap = <String, Map<String, String>>{};
      for (int i = 0; i < dates.length; i++) {
        weatherMap[dates[i].toString()] = {
          'emoji': codes[i] is int ? _getWeatherEmoji(codes[i]) : '',
          'sunrise': _to12h(sunrises[i].toString()),
          'sunset': _to12h(sunsets[i].toString()),
        };
      }
      if (weatherMap.isEmpty) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _weatherCacheKey,
          json.encode({
            'loc': location.key,
            'days': weatherMap,
            'at': DateTime.now().millisecondsSinceEpoch,
          }));
      return weatherMap;
    } catch (_) {
      return null;
    }
  }

  /// Current US AQI at [location]; null when unavailable. A success is cached for [cachedAqi].
  static Future<int?> fetchAQI(WeatherLocation location) async {
    final data = await _getJson(Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': _coord(location.latitude),
      'longitude': _coord(location.longitude),
      'current': 'us_aqi',
      'timezone': 'auto',
    }));
    try {
      final aqi = (data['current']['us_aqi'] as num).round();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_aqiCacheKey,
          json.encode({'loc': location.key, 'aqi': aqi, 'at': DateTime.now().millisecondsSinceEpoch}));
      return aqi;
    } catch (_) {
      return null;
    }
  }

  /// The last forecast fetched for [location], or empty.
  static Future<Map<String, Map<String, String>>> cachedWeather(WeatherLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = json.decode(prefs.getString(_weatherCacheKey) ?? 'null');
      if (cache is! Map || cache['loc'] != location.key) return {};
      return (cache['days'] as Map).map((date, day) =>
          MapEntry(date as String, (day as Map).map((k, v) => MapEntry(k as String, v as String))));
    } catch (_) {
      return {};
    }
  }

  /// Whether weather and AQI for [location] were both fetched within [freshFor].
  static Future<bool> isFresh(WeatherLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [_weatherCacheKey, _aqiCacheKey]) {
        final cache = json.decode(prefs.getString(key) ?? 'null');
        if (cache is! Map || cache['loc'] != location.key || cache['at'] is! int) return false;
        final at = DateTime.fromMillisecondsSinceEpoch(cache['at'] as int);
        if (DateTime.now().difference(at) > freshFor) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The last AQI fetched for [location] if it is recent enough, else null.
  static Future<int?> cachedAqi(WeatherLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = json.decode(prefs.getString(_aqiCacheKey) ?? 'null');
      if (cache is! Map || cache['loc'] != location.key) return null;
      final at = DateTime.fromMillisecondsSinceEpoch(cache['at'] as int);
      if (DateTime.now().difference(at) > _aqiMaxAge) return null;
      return cache['aqi'] as int;
    } catch (_) {
      return null;
    }
  }

  /// Place search for the location picker. Null when the request fails (vs. empty: no matches).
  static Future<List<WeatherLocation>?> searchLocations(String query) async {
    final data = await _getJson(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query,
      'count': '10',
      'language': 'en',
      'format': 'json',
    }));
    if (data is! Map) return null;
    final results = data['results'];
    if (results is! List) return [];
    final locations = <WeatherLocation>[];
    for (final r in results) {
      if (r is! Map || r['latitude'] is! num || r['longitude'] is! num) continue;
      locations.add(WeatherLocation(
        name: r['name']?.toString() ?? '',
        detail: [r['admin1'], r['country']]
            .whereType<String>()
            .where((part) => part.isNotEmpty && part != r['name'])
            .join(', '),
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
      ));
    }
    return locations;
  }

  /// The day's quote as "Quote" - Author. Fetched at most once a day; offline, the last one.
  static Future<String?> fetchDailyQuote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String todayKey = DateTime.now().toIso8601String().substring(0, 10);
      final cachedQuote = prefs.getString('cached_quote_text');
      if (cachedQuote != null && prefs.getString('cached_quote_date') == todayKey) {
        return cachedQuote;
      }

      final data = await _getJson(Uri.parse(zenQuotesUrl));
      if (data is List && data.isNotEmpty && data[0] is Map) {
        final q = data[0]['q'];
        final a = data[0]['a'];
        if (q is String && a is String) {
          final formattedQuote = '"$q" - $a';
          await prefs.setString('cached_quote_date', todayKey);
          await prefs.setString('cached_quote_text', formattedQuote);
          return formattedQuote;
        }
      }
      return cachedQuote;
    } catch (_) {
      return null;
    }
  }
}
