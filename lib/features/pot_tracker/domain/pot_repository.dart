import 'pot_entities.dart';

abstract class IPotRepository {
  Future<void> init();
  Future<Map<String, dynamic>?> loadLatestSession();
  Future<void> saveSession(List<Player> players, double ante, List<RoundRecord> history);
  Future<void> dispose();
}
