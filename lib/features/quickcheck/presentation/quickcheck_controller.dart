import 'package:flutter/foundation.dart';
import '../domain/quickcheck_entities.dart';
import '../data/local_quickcheck_repository.dart';

/// Tracks the status of each page for the grid view.
class PageState {
  final AnswerKey answerKey;
  final PageStatus status;
  final int totalQuestions;
  final int attemptedCount;
  final int correctCount;
  final int wrongCount;

  double get accuracy =>
      attemptedCount == 0 ? 0 : correctCount / attemptedCount;

  PageState({
    required this.answerKey,
    required this.status,
    required this.totalQuestions,
    required this.attemptedCount,
    required this.correctCount,
    required this.wrongCount,
  });
}

/// Active practice session state.
class PracticeSession {
  final int pageNumber;
  final String sessionName; // display name for the session
  final List<int> questionIndices; // indices into the AnswerKey.answers string
  final String answers; // full answer string from AnswerKey
  final Map<int, String> flaggedAnswers; // 0-based question index -> corrected answer override
  final bool isRetryMode;
  final bool isContinueMode;
  int currentIndex; // pointer into questionIndices

  int get currentQuestionIndex => questionIndices[currentIndex];
  int get currentQuestionNumber => currentQuestionIndex + 1; // 1-based for display
  String get correctAnswer {
    final qIndex = currentQuestionIndex;
    if (flaggedAnswers.containsKey(qIndex)) {
      return flaggedAnswers[qIndex]!;
    }
    return answers[qIndex];
  }
  int get totalQuestions => questionIndices.length;
  int get questionsRemaining => totalQuestions - currentIndex;
  bool get isFinished => currentIndex >= totalQuestions;
  double get progress => totalQuestions == 0 ? 0 : currentIndex / totalQuestions;

  PracticeSession({
    required this.pageNumber,
    required this.sessionName,
    required this.questionIndices,
    required this.answers,
    Map<int, String>? flaggedAnswers,
    this.isRetryMode = false,
    this.isContinueMode = false,
    this.currentIndex = 0,
  }) : flaggedAnswers = flaggedAnswers ?? const {};
}

class QuickCheckController extends ChangeNotifier {
  final LocalQuickCheckRepository _repo = LocalQuickCheckRepository();
  bool _initialized = false;

  // State
  List<AnswerKey> _answerKeys = [];
  final Map<int, List<AttemptRecord>> _attemptsCache = {}; // pageNumber -> attempts
  PracticeSession? _activeSession;

  // Session results (tracked during practice)
  int _sessionCorrect = 0;
  int _sessionWrong = 0;

  // Getters
  List<AnswerKey> get answerKeys => _answerKeys;
  PracticeSession? get activeSession => _activeSession;
  int get sessionCorrect => _sessionCorrect;
  int get sessionWrong => _sessionWrong;

  // ── Initialization ──

  Future<void> init() async {
    if (_initialized) return;
    await _repo.init();
    await _reload();
    _initialized = true;
  }

  Future<void> _reload() async {
    _answerKeys = await _repo.getAllAnswerKeys();
    _answerKeys.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

    // Reload attempts for all pages
    _attemptsCache.clear();
    final allAttempts = await _repo.getAllAttempts();
    for (final a in allAttempts) {
      _attemptsCache.putIfAbsent(a.pageNumber, () => []).add(a);
    }
    notifyListeners();
  }

  // ── Page State Computation ──

  List<PageState> get pageStates {
    return _answerKeys.map((key) {
      final attempts = _attemptsCache[key.pageNumber] ?? [];
      return _computePageState(key, attempts);
    }).toList();
  }

  PageState _computePageState(AnswerKey key, List<AttemptRecord> attempts) {
    if (attempts.isEmpty) {
      return PageState(
        answerKey: key,
        status: PageStatus.notStarted,
        totalQuestions: key.questionCount,
        attemptedCount: 0,
        correctCount: 0,
        wrongCount: 0,
      );
    }

    // Get latest attempt per question index
    final latestByQuestion = <int, AttemptRecord>{};
    for (final a in attempts) {
      final existing = latestByQuestion[a.questionIndex];
      if (existing == null ||
          a.attemptedAt.compareTo(existing.attemptedAt) > 0) {
        latestByQuestion[a.questionIndex] = a;
      }
    }

    final attemptedCount = latestByQuestion.length;
    final correctCount =
        latestByQuestion.values.where((a) => a.isCorrect).length;
    final wrongCount =
        latestByQuestion.values.where((a) => !a.isCorrect).length;
    final totalQuestions = key.questionCount;

    PageStatus status;
    if (attemptedCount < totalQuestions) {
      status = PageStatus.inProgress;
    } else if (correctCount == totalQuestions) {
      status = PageStatus.perfected;
    } else {
      status = PageStatus.completed;
    }

    return PageState(
      answerKey: key,
      status: status,
      totalQuestions: totalQuestions,
      attemptedCount: attemptedCount,
      correctCount: correctCount,
      wrongCount: wrongCount,
    );
  }

