enum PageStatus { notStarted, inProgress, completed, perfected }

class AnswerKey {
  final int? id;
  final int pageNumber;
  final String name; // user-given session name
  final String answers; // e.g. 'ABCDE' for 5 questions, each char is A-E

  int get questionCount => answers.length;

  /// Display label: use name if set, fallback to "p<pageNumber>"
  String get displayName => name.isNotEmpty ? name : 'p$pageNumber';

  AnswerKey({this.id, required this.pageNumber, this.name = '', required this.answers});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'pageNumber': pageNumber,
    'name': name,
    'answers': answers.toUpperCase(),
  };

  factory AnswerKey.fromMap(Map<String, dynamic> m) => AnswerKey(
    id: m['id'] as int?,
    pageNumber: m['pageNumber'] as int,
    name: (m['name'] as String?) ?? '',
    answers: m['answers'] as String,
  );
}

class AttemptRecord {
  final int? id;
  final int pageNumber;
  final int questionIndex; // 0-based
  final String userAnswer; // single char A-E
  final String correctAnswer; // single char A-E
  final bool isCorrect;
  final String attemptedAt; // ISO8601

  AttemptRecord({
    this.id,
    required this.pageNumber,
    required this.questionIndex,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.attemptedAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'pageNumber': pageNumber,
    'questionIndex': questionIndex,
    'userAnswer': userAnswer,
    'correctAnswer': correctAnswer,
    'isCorrect': isCorrect ? 1 : 0,
    'attemptedAt': attemptedAt,
  };

  factory AttemptRecord.fromMap(Map<String, dynamic> m) => AttemptRecord(
    id: m['id'] as int?,
    pageNumber: m['pageNumber'] as int,
    questionIndex: m['questionIndex'] as int,
    userAnswer: m['userAnswer'] as String,
    correctAnswer: m['correctAnswer'] as String,
    isCorrect: m['isCorrect'] == 1,
    attemptedAt: m['attemptedAt'] as String,
  );
}
