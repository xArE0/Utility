/// A place weather, sunrise/sunset and air quality are fetched for.
class WeatherLocation {
  final String name;

  /// Region and country, e.g. "Bagmati, Nepal"; empty when unknown.
  final String detail;
  final double latitude;
  final double longitude;

  /// From "Use my location" rather than a search; only one such entry is kept.
  final bool isDevice;

  const WeatherLocation({
    required this.name,
    this.detail = '',
    required this.latitude,
    required this.longitude,
    this.isDevice = false,
  });

  static const kathmandu =
      WeatherLocation(name: 'Kathmandu', detail: 'Nepal', latitude: 27.7278, longitude: 85.3782);

  /// Identity for comparisons and caches; ~10 m precision, so the same place found twice matches.
  String get key => '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';

  Map<String, dynamic> toJson() => {
        'name': name,
        'detail': detail,
        'lat': latitude,
        'lon': longitude,
        if (isDevice) 'device': true,
      };

  static WeatherLocation? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'], lon = json['lon'], name = json['name'];
    if (lat is! num || lon is! num || name is! String) return null;
    return WeatherLocation(
      name: name,
      detail: json['detail'] as String? ?? '',
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      isDevice: json['device'] == true,
    );
  }
}