  // ── Global Stats ──

  int get totalPages => _answerKeys.length;

  int get completedPages => pageStates
      .where((p) =>
          p.status == PageStatus.completed ||
          p.status == PageStatus.perfected)
      .length;

  int get perfectedPages =>
      pageStates.where((p) => p.status == PageStatus.perfected).length;

  double get overallAccuracy {
    int totalAttempted = 0;
    int totalCorrect = 0;
    for (final ps in pageStates) {
      totalAttempted += ps.attemptedCount;
      totalCorrect += ps.correctCount;
    }
    return totalAttempted == 0 ? 0 : totalCorrect / totalAttempted;
  }

  double get completionPercent =>
      totalPages == 0 ? 0 : completedPages / totalPages;

  // ── Answer Key Management ──

  Future<void> addAnswerKeys(int startPage, List<String> answersPerPage, {List<String>? names}) async {
    for (int i = 0; i < answersPerPage.length; i++) {
      final pageNum = startPage + i;
      final name = (names != null && i < names.length) ? names[i] : '';
      final key = AnswerKey(
        pageNumber: pageNum,
        name: name,
        answers: answersPerPage[i].toUpperCase().replaceAll(RegExp(r'[^A-E]'), ''),
      );
      if (key.answers.isNotEmpty) {
        await _repo.upsertAnswerKey(key);
      }
    }
    await _reload();
  }

  Future<void> deleteAnswerKey(int pageNumber) async {
    await _repo.deleteAnswerKey(pageNumber);
    await _repo.clearAttemptsForPage(pageNumber);
    await _reload();
  }

  Future<void> flagQuestion(int pageNumber, int questionIndex, String correctedAnswer) async {
    final oldKey = _answerKeys.firstWhere((k) => k.pageNumber == pageNumber);
    final oldEffectiveAnswer = oldKey.getEffectiveAnswer(questionIndex);
    
    final newFlagged = Map<int, String>.from(oldKey.flaggedAnswers);
    newFlagged[questionIndex] = correctedAnswer.toUpperCase();
    
    final newKey = AnswerKey(
      id: oldKey.id,
      pageNumber: oldKey.pageNumber,
      name: oldKey.name,
      answers: oldKey.answers,
      flaggedAnswers: newFlagged,
    );

    final newEffectiveAnswer = newKey.getEffectiveAnswer(questionIndex);
    if (oldEffectiveAnswer != newEffectiveAnswer) {
      await _repo.clearAttemptForQuestion(pageNumber, questionIndex);
      _attemptsCache[pageNumber]?.removeWhere((a) => a.questionIndex == questionIndex);
    }
    
    await _repo.upsertAnswerKey(newKey);
    await _reload();
  }

  Future<void> unflagQuestion(int pageNumber, int questionIndex) async {
    final oldKey = _answerKeys.firstWhere((k) => k.pageNumber == pageNumber);
    final oldEffectiveAnswer = oldKey.getEffectiveAnswer(questionIndex);
    
    final newFlagged = Map<int, String>.from(oldKey.flaggedAnswers);
    newFlagged.remove(questionIndex);
    
    final newKey = AnswerKey(
      id: oldKey.id,
      pageNumber: oldKey.pageNumber,
      name: oldKey.name,
      answers: oldKey.answers,
      flaggedAnswers: newFlagged,
    );

    final newEffectiveAnswer = newKey.getEffectiveAnswer(questionIndex);
    if (oldEffectiveAnswer != newEffectiveAnswer) {
      await _repo.clearAttemptForQuestion(pageNumber, questionIndex);
      _attemptsCache[pageNumber]?.removeWhere((a) => a.questionIndex == questionIndex);
    }
    
    await _repo.upsertAnswerKey(newKey);
    await _reload();
  }

