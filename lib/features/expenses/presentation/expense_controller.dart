import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/expense_entities.dart';
import '../domain/expense_repository.dart';

class ExpenseController extends ChangeNotifier {
  final IExpenseRepository _repository;
  
  List<Person> _people = [];
  Person? _selectedPerson;
  bool _initialized = false;

  List<Person> get people => _people;
  Person? get selectedPerson => _selectedPerson;
  bool get initialized => _initialized;

  ExpenseController({required IExpenseRepository repository}) : _repository = repository;

  set selectedPerson(Person? person) {
    _selectedPerson = person;
    notifyListeners();
  }

  Future<void> init() async {
    if (_initialized) return;
    await _repository.init();
    await loadPeople();
    _initialized = true;
    notifyListeners();
  }

  Future<void> loadPeople() async {
    final people = await _repository.getAllPeople();
    _people = people;
    if (_selectedPerson != null) {
      _selectedPerson = _people.firstWhere(
            (p) => p.id == _selectedPerson!.id,
        orElse: () => _selectedPerson!,
      );
    }
    notifyListeners();
  }

  Future<void> deletePerson(Person person) async {
    await _repository.deletePerson(person.id!);
    await loadPeople();
  }

  Future<void> addPerson(String name) async {
    await _repository.addPerson(name);
    await loadPeople();
  }

  Future<void> addTransaction(Person person, double amount, String note) async {
    final transaction = Transaction(personId: person.id, amount: amount, note: note);
    await _repository.addTransaction(transaction);
    await loadPeople();
  }

