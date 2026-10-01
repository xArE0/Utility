import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform services from the native side (SystemChannel.kt).
class SystemService {
  SystemService._();

  static const _channel = MethodChannel('com.example.utility/system');

  /// The device's IANA timezone, e.g. "Asia/Kathmandu"; null if unavailable.
  static Future<String?> timezone() async {
    try {
      return await _channel.invokeMethod<String>('timezone');
    } catch (e) {
      debugPrint('timezone failed: $e');
      return null;
    }
  }

  /// One coarse (~1 km) location fix. Throws [PlatformException] with code NO_PERMISSION,
  /// LOCATION_OFF or TIMEOUT.
  static Future<({double latitude, double longitude})> currentLocation() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('currentLocation');
    return (
      latitude: (map!['lat'] as num).toDouble(),
      longitude: (map['lon'] as num).toDouble(),
    );
  }

  /// Copies [text] flagged as sensitive; it is cleared from the clipboard again after 30 s.
  static Future<void> copySensitive(String text) async {
    try {
      await _channel.invokeMethod('copySensitive', {'text': text});
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  /// Blocks (or allows again) screenshots, screen recording and the recents preview.
  static Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod('setSecure', {'secure': secure});
    } catch (e) {
      debugPrint('setSecure failed: $e');
    }
  }
}
