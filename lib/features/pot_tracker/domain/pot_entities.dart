class Player {
  String name;
  double net;
  Player({required this.name, this.net = 0});

  Map<String, dynamic> toMap() => {'name': name, 'net': net};
  static Player fromMap(Map m) => Player(name: m['name'] as String, net: (m['net'] as num).toDouble());
}

class RoundRecord {
  final DateTime time;
  final List<String> winners;
  final double ante;
  final int playerCount;
  RoundRecord({required this.time, required this.winners, required this.ante, required this.playerCount});

  Map<String, dynamic> toMap() => {
    'time': time.toIso8601String(),
    'winners': winners,
    'ante': ante,
    'playerCount': playerCount,
  };
  static RoundRecord fromMap(Map m) => RoundRecord(
    time: DateTime.parse(m['time'] as String),
    winners: List<String>.from(m['winners'] as List),
    ante: (m['ante'] as num).toDouble(),
    playerCount: (m['playerCount'] as num).toInt(),
  );
}