  Future<void> sharePersonHistory(Person person) async {
    final buffer = StringBuffer();
    buffer.writeln('Date,Time,Amount,Note');
    for (final tx in person.transactions) {
      final date = DateFormat('yyyy-MM-dd').format(tx.dateTime);
      final time = DateFormat('HH:mm').format(tx.dateTime);
      buffer.writeln('$date,$time,${tx.amount},${tx.note.replaceAll(',', ' ')}');
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${person.name}_history.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Transaction history for ${person.name}',
      subject: 'Transaction history for ${person.name}',
    );
  }

  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      final days = difference.inDays % 7;
      return '$weeks week${weeks > 1 ? 's' : ''}${days > 0 ? ' $days day${days > 1 ? 's' : ''}' : ''} ago';
    }

    if (difference.inDays < 30 * 12) {
      final months = difference.inDays ~/ 30;
      final days = difference.inDays % 30;
      return '$months month${months > 1 ? 's' : ''}${days > 0 ? ' $days day${days > 1 ? 's' : ''}' : ''} ago';
    }

    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    return '$years year${years > 1 ? 's' : ''}${months > 0 ? ' $months month${months > 1 ? 's' : ''}' : ''} ago';
  }

  Map<String, double> calculateDayStats(List<Transaction> allTx, DateTime day) {
    final dayTx = allTx.where((tx) =>
    tx.dateTime.year == day.year &&
        tx.dateTime.month == day.month &&
        tx.dateTime.day == day.day
    ).toList();

    final beforeDayTx = allTx.where((tx) =>
        tx.dateTime.isBefore(DateTime(day.year, day.month, day.day))
    ).toList();

    final opening = beforeDayTx.fold<double>(0, (sum, tx) => sum + tx.amount);
    final closing = opening + dayTx.fold<double>(0, (sum, tx) => sum + tx.amount);
    final plus = dayTx.where((tx) => tx.amount > 0).fold<double>(0, (sum, tx) => sum + tx.amount);
    final minus = dayTx.where((tx) => tx.amount < 0).fold<double>(0, (sum, tx) => sum + tx.amount);

    return {
      'opening': opening,
      'closing': closing,
      'plus': plus,
      'minus': minus,
    };
  }

  double evaluateExpression(String expr) {
    final tokens = _tokenize(expr);
    final rpn = _toRPN(tokens);
    return _evalRPN(rpn);
  }

  List<String> _tokenize(String s) {
    final tokens = <String>[];
    int i = 0;

    bool isOperator(String t) => t == '+' || t == '-' || t == '*' || t == '/';

    while (i < s.length) {
      final ch = s[i];
      if (ch == ' ' || ch == '\t') {
        i++;
        continue;
      }

      if ((ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) || ch == '.') {
        final sb = StringBuffer();
        while (i < s.length && ((s[i].codeUnitAt(0) >= 48 && s[i].codeUnitAt(0) <= 57) || s[i] == '.')) {
          sb.write(s[i]);
          i++;
        }
        tokens.add(sb.toString());
        continue;
      }

      if (ch == '+' || ch == '-' || ch == '*' || ch == '/' || ch == '(' || ch == ')') {
        if ((ch == '+' || ch == '-') &&
            (tokens.isEmpty || isOperator(tokens.last) || tokens.last == '(')) {
          tokens.add('0');
        }
        tokens.add(ch);
        i++;
        continue;
      }

      throw FormatException('Invalid character in expression: $ch');
    }

    return tokens;
  }

  List<String> _toRPN(List<String> tokens) {
    final output = <String>[];
    final ops = <String>[];

    int precedence(String op) {
      if (op == '+' || op == '-') return 1;
      if (op == '*' || op == '/') return 2;
      return 0;
    }

    bool isOperator(String t) => t == '+' || t == '-' || t == '*' || t == '/';

    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (double.tryParse(token) != null) {
        output.add(token);
      } else if (isOperator(token)) {
        while (ops.isNotEmpty && isOperator(ops.last) &&
            ((precedence(ops.last) > precedence(token)) ||
                (precedence(ops.last) == precedence(token)))) {
          output.add(ops.removeLast());
        }
        ops.add(token);
      } else if (token == '(') {
        ops.add(token);
      } else if (token == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          output.add(ops.removeLast());
        }
        if (ops.isEmpty || ops.last != '(') {
          throw FormatException('Mismatched parentheses');
        }
        ops.removeLast(); 
      } else {
        throw FormatException('Unknown token $token');
      }
    }

    while (ops.isNotEmpty) {
      final op = ops.removeLast();
      if (op == '(' || op == ')') throw FormatException('Mismatched parentheses');
      output.add(op);
    }

    return output;
  }

  double _evalRPN(List<String> rpn) {
    final stack = <double>[];

    for (final token in rpn) {
      final num = double.tryParse(token);
      if (num != null) {
        stack.add(num);
      } else if (token == '+' || token == '-' || token == '*' || token == '/') {
        if (stack.length < 2) throw FormatException('Invalid expression');
        final b = stack.removeLast();
        final a = stack.removeLast();
        double res;
        switch (token) {
          case '+':
            res = a + b;
            break;
          case '-':
            res = a - b;
            break;
          case '*':
            res = a * b;
            break;
          case '/':
            if (b == 0) throw FormatException('Division by zero');
            res = a / b;
            break;
          default:
            throw FormatException('Unsupported operator $token');
        }
        stack.add(res);
      } else {
        throw FormatException('Unknown token in RPN: $token');
      }
    }

    if (stack.length != 1) throw FormatException('Invalid expression');
    return stack.single;
  }

  Map<DateTime, List<Transaction>> groupTransactionsByDate(List<Transaction> transactions) {
    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final grouped = <DateTime, List<Transaction>>{};
    for (var tx in sortedTransactions) {
      final date = DateTime(tx.dateTime.year, tx.dateTime.month, tx.dateTime.day);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(tx);
    }

    return Map.fromEntries(
        grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key))
    );
  }

  Color getRandomPastelColor() {
    final random = math.Random();
    return Color.fromRGBO(
      200 + random.nextInt(56),
      200 + random.nextInt(56),
      200 + random.nextInt(56),
      0.9,
    );
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
