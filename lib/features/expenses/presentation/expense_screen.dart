import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/app_toast.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.govBlue),
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
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
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
    AppToast.show(context, '<Amount> <Note>  — e.g. -900/3 lunch',
        isError: true);
  }

  static const _avatarColors = [
    AppColors.govBlue,
    AppColors.sapphire,
    AppColors.jade,
    AppColors.rose,
    AppColors.amethyst,
    AppColors.aqua,
    AppColors.coral,
  ];

  void _confirmDeletePerson(Person person) {
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
            child:
                const Text('Khatam', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  /// Totals up top, then one compact row per person (tap to open, long-press to delete).
  Widget _buildPeopleList() {
    final people = _controller.people;
    if (people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline,
                  size: 56, color: AppColors.slate500),
              const SizedBox(height: 14),
              Text('No one here yet', style: AppTypography.titleMedium),
              const SizedBox(height: 6),
              Text('Add a person to start tracking who owes whom.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.slate400)),
            ],
          ),
        ),
      );
    }

    final owedToYou = people
        .where((p) => p.balance > 0)
        .fold<double>(0, (s, p) => s + p.balance);
    final youOwe = people
        .where((p) => p.balance < 0)
        .fold<double>(0, (s, p) => s - p.balance);

    Widget total(String label, double amount, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.slate400,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('Rs. ${amount.toStringAsFixed(0)}',
                  style: AppTypography.titleMedium
                      .copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        GlassCard(
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              total('Owed to you', owedToYou, AppColors.success),
              total('You owe', youOwe, AppColors.error),
              total('Net', owedToYou - youOwe,
                  owedToYou >= youOwe ? AppColors.success : AppColors.error),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final person in people)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildPersonRow(person),
          ),
      ],
    );
  }

  Widget _buildPersonRow(Person person) {
    final color =
        _avatarColors[person.name.hashCode.abs() % _avatarColors.length];
    final balance = person.balance;
    final last = person.transactions.isEmpty
        ? null
        : person.transactions
            .reduce((a, b) => a.dateTime.isAfter(b.dateTime) ? a : b);
    return Material(
      color: AppColors.slate800.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.slate700.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _controller.selectedPerson = person,
        onLongPress: () => _confirmDeletePerson(person),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  person.name.isEmpty
                      ? '?'
                      : person.name.characters.first.toUpperCase(),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      last == null
                          ? 'No entries yet'
                          : '${last.note.isEmpty ? 'Entry' : last.note} · ${_controller.timeAgo(last.dateTime)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${balance.abs().toStringAsFixed(0)}',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: balance == 0
                          ? AppColors.slate300
                          : (balance > 0 ? AppColors.success : AppColors.error),
                    ),
                  ),
                  Text(
                    balance == 0
                        ? 'settled'
                        : (balance > 0 ? 'owes you' : 'you owe'),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.slate500, fontSize: 11),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: AppColors.slate500),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Expense Tracker', style: AppTypography.titleLarge),
          backgroundColor: AppColors.slate900.withValues(alpha: 0.85),
          actions: [
            if (_controller.selectedPerson != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _controller.selectedPerson = null,
              ),
          ],
        ),
        floatingActionButton:
            _controller.initialized && _controller.selectedPerson == null
                ? FloatingActionButton.extended(
                    onPressed: () => _showAddPersonDialog(context),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add Person'),
                  )
                : null,
        body: !_controller.initialized
            ? const Center(child: CircularProgressIndicator())
            : _controller.selectedPerson == null
                ? _buildPeopleList()
                : Column(
                    children: [
                      Card(
                        margin: const EdgeInsets.all(16),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _controller.selectedPerson!.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.govBlue,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors:
                                        _controller.selectedPerson!.balance >= 0
                                            ? [AppColors.jade, AppColors.teal]
                                            : [
                                                AppColors.error,
                                                AppColors.coral
                                              ],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  'Rs. ${_controller.selectedPerson!.balance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.onAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.share,
                                    color: AppColors.amethyst, size: 28),
                                tooltip: 'Share',
                                onPressed: () => _controller.sharePersonHistory(
                                    _controller.selectedPerson!),
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
                              onPressed: () => _controller.addTransaction(
                                  _controller.selectedPerson!,
                                  20,
                                  'Transport Rs.20'),
                            ),
                            _QuickActionButton(
                              amount: -20,
                              onPressed: () => _controller.addTransaction(
                                  _controller.selectedPerson!,
                                  -20,
                                  'Transport Rs.20'),
                            ),
                            _QuickActionButton(
                              amount: 100,
                              onPressed: () => _controller.addTransaction(
                                  _controller.selectedPerson!,
                                  100,
                                  'Quick add Rs.100'),
                            ),
                            _QuickActionButton(
                              amount: -100,
                              onPressed: () => _controller.addTransaction(
                                  _controller.selectedPerson!,
                                  -100,
                                  'Quick subtract Rs.100'),
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
                          itemCount: _controller
                              .groupTransactionsByDate(
                                  _controller.selectedPerson!.transactions)
                              .entries
                              .length,
                          itemBuilder: (context, index) {
                            final entry = _controller
                                .groupTransactionsByDate(
                                    _controller.selectedPerson!.transactions)
                                .entries
                                .elementAt(index);
                            final day = DateFormat('EEEE').format(entry.key);
                            final date =
                                DateFormat('MMM dd, yyyy').format(entry.key);
                            final ago = _controller.timeAgo(entry.key);
                            final stats = _controller.calculateDayStats(
                                _controller.selectedPerson!.transactions,
                                entry.key);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$day > $date > $ago',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Flexible(
                                            child: _StatPill(
                                              label: stats['opening']!
                                                  .toStringAsFixed(0),
                                              color: AppColors.slate700,
                                              textColor: AppColors.slate200,
                                            ),
                                          ),
                                          Flexible(
                                            child: _StatPill(
                                              label: stats['closing']!
                                                  .toStringAsFixed(0),
                                              color: AppColors.amethyst
                                                  .withValues(alpha: 0.18),
                                              textColor: AppColors.amethyst,
                                            ),
                                          ),
                                          Flexible(
                                            child: _StatPill(
                                              label:
                                                  '+${stats['plus']!.toStringAsFixed(0)}',
                                              color: AppColors.success
                                                  .withValues(alpha: 0.18),
                                              textColor: AppColors.success,
                                            ),
                                          ),
                                          Flexible(
                                            child: _StatPill(
                                              label:
                                                  '-${stats['minus']!.abs().toStringAsFixed(0)}',
                                              color: AppColors.error
                                                  .withValues(alpha: 0.18),
                                              textColor: AppColors.error,
                                            ),
                                          ),
                                          Flexible(
                                            child: _StatPill(
                                                label:
                                                    'Δ ${(stats['plus']! + stats['minus']!).toStringAsFixed(0)}',
                                                color: (stats['plus']! +
                                                            stats['minus']!) >=
                                                        0
                                                    ? AppColors.success
                                                        .withValues(alpha: 0.18)
                                                    : AppColors.error
                                                        .withValues(
                                                            alpha: 0.18),
                                                textColor: (stats['plus']! +
                                                            stats['minus']!) >=
                                                        0
                                                    ? AppColors.success
                                                    : AppColors.error),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ...entry.value.map((tx) => Card(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 4),
                                      child: ListTile(
                                        title: Text(tx.note),
                                        subtitle: Text(DateFormat('hh:mm a')
                                            .format(tx.dateTime)),
                                        trailing: Text(
                                          'Rs ${tx.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: tx.amount >= 0
                                                ? AppColors.success
                                                : AppColors.error,
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
    // Tinted by direction so + and − read apart at a glance.
    final color = amount >= 0 ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.12),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape: const StadiumBorder(),
        ),
        child: Text(
            amount >= 0 ? '+Rs.${amount.toInt()}' : '-Rs.${(-amount).toInt()}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
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
