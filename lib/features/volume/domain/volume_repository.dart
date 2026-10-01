import 'volume_entities.dart';

abstract class IVolumeRepository {
  Future<List<VolumeRule>> loadRules();

  /// Replaces all rules and re-arms the alarm. Saving never applies a rule retroactively.
  Future<void> saveRules(List<VolumeRule> rules);

  /// Applies one rule's levels immediately (also how to test a rule).
  Future<void> applyNow(String ruleId);

  /// Live stream levels, ringer mode, next scheduled change and the recent run log.
  Future<VolumeState> getState();

  /// Xiaomi/Redmi/POCO only; throws [VolumeException] if the screen isn't found.
  Future<void> openAutostartSettings();

  /// Emits on any volume or ringer mode change while listening.
  Stream<void> get changes;
  Future<void> startListening();
  Future<void> stopListening();
  Future<void> dispose();
}
