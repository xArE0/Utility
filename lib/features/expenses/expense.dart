import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';
import 'dart:ui'; // For ImageFilter
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/animated_background.dart';

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MoneyCalc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ExpenseTrackerScreen(),
    );
  }
}

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  late final Database _db;
  List<Person> _people = [];
  Person? _selectedPerson;
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initDB();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Color _getRandomPastelColor() {
    final random = math.Random();
    return Color.fromRGBO(
      200 + random.nextInt(56),
      200 + random.nextInt(56),
      200 + random.nextInt(56),
      0.9,
    );
  }

  Future<void> _initDB() async {
    _db = await openDatabase(
      join(await getDatabasesPath(), 'expense_tracker.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
                      CREATE TABLE people (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT
                      )
                    ''');
        await db.execute('''
                      CREATE TABLE transactions (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        personId INTEGER,
                        amount REAL,
                        note TEXT,
                        dateTime TEXT,
                        FOREIGN KEY (personId) REFERENCES people (id)
                      )
                    ''');
      },
    );
    await _loadPeople();
  }

  Future<void> _loadPeople() async {
    final List<Map<String, dynamic>> peopleMap = await _db.query('people');
    final people = peopleMap.map((map) => Person.fromMap(map)).toList();

    for (var person in people) {
      final transactionsMap = await _db.query(
          'transactions',
          where: 'personId = ?',
          whereArgs: [person.id],
          orderBy: 'dateTime DESC'
      );
      person.transactions.addAll(
          transactionsMap.map((map) => Transaction.fromMap(map))
      );
    }

    setState(() {
      _people = people;
      if (_selectedPerson != null) {
        _selectedPerson = people.firstWhere(
              (p) => p.id == _selectedPerson!.id,
          orElse: () => _selectedPerson!,
        );
      }
    });
  }

  Future<void> _deletePerson(Person person) async {
    await _db.delete(
      'transactions',
      where: 'personId = ?',
      whereArgs: [person.id],
    );

    await _db.delete(
      'people',
      where: 'id = ?',
      whereArgs: [person.id],
    );

    await _loadPeople();
  }

  Future<void> _addPerson(String name) async {
    await _db.insert('people', {'name': name});
    await _loadPeople();
  }

  Future<void> _addTransaction(Person person, double amount, String note) async {
    final transaction = Transaction(amount: amount, note: note);
    final id = await _db.insert('transactions', {
      ...transaction.toMap(),
      'personId': person.id,
    });

    final newTransaction = Transaction(
      id: id,
      personId: person.id,
      amount: amount,
      note: note,
      dateTime: transaction.dateTime,
    );

    setState(() {
      person.transactions.insert(0, newTransaction);
      final index = _people.indexWhere((p) => p.id == person.id);
      if (index != -1) {
        _people[index] = person;
        if (_selectedPerson?.id == person.id) {
          _selectedPerson = person;
        }
      }
    });

    await _loadPeople();
  }

  Future<void> _sharePersonHistory(Person person) async {
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

  String _timeAgo(DateTime date) {
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

    if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      final days = difference.inDays % 30;
      return '$months month${months > 1 ? 's' : ''}${days > 0 ? ' $days day${days > 1 ? 's' : ''}' : ''} ago';
    }

    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    return '$years year${years > 1 ? 's' : ''}${months > 0 ? ' $months month${months > 1 ? 's' : ''}' : ''} ago';
  }

  Map<String, double> _calculateDayStats(List<Transaction> allTx, DateTime day) {
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

  // Simple safe expression evaluator supporting + - * / and parentheses.
  // Handles unary + and - as well.
  double _evaluateExpression(String expr) {
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

      // number (including decimal)
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
        // handle unary +/-
        if ((ch == '+' || ch == '-') &&
            (tokens.isEmpty || isOperator(tokens.last) || tokens.last == '(')) {
          // treat unary by inserting 0 before it -> "0 - 5" or "0 + 5"
          tokens.add('0');
        }
        tokens.add(ch);
        i++;
        continue;
      }

      // unknown character -> throw so caller can show error
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
        ops.removeLast(); // pop '('
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

  void _handleInputSubmit() {
    final input = _inputController.text.trim();
    if (input.isEmpty || _selectedPerson == null) {
      _showInputError();
      return;
    }

    // find first whitespace to split amount expression and note
    final firstSpace = input.indexOf(RegExp(r'\s'));
    if (firstSpace == -1) {
      _showInputError();
      return;
    }

    final amountExpr = input.substring(0, firstSpace).trim();
    final note = input.substring(firstSpace).trim();
    try {
      final amount = _evaluateExpression(amountExpr);
      if (amount.isNaN) {
        _showInputError();
        return;
      }
      _addTransaction(_selectedPerson!, amount, note);
      _inputController.clear();
    } catch (e) {
      _showInputError();
    }
  }

  void _showInputError() {
    ScaffoldMessenger.of(context as BuildContext).showSnackBar(
      const SnackBar(content: Text('<Amount> <Note>  — amount can be an expression like -900/3')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Expense Tracker', style: AppTypography.titleLarge),
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: AppColors.slate900.withOpacity(0.5)),
            ),
          ),
          actions: [
            if (_selectedPerson != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedPerson = null),
              ),
          ],
        ),
        body: _selectedPerson == null
            ? Container(
                // Removed background image
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _people.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _people.length) {
                      return GlassCard(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showAddPersonDialog(context),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline,
                                size: 40,
                                color: AppColors.slate200),
                            SizedBox(height: 8),
                            Text(
                              "Add Person",
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.slate200,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
  
                    final person = _people[index];
                    return GlassCard(
                      borderRadius: BorderRadius.circular(16),
                      // Removed onTap from GlassCard to avoid conflict with InkWell
                      gradientColors: [
                        _getRandomPastelColor().withOpacity(0.3),
                        _getRandomPastelColor().withOpacity(0.1),
                      ],
                      child: InkWell( 
                        onTap: () => setState(() => _selectedPerson = person),
                        onLongPress: () {
                           // ... deletion dialog logic ...
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: AppColors.slate800,
                                title: Text('Delete ${person.name}?', style: AppTypography.titleLarge),
                                content: Text('Deal Khatam??', style: AppTypography.bodyMedium),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Nope'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deletePerson(person);
                                    },
                                    child: const Text('Khatam',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              person.name,
                              style: AppTypography.titleLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Rs. ${person.balance.toStringAsFixed(2)}',
                              style: AppTypography.titleMedium.copyWith(
                                color: person.balance >= 0
                                    ? AppColors.govGreen
                                    : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
          : Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedPerson!.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _selectedPerson!.balance >= 0
                            ? [Colors.green.shade400, Colors.green.shade700]
                            : [Colors.red.shade400, Colors.red.shade700],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      // No boxShadow here = no lift
                    ),
                    child: Text(
                      'Rs. ${_selectedPerson!.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.deepPurple, size: 28),
                    tooltip: 'Share',
                    onPressed: () => _sharePersonHistory(_selectedPerson!),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _QuickActionButton(
                  amount: 20,
                  onPressed: () => _addTransaction(_selectedPerson!, 20, 'Transport Rs.20'),
                ),
                _QuickActionButton(
                  amount: -20,
                  onPressed: () => _addTransaction(_selectedPerson!, -20, 'Transport Rs.20'),
                ),
                _QuickActionButton(
                  amount: 100,
                  onPressed: () => _addTransaction(_selectedPerson!, 100, 'Quick add Rs.100'),
                ),
                _QuickActionButton(
                  amount: -100,
                  onPressed: () => _addTransaction(_selectedPerson!, -100, 'Quick subtract Rs.100'),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(
                      labelText: '<Amount> <Note>',
                    ),
                    keyboardType: TextInputType.text,
                    onSubmitted: (_) => _handleInputSubmit(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleInputSubmit,
                    child: const Text('Sync'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _groupTransactionsByDate(_selectedPerson!.transactions).entries.length,
              itemBuilder: (context, index) {
                final entry = _groupTransactionsByDate(_selectedPerson!.transactions)
                    .entries.elementAt(index);
                final day = DateFormat('EEEE').format(entry.key); // Full day name
                final date = DateFormat('MMM dd, yyyy').format(entry.key);
                final ago = _timeAgo(entry.key);
                final stats = _calculateDayStats(_selectedPerson!.transactions, entry.key);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Day > Date (top row, left-aligned)
                          Text(
                            '$day > $date > $ago',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          // Stats row (bottom, right-aligned)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Flexible(
                                child: _StatPill(
                                  label: stats['opening']!.toStringAsFixed(0),
                                  color: Colors.blueGrey.shade100,
                                  textColor: Colors.blueGrey.shade800,
                                ),
                              ),
                              Flexible(
                                child: _StatPill(
                                  label: stats['closing']!.toStringAsFixed(0),
                                  color: Colors.deepPurple.shade100,
                                  textColor: Colors.deepPurple.shade800,
                                ),
                              ),
                              Flexible(
                                child: _StatPill(
                                  label: '+${stats['plus']!.toStringAsFixed(0)}',
                                  color: Colors.green.shade100,
                                  textColor: Colors.green.shade800,
                                ),
                              ),
                              Flexible(
                                child: _StatPill(
                                  label: '-${stats['minus']!.abs().toStringAsFixed(0)}',
                                  color: Colors.red.shade100,
                                  textColor: Colors.red.shade800,
                                ),
                              ),
                              Flexible(
                                child: _StatPill(
                                    label: 'Δ ${(stats['plus']! + stats['minus']!).toStringAsFixed(0)}',
                                    color: (stats['plus']! + stats['minus']!) >= 0
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    textColor: (stats['plus']! + stats['minus']!) >= 0
                                        ? Colors.green.shade800
                                        : Colors.red.shade800
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ...entry.value.map((tx) => Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(tx.note),
                        subtitle: Text(DateFormat('hh:mm a').format(tx.dateTime)),
                        trailing: Text(
                          'Rs ${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: tx.amount >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _showAddPersonDialog(BuildContext context) async {
    final nameController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Person'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _addPerson(nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<Transaction>> _groupTransactionsByDate(List<Transaction> transactions) {
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
}

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

class _QuickActionButton extends StatelessWidget {
  final double amount;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.amount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(amount >= 0 ? '+Rs.${amount.toInt()}' : '-Rs.${(-amount).toInt()}'),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _StatPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        softWrap: true,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
      ),
    );
  }
}