  Future<void> updateAnswerKey(int pageNumber, {String? newAnswers, String? newName}) async {
    final oldKey = _answerKeys.firstWhere((k) => k.pageNumber == pageNumber);
    final finalAnswers = newAnswers ?? oldKey.answers;
    final finalName = newName ?? oldKey.name;
    
    final newFlagged = <int, String>{};
    oldKey.flaggedAnswers.forEach((idx, val) {
      if (idx < finalAnswers.length) {
        newFlagged[idx] = val;
      }
    });

    final newKey = AnswerKey(
      id: oldKey.id,
      pageNumber: oldKey.pageNumber,
      name: finalName,
      answers: finalAnswers,
      flaggedAnswers: newFlagged,
    );

    final maxLen = oldKey.answers.length > finalAnswers.length ? oldKey.answers.length : finalAnswers.length;
    for (int i = 0; i < maxLen; i++) {
      if (i >= finalAnswers.length) {
        await _repo.clearAttemptForQuestion(pageNumber, i);
        _attemptsCache[pageNumber]?.removeWhere((a) => a.questionIndex == i);
      } else {
        final oldEff = oldKey.getEffectiveAnswer(i);
        final newEff = newKey.getEffectiveAnswer(i);
        if (oldEff != newEff) {
          await _repo.clearAttemptForQuestion(pageNumber, i);
          _attemptsCache[pageNumber]?.removeWhere((a) => a.questionIndex == i);
        }
      }
    }

    await _repo.upsertAnswerKey(newKey);
    await _reload();
  }

  Future<void> deleteAllData() async {
    await _repo.deleteAllAnswerKeys();
    await _repo.clearAllAttempts();
    _activeSession = null;
    await _reload();
  }

  // ── Practice Session ──

  void startPractice(int pageNumber) {
    final key = _answerKeys.firstWhere((k) => k.pageNumber == pageNumber);
    final indices = List.generate(key.questionCount, (i) => i);

    _activeSession = PracticeSession(
      pageNumber: pageNumber,
      sessionName: key.displayName,
      questionIndices: indices,
      answers: key.answers,
      flaggedAnswers: Map<int, String>.from(key.flaggedAnswers),
    );
    _sessionCorrect = 0;
    _sessionWrong = 0;
    notifyListeners();
  }

   /// Continue from the first unanswered question, but show all questions.
   void continuePractice(int pageNumber) {
     final key = _answerKeys.firstWhere((k) => k.pageNumber == pageNumber);
     final attempts = _attemptsCache[pageNumber] ?? [];

     // Find which questions have been attempted (latest per question)
     final attemptedIndices = <int>{};
     for (final a in attempts) {
       attemptedIndices.add(a.questionIndex);
     }

     // Build list of ALL question indices, find first unanswered
     final allQuestions = List.generate(key.questionCount, (i) => i);
     int startIndex = 0;
     for (int i = 0; i < allQuestions.length; i++) {
       if (!attemptedIndices.contains(i)) {
         startIndex = i;
         break;
       }
     }

     // If everything is answered, just restart all
     if (attemptedIndices.length == key.questionCount) {
       startPractice(pageNumber);
       return;
     }

     _activeSession = PracticeSession(
       pageNumber: pageNumber,
       sessionName: key.displayName,
       questionIndices: allQuestions,
       answers: key.answers,
       flaggedAnswers: Map<int, String>.from(key.flaggedAnswers),
       isContinueMode: true,
       currentIndex: startIndex,
     );
     _sessionCorrect = 0;
     _sessionWrong = 0;
     notifyListeners();
   }

  void startRetryMistakes(int pageNumber) {
    final key = _answerKeys.firstWhere((k) => k.pageNumber == pageNumber);
    final attempts = _attemptsCache[pageNumber] ?? [];

    // Find latest attempt per question, keep only wrong ones
    final latestByQuestion = <int, AttemptRecord>{};
    for (final a in attempts) {
      final existing = latestByQuestion[a.questionIndex];
      if (existing == null ||
          a.attemptedAt.compareTo(existing.attemptedAt) > 0) {
        latestByQuestion[a.questionIndex] = a;
      }
    }

    final wrongIndices = latestByQuestion.entries
        .where((e) => !e.value.isCorrect)
        .map((e) => e.key)
        .toList()
      ..sort();

    if (wrongIndices.isEmpty) return;

    _activeSession = PracticeSession(
      pageNumber: pageNumber,
      sessionName: key.displayName,
      questionIndices: wrongIndices,
      answers: key.answers,
      flaggedAnswers: Map<int, String>.from(key.flaggedAnswers),
      isRetryMode: true,
    );
    _sessionCorrect = 0;
    _sessionWrong = 0;
    notifyListeners();
  }

