import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/volume_entities.dart';
import '../domain/volume_repository.dart';

/// Rules are stored natively so the alarm receiver can read them without Flutter running.
class AndroidVolumeRepository implements IVolumeRepository {
  static const _channel = MethodChannel('com.example.utility/volume');

  final _changes = StreamController<void>.broadcast();

  AndroidVolumeRepository() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _changes.add(null);
    });
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> startListening() => _invoke('startListening');

  @override
  Future<void> stopListening() => _invoke('stopListening');

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _changes.close();
  }

  @override
  Future<List<VolumeRule>> loadRules() async {
    final json = await _invoke<String>('getRules') ?? '[]';
    return (jsonDecode(json) as List)
        .map((e) => VolumeRule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> saveRules(List<VolumeRule> rules) => _invoke(
      'saveRules', {'json': jsonEncode(rules.map((r) => r.toJson()).toList())});

  @override
  Future<void> applyNow(String ruleId) => _invoke('applyNow', {'id': ruleId});

  @override
  Future<VolumeState> getState() async {
    final map = await _invoke<Map<Object?, Object?>>('getState');
    if (map == null) return const VolumeState();

    final rawStreams = (map['streams'] as Map?) ?? const {};
    final streams = <VolumeStream, StreamInfo>{};
    for (final e in rawStreams.entries) {
      final stream = VolumeStream.fromKey(e.key as String);
      final info = e.value as Map;
      if (stream == null) continue;
      streams[stream] = StreamInfo(
        min: (info['min'] as num).toInt(),
        max: (info['max'] as num).toInt(),
        current: (info['current'] as num).toInt(),
      );
    }

    final nextMs = (map['nextChangeMs'] as num?)?.toInt();
    final log = (jsonDecode((map['log'] as String?) ?? '[]') as List)
        .map(
            (e) => VolumeLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return VolumeState(
      streams: streams,
      ringerMode: (map['ringerMode'] as String?) ?? 'normal',
      nextChange:
          nextMs == null ? null : DateTime.fromMillisecondsSinceEpoch(nextMs),
      log: log,
      isXiaomi: map['isXiaomi'] == true,
      autostart: (map['autostart'] as String?) ?? 'unknown',
    );
  }

  @override
  Future<void> openAutostartSettings() => _invoke('openAutostartSettings');

  /// Native failures keep their message so the UI can show exactly what went wrong.
  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw VolumeException(
          e.code, e.message ?? 'Volume schedule error (${e.code})');
    } on MissingPluginException {
      throw const VolumeException(
          'UNSUPPORTED', 'Scheduled volume is only available on Android.');
    }
  }
}
