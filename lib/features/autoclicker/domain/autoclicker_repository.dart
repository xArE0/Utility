import 'autoclicker_entities.dart';

abstract class IAutoClickerRepository {
  Future<AutoClickerConfig> loadConfig();
  Future<void> saveConfig(AutoClickerConfig config);

  Future<AutoClickerStatus> getStatus();

  /// Emits whenever the overlay is shown/hidden, clicking starts/stops, or the tap count moves.
  Stream<AutoClickerStatus> get statusStream;

  /// Throws [AutoClickerException] (e.g. service not enabled) with a user-facing message.
  Future<void> showOverlay(AutoClickerConfig config);
  Future<void> hideOverlay();

  /// Starts tapping under the on-screen target. Throws [AutoClickerException] with the reason
  /// if it can't (no overlay, target hidden under the panel, ...).
  Future<void> startClicking();
  Future<void> stopClicking();

  /// Pushes new settings to a running overlay; they apply from the next tap.
  Future<void> updateConfig(AutoClickerConfig config);

  Future<void> openAccessibilitySettings();
  Future<void> openAppInfo();

  /// Xiaomi/Redmi/POCO only; throws [AutoClickerException] elsewhere or if the screen isn't found.
  Future<void> openAutostartSettings();
  Future<void> moveToBackground();

  Future<void> dispose();
}