  /// Returns true if the answer is correct.
  Future<bool> submitAnswer(String userAnswer) async {
    final session = _activeSession;
    if (session == null || session.isFinished) return false;

    final correct = session.correctAnswer;
    final isCorrect = userAnswer.toUpperCase() == correct;

    // Clear previous attempt for this question (so latest wins)
    await _repo.clearAttemptForQuestion(
      session.pageNumber,
      session.currentQuestionIndex,
    );

    final record = AttemptRecord(
      pageNumber: session.pageNumber,
      questionIndex: session.currentQuestionIndex,
      userAnswer: userAnswer.toUpperCase(),
      correctAnswer: correct,
      isCorrect: isCorrect,
      attemptedAt: DateTime.now().toIso8601String(),
    );
    await _repo.addAttempt(record);

    // Update local cache
    _attemptsCache
        .putIfAbsent(session.pageNumber, () => [])
        .removeWhere((a) => a.questionIndex == session.currentQuestionIndex);
    _attemptsCache[session.pageNumber]!.add(record);

    if (isCorrect) {
      _sessionCorrect++;
    } else {
      _sessionWrong++;
    }

    notifyListeners();
    return isCorrect;
  }

  void advanceToNext() {
    if (_activeSession == null) return;
    _activeSession!.currentIndex++;
    notifyListeners();
  }

   void jumpToQuestionIndex(int questionIndex) {
     if (_activeSession == null) return;
     // Find the position of this questionIndex in questionIndices
     final position = _activeSession!.questionIndices.indexOf(questionIndex);
     if (position >= 0 && position < _activeSession!.questionIndices.length) {
       _activeSession!.currentIndex = position;
       notifyListeners();
     }
   }

  AttemptRecord? getAttemptForQuestion(int pageNumber, int questionIndex) {
    final attempts = _attemptsCache[pageNumber] ?? [];
    AttemptRecord? latest;
    for (final a in attempts) {
      if (a.questionIndex == questionIndex) {
        if (latest == null || a.attemptedAt.compareTo(latest.attemptedAt) > 0) {
          latest = a;
        }
      }
    }
    return latest;
  }

  void endSession() {
    _activeSession = null;
    notifyListeners();
  }

  int getWrongCountForPage(int pageNumber) {
    final attempts = _attemptsCache[pageNumber] ?? [];
    final latestByQuestion = <int, AttemptRecord>{};
    for (final a in attempts) {
      final existing = latestByQuestion[a.questionIndex];
      if (existing == null ||
          a.attemptedAt.compareTo(existing.attemptedAt) > 0) {
        latestByQuestion[a.questionIndex] = a;
      }
    }
    return latestByQuestion.values.where((a) => !a.isCorrect).length;
  }

  int getCorrectCountForPage(int pageNumber) {
    final attempts = _attemptsCache[pageNumber] ?? [];
    final latestByQuestion = <int, AttemptRecord>{};
    for (final a in attempts) {
      final existing = latestByQuestion[a.questionIndex];
      if (existing == null ||
          a.attemptedAt.compareTo(existing.attemptedAt) > 0) {
        latestByQuestion[a.questionIndex] = a;
      }
    }
    return latestByQuestion.values.where((a) => a.isCorrect).length;
  }

  /// Returns the index of the first unanswered question (0-based), or -1 if all answered.
  int getResumeIndex(int pageNumber) {
    final key = _answerKeys.firstWhere((k) => k.pageNumber == pageNumber, orElse: () => AnswerKey(pageNumber: 0, answers: ''));
    if (key.questionCount == 0) return -1;
    
    final attempts = _attemptsCache[pageNumber] ?? [];
    final attemptedIndices = <int>{};
    for (final a in attempts) {
      attemptedIndices.add(a.questionIndex);
    }
    
    for (int i = 0; i < key.questionCount; i++) {
      if (!attemptedIndices.contains(i)) return i;
    }
    return -1; // all answered
  }

  Future<void> resetPageProgress(int pageNumber) async {
    await _repo.clearAttemptsForPage(pageNumber);
    _attemptsCache.remove(pageNumber);
    notifyListeners();
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }
}
