class Person {
  final int? id;
  final String name;
  final List<Transaction> transactions;

  Person({this.id, required this.name, List<Transaction>? transactions})
      : transactions = transactions ?? [];

  double get balance => transactions.fold(0, (sum, tx) => sum + tx.amount);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  static Person fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'],
      name: map['name'],
    );
  }
}

class Transaction {
  final int? id;
  final int? personId;
  final double amount;
  final String note;
  final DateTime dateTime;

  Transaction({
    this.id,
    this.personId,
    required this.amount,
    required this.note,
    DateTime? dateTime,
  }) : dateTime = dateTime ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'amount': amount,
      'note': note,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      personId: map['personId'],
      amount: map['amount'],
      note: map['note'],
      dateTime: DateTime.parse(map['dateTime']),
    );
  }
}
