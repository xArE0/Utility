import 'quickcheck_entities.dart';

abstract class IQuickCheckRepository {
  Future<void> init();

  // Answer Keys
  Future<List<AnswerKey>> getAllAnswerKeys();
  Future<AnswerKey?> getAnswerKeyForPage(int pageNumber);
  Future<void> upsertAnswerKey(AnswerKey key);
  Future<void> deleteAnswerKey(int pageNumber);
  Future<void> deleteAllAnswerKeys();

  // Attempts
  Future<List<AttemptRecord>> getAttemptsForPage(int pageNumber);
  Future<List<AttemptRecord>> getWrongAttemptsForPage(int pageNumber);
  Future<List<AttemptRecord>> getAllAttempts();
  Future<void> addAttempt(AttemptRecord record);
  Future<void> clearAttemptsForPage(int pageNumber);
  Future<void> clearAttemptForQuestion(int pageNumber, int questionIndex);
  Future<void> clearAllAttempts();

  Future<void> dispose();
}
