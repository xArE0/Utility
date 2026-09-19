import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:utility/features/autoclicker/domain/autoclicker_entities.dart';
import 'package:utility/features/autoclicker/domain/autoclicker_repository.dart';
import 'package:utility/features/autoclicker/presentation/autoclicker_controller.dart';

class _FakeRepository implements IAutoClickerRepository {
  AutoClickerConfig saved = const AutoClickerConfig();
  AutoClickerStatus status = const AutoClickerStatus();
  AutoClickerException? showError;
  AutoClickerException? startError;
  final calls = <String>[];
  final _stream = StreamController<AutoClickerStatus>.broadcast();

  @override
  Future<AutoClickerConfig> loadConfig() async => saved;

  @override
  Future<void> saveConfig(AutoClickerConfig config) async => saved = config;

  @override
  Future<AutoClickerStatus> getStatus() async => status;

  @override
  Stream<AutoClickerStatus> get statusStream => _stream.stream;

  void push(AutoClickerStatus s) {
    status = s;
    _stream.add(s);
  }

  @override
  Future<void> showOverlay(AutoClickerConfig config) async {
    calls.add('showOverlay(${config.intervalMs},${config.maxClicks})');
    if (showError != null) throw showError!;
  }

  @override
  Future<void> hideOverlay() async => calls.add('hideOverlay');

  @override
  Future<void> startClicking() async {
    calls.add('startClicking');
    if (startError != null) throw startError!;
  }

  @override
  Future<void> stopClicking() async => calls.add('stopClicking');

  @override
  Future<void> updateConfig(AutoClickerConfig config) async =>
      calls.add('updateConfig(${config.intervalMs},${config.maxClicks})');

  @override
  Future<void> openAccessibilitySettings() async => calls.add('openAccessibilitySettings');

  @override
  Future<void> openAppInfo() async => calls.add('openAppInfo');

  @override
  Future<void> openAutostartSettings() async => calls.add('openAutostartSettings');

  @override
  Future<void> moveToBackground() async => calls.add('moveToBackground');

  @override
  Future<void> dispose() async => _stream.close();
}

void main() {
  late _FakeRepository repo;
  late AutoClickerController controller;

  setUp(() async {
    repo = _FakeRepository();
    controller = AutoClickerController(repository: repo);
    await controller.init();
  });

  tearDown(() => controller.dispose());

  test('interval is clamped to the supported range and persisted', () async {
    await controller.setInterval(5);
    expect(controller.config.intervalMs, AutoClickerConfig.minIntervalMs);
    expect(repo.saved.intervalMs, AutoClickerConfig.minIntervalMs);

    await controller.setInterval(99999999);
    expect(controller.config.intervalMs, AutoClickerConfig.maxIntervalMs);
  });

  test('max clicks 0 means unlimited and negatives are rejected', () async {
    expect(controller.config.isUnlimited, isTrue);
    await controller.setMaxClicks(25);
    expect(controller.config.isUnlimited, isFalse);
    await controller.setMaxClicks(-3);
    expect(controller.config.maxClicks, 0);
  });

  test('config is only pushed to native while the overlay is on screen', () async {
    await controller.setInterval(250);
    expect(repo.calls, isEmpty);

    repo.push(const AutoClickerStatus(serviceConnected: true, overlayVisible: true));
    await Future<void>.delayed(Duration.zero);
    await controller.setInterval(400);
    expect(repo.calls, ['updateConfig(400,0)']);
  });

  test('showOverlay sends the current config, then backgrounds the app', () async {
    await controller.setInterval(300);
    await controller.setMaxClicks(10);
    final error = await controller.showOverlay();

    expect(error, isNull);
    expect(repo.calls, ['showOverlay(300,10)', 'moveToBackground']);
  });

  test('native errors surface as a message and the app stays in the foreground', () async {
    repo.showError = const AutoClickerException('SERVICE_NOT_RUNNING', 'Turn on the service first.');
    final error = await controller.showOverlay();

    expect(error, 'Turn on the service first.');
    expect(repo.calls, ['showOverlay(500,0)']);
    expect(controller.busy, isFalse);
  });

  test('startClicking starts, then steps the app aside; failure keeps it in front', () async {
    expect(await controller.startClicking(), isNull);
    expect(repo.calls, ['startClicking', 'moveToBackground']);

    repo.calls.clear();
    repo.startError = const AutoClickerException('CANNOT_START', 'Drag the target away from the panel.');
    expect(await controller.startClicking(), 'Drag the target away from the panel.');
    expect(repo.calls, ['startClicking']);
  });

  test('stopClicking stays in the app', () async {
    expect(await controller.stopClicking(), isNull);
    expect(repo.calls, ['stopClicking']);
  });

  test('status updates from native are reflected', () async {
    repo.push(const AutoClickerStatus(
      serviceEnabled: true,
      serviceConnected: true,
      overlayVisible: true,
      running: true,
      taps: 42,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(controller.status.running, isTrue);
    expect(controller.status.taps, 42);
  });
}
