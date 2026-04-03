import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/animated_background.dart';
import 'expense_controller.dart';
import '../domain/expense_entities.dart';
import '../data/local_expense_repository.dart';

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
  late final ExpenseController _controller;
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = ExpenseController(repository: LocalExpenseRepository());
    _controller.init();
    _controller.addListener(_onControllerNotify);
    _scrollController.addListener(_onScroll);
  }

  void _onControllerNotify() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerNotify);
    _scrollController.dispose();
    _inputController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleInputSubmit() {
    final input = _inputController.text.trim();
    if (input.isEmpty || _controller.selectedPerson == null) {
      _showInputError();
      return;
    }

    final firstSpace = input.indexOf(RegExp(r'\s'));
    if (firstSpace == -1) {
      _showInputError();
      return;
    }

    final amountExpr = input.substring(0, firstSpace).trim();
    final note = input.substring(firstSpace).trim();
    try {
      final amount = _controller.evaluateExpression(amountExpr);
      if (amount.isNaN) {
        _showInputError();
        return;
      }
      _controller.addTransaction(_controller.selectedPerson!, amount, note);
      _inputController.clear();
    } catch (e) {
      _showInputError();
    }
  }

  void _showInputError() {
    ScaffoldMessenger.of(context).showSnackBar(
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
          backgroundColor: AppColors.slate900.withOpacity(0.85),
          actions: [
            if (_controller.selectedPerson != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _controller.selectedPerson = null,
              ),
          ],
        ),
        body: !_controller.initialized
            ? const Center(child: CircularProgressIndicator())
            : _controller.selectedPerson == null
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _controller.people.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _controller.people.length) {
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
    
                      final person = _controller.people[index];
                      return GlassCard(
                        borderRadius: BorderRadius.circular(16),
                        gradientColors: [
                          _controller.getRandomPastelColor().withOpacity(0.3),
                          _controller.getRandomPastelColor().withOpacity(0.1),
                        ],
                        child: InkWell( 
                          onTap: () => _controller.selectedPerson = person,
                          onLongPress: () {
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
                                        _controller.deletePerson(person);
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
                              _controller.selectedPerson!.name,
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
                                colors: _controller.selectedPerson!.balance >= 0
                                    ? [Colors.green.shade400, Colors.green.shade700]
                                    : [Colors.red.shade400, Colors.red.shade700],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              'Rs. ${_controller.selectedPerson!.balance.toStringAsFixed(2)}',
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
                            onPressed: () => _controller.sharePersonHistory(_controller.selectedPerson!),
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
                          onPressed: () => _controller.addTransaction(_controller.selectedPerson!, 20, 'Transport Rs.20'),
                        ),
                        _QuickActionButton(
                          amount: -20,
                          onPressed: () => _controller.addTransaction(_controller.selectedPerson!, -20, 'Transport Rs.20'),
                        ),
                        _QuickActionButton(
                          amount: 100,
                          onPressed: () => _controller.addTransaction(_controller.selectedPerson!, 100, 'Quick add Rs.100'),
                        ),
                        _QuickActionButton(
                          amount: -100,
                          onPressed: () => _controller.addTransaction(_controller.selectedPerson!, -100, 'Quick subtract Rs.100'),
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
                      itemCount: _controller.groupTransactionsByDate(_controller.selectedPerson!.transactions).entries.length,
                      itemBuilder: (context, index) {
                        final entry = _controller.groupTransactionsByDate(_controller.selectedPerson!.transactions)
                            .entries.elementAt(index);
                        final day = DateFormat('EEEE').format(entry.key);
                        final date = DateFormat('MMM dd, yyyy').format(entry.key);
                        final ago = _controller.timeAgo(entry.key);
                        final stats = _controller.calculateDayStats(_controller.selectedPerson!.transactions, entry.key);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$day > $date > $ago',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
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
                _controller.addPerson(nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
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
