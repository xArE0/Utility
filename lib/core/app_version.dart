const int appRevision = 1;

String get appVersion {
  final now = DateTime.now();
  final yy = (now.year % 100).toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  return '$yy.$mm.$dd.v$appRevision';
}
