import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../core/theme/app_colors.dart';

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

class PotTrackerPage extends StatefulWidget {
  const PotTrackerPage({super.key});

  @override
  State<PotTrackerPage> createState() => _PotTrackerPageState();
}

class _PotTrackerPageState extends State<PotTrackerPage> {
  final List<Player> players = [];
  double ante = 0.0;
  final List<RoundRecord> history = [];

  final TextEditingController _newPlayerCtl = TextEditingController();
  final TextEditingController _anteCtl = TextEditingController();

  Database? _db;
  OverlayEntry? _overlayEntry;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initDbAndLoad();
  }

  @override
  void dispose() {
    _newPlayerCtl.dispose();
    _anteCtl.dispose();
    _db?.close();
    super.dispose();
  }

  Future<void> _initDbAndLoad() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'pottracker_session.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE IF NOT EXISTS session (key TEXT PRIMARY KEY, value TEXT)');
    });
    await _loadSession();
  }

  Future<void> _saveSession() async {
    if (_db == null) return;
    final map = {
      'players': players.map((p) => p.toMap()).toList(),
      'ante': ante,
      'history': history.map((r) => r.toMap()).toList(),
    };
    final jsonStr = jsonEncode(map);
    await _db!.insert('session', {'key': 'latest', 'value': jsonStr}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _loadSession() async {
    if (_db == null) return;
    final rows = await _db!.query('session', where: 'key = ?', whereArgs: ['latest']);
    if (rows.isEmpty) return;
    final value = rows.first['value'] as String;
    final map = jsonDecode(value) as Map<String, dynamic>;
    final loadedPlayers = (map['players'] as List).map((e) => Player.fromMap(e as Map)).toList();
    final loadedAnte = (map['ante'] as num).toDouble();
    final loadedHistory = (map['history'] as List).map((e) => RoundRecord.fromMap(e as Map)).toList();
    setState(() {
      players.clear();
      players.addAll(loadedPlayers);
      ante = loadedAnte;
      history.clear();
      history.addAll(loadedHistory);
      _anteCtl.text = ante > 0 ? ante.toStringAsFixed(2) : '';
    });
  }

  String _generateDefaultName() {
    final regex = RegExp(r'^Player (\d+)$');
    var maxN = 0;
    for (final p in players) {
      final m = regex.firstMatch(p.name);
      if (m != null) {
        final n = int.tryParse(m.group(1) ?? '') ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return 'Player ${maxN + 1}';
  }

  void addPlayer(String name) {
    final useName = (name.trim().isEmpty) ? _generateDefaultName() : name.trim();
    setState(() {
      players.add(Player(name: useName));
      _newPlayerCtl.clear();
    });
    _saveSession();
  }

  void renamePlayer(int index) async {
    final ctl = TextEditingController(text: players[index].name);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Player'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Player name',
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctl.text),
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (res != null && res.trim().isNotEmpty) {
      setState(() => players[index].name = res.trim());
      await _saveSession();
    }
  }

  void removePlayer(int index) {
    setState(() => players.removeAt(index));
    _saveSession();
  }

  void setAnteFromInput() {
    final v = double.tryParse(_anteCtl.text);
    if (v != null && v >= 0) {
      setState(() => ante = double.parse(v.toStringAsFixed(2)));
      _saveSession();
    }
  }

  void settleWinner(int winnerIndex) {
    if (players.isEmpty) return;
    if (ante <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Set a non-zero ante first.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final n = players.length;
    setState(() {
      for (var i = 0; i < n; i++) {
        if (i == winnerIndex) continue;
        players[i].net = double.parse((players[i].net - ante).toStringAsFixed(2));
      }
      players[winnerIndex].net = double.parse((players[winnerIndex].net + ante * (n - 1)).toStringAsFixed(2));
      history.insert(
        0,
        RoundRecord(time: DateTime.now(), winners: [players[winnerIndex].name], ante: ante, playerCount: n),
      );
      _removeOverlay();
      _isDragging = false;
    });
    _saveSession();
  }

  void _showRadialMenu(Offset startGlobal) {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (_) => RadialMenuOverlay(
        players: players,
        startGlobal: startGlobal,
        onSelect: (index) => settleWinner(index),
        onCancel: _removeOverlay,
      ),
    );
    overlay.insert(_overlayEntry!);
    setState(() => _isDragging = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isDragging = false);
  }

  Future<void> _resetTransactions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Transactions?'),
        content: const Text('This will set all player nets to 0 and clear history. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      for (final p in players) {
        p.net = 0.0;
      }
      history.clear();
    });
    await _saveSession();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate900 : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? AppColors.slate900 : const Color(0xFF2C3E50),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 100),
              title: const Text('Pot Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${players.length} Players',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Ante: $ante',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'Reset',
                onPressed: _resetTransactions,
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear history',
                onPressed: () async {
                  setState(() => history.clear());
                  await _saveSession();
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3498DB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.attach_money, color: Color(0xFF3498DB)),
                            ),
                            const SizedBox(width: 12),
                            const Text('Set Ante', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _anteCtl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Per-player ante',
                                  prefixText: 'Rs. ',
                                  filled: true,
                                  fillColor: isDark ? AppColors.slate900.withOpacity(0.55) : Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: TextStyle(color: isDark ? AppColors.slate50 : AppColors.slate900),
                                onSubmitted: (_) => setAnteFromInput(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: setAnteFromInput,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3498DB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Set'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27AE60).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_add, color: Color(0xFF27AE60)),
                            ),
                            const SizedBox(width: 12),
                            const Text('Add Player', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newPlayerCtl,
                                decoration: InputDecoration(
                                  hintText: 'Player name (optional)',
                                  filled: true,
                                  fillColor: isDark ? AppColors.slate900.withOpacity(0.55) : Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: TextStyle(color: isDark ? AppColors.slate50 : AppColors.slate900),
                                onSubmitted: addPlayer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => addPlayer(_newPlayerCtl.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF27AE60),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Players', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      if (players.isNotEmpty)
                        Text('${players.length} total', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPlayersList(),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTapDown: (details) {
                      if (players.isEmpty) return;
                      _showRadialMenu(details.globalPosition);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF39C12),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _isDragging ? 'Drag to winner...' : 'Settle Round',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      if (history.isNotEmpty)
                        Text('${history.length} rounds', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHistory(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, Color? color}) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppColors.slate800.withOpacity(0.6) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: AppColors.slate700.withOpacity(0.6))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildPlayersList() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    if (players.isEmpty) {
      return _buildCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: isDark ? AppColors.slate500 : Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('No players yet', style: TextStyle(color: isDark ? AppColors.slate300 : Colors.grey.shade600, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Add players to get started', style: TextStyle(color: isDark ? AppColors.slate400 : Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: players.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final isPositive = p.net > 0;
        final isNegative = p.net < 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800.withOpacity(0.6) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? Border.all(color: AppColors.slate700.withOpacity(0.6)) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isPositive
                  ? const Color(0xFF27AE60).withOpacity(0.1)
                  : isNegative
                  ? const Color(0xFFE74C3C).withOpacity(0.1)
                  : Colors.grey.shade200,
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPositive
                      ? const Color(0xFF27AE60)
                      : isNegative
                      ? const Color(0xFFE74C3C)
                      : Colors.grey.shade700,
                ),
              ),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Net: Rs. ${p.net.toStringAsFixed(0)}',
              style: TextStyle(
                color: isPositive
                    ? const Color(0xFF27AE60)
                    : isNegative
                    ? const Color(0xFFE74C3C)
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => renamePlayer(i),
                  color: isDark ? AppColors.slate300 : Colors.grey.shade600,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => removePlayer(i),
                  color: isDark ? AppColors.slate300 : Colors.grey.shade600,
                ),
              ],
            ),
            onTap: () => renamePlayer(i),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHistory() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    if (history.isEmpty) {
      return _buildCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.history, size: 48, color: isDark ? AppColors.slate500 : Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('No rounds yet', style: TextStyle(color: isDark ? AppColors.slate300 : Colors.grey.shade600, fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: history.map((r) {
        final winnings = r.ante * (r.playerCount - 1);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800.withOpacity(0.6) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? Border.all(color: AppColors.slate700.withOpacity(0.6)) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF39C12).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.emoji_events, color: Color(0xFFF39C12)),
            ),
            title: Text(
              '${r.winners.join(', ')} won Rs. ${winnings.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Ante: Rs. ${r.ante.toStringAsFixed(2)} • ${r.playerCount} players'),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(r.time),
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : Colors.grey.shade500),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      }).toList(),
    );
  }
}

class RadialMenuOverlay extends StatefulWidget {
  final List<Player> players;
  final Offset startGlobal;
  final void Function(int) onSelect;
  final VoidCallback onCancel;

  const RadialMenuOverlay({
    super.key,
    required this.players,
    required this.startGlobal,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  State<RadialMenuOverlay> createState() => _RadialMenuOverlayState();
}

class _RadialMenuOverlayState extends State<RadialMenuOverlay> with SingleTickerProviderStateMixin {
  int? _highlightIndex;
  late Offset _center;
  late double _radius;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  Offset? _startPos;
  Offset _currentPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int? _getNearestIndex(Offset currentPos) {
    if (_startPos == null) return null;

    // Calculate movement delta from start position
    final delta = currentPos - _startPos!;
    final moveDistance = delta.distance;

    // Need minimum movement to select
    if (moveDistance < 30) return null;

    // Calculate angle of movement direction
    var angle = atan2(delta.dy, delta.dx);

    // Normalize angle to 0-2π range
    if (angle < 0) angle += 2 * pi;

    // Adjust for starting at top (-π/2)
    angle = angle + pi / 2;
    if (angle >= 2 * pi) angle -= 2 * pi;

    // Find which slice this angle falls into
    final angleStep = 2 * pi / widget.players.length;
    final sliceIndex = (angle / angleStep).floor() % widget.players.length;

    return sliceIndex;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { widget.onCancel(); return false; },
      child: LayoutBuilder(builder: (context, constraints) {
        _center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        _radius = min(constraints.maxWidth, constraints.maxHeight) * 0.35;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _startPos = details.localPosition;
            _currentPos = details.localPosition;
            setState(() => _highlightIndex = null);
          },
          onPanUpdate: (details) {
            _currentPos = details.localPosition;
            final newIndex = _getNearestIndex(_currentPos);
            if (_highlightIndex != newIndex) setState(() => _highlightIndex = newIndex);
          },
          onPanEnd: (_) {
            if (_highlightIndex != null) {
              widget.onSelect(_highlightIndex!);
            } else {
              widget.onCancel();
            }
            _startPos = null;
          },
          onPanCancel: () {
            widget.onCancel();
            _startPos = null;
          },
          onTapUp: (_) {
            widget.onCancel();
            _startPos = null;
          },
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                  for (var i = 0; i < widget.players.length; i++)
                    _buildSlice(i, _scaleAnim.value),
                  Positioned(
                    left: _center.dx - 36,
                    top: _center.dy - 36,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF39C12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF39C12).withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.emoji_events, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildSlice(int index, double scale) {
    final angleStep = 2 * pi / widget.players.length;
    final startAngle = -pi / 2 + index * angleStep - angleStep / 2;
    final isHighlighted = index == _highlightIndex;

    final name = widget.players[index].name.trim();
    final initials = name.isEmpty
        ? '?'
        : name
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();

    final midAngle = startAngle + angleStep / 2;
    final iconRadius = _radius * 0.7;
    final pos = Offset(_center.dx + iconRadius * cos(midAngle), _center.dy + iconRadius * sin(midAngle));

    return Stack(
      children: [
        Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: CustomPaint(
            size: Size.infinite,
            painter: _SlicePainter(
              center: _center,
              radius: _radius,
              startAngle: startAngle,
              sweepAngle: angleStep,
              color: isHighlighted ? const Color(0xFF4FC3F7) : Colors.grey.shade300,
              isHighlighted: isHighlighted,
            ),
          ),
        ),
        Positioned(
          left: pos.dx - 28,
          top: pos.dy - 28,
          child: Transform.scale(
            scale: scale,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: isHighlighted ? 1.2 : 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isHighlighted ? Colors.white : Colors.grey.shade700,
                      shape: BoxShape.circle,
                      boxShadow: isHighlighted ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ] : null,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: isHighlighted ? Colors.black87 : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(
                        color: isHighlighted ? Colors.white : Colors.grey.shade400,
                        fontSize: isHighlighted ? 14 : 12,
                        fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                        shadows: isHighlighted ? [
                          const Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                          ),
                        ] : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SlicePainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double startAngle;
  final double sweepAngle;
  final Color color;
  final bool isHighlighted;

  _SlicePainter({
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.sweepAngle,
    required this.color,
    required this.isHighlighted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final innerRadius = radius * 0.35;

    final path = Path();

    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
    );

    final endAngle = startAngle + sweepAngle;
    path.lineTo(
      center.dx + innerRadius * cos(endAngle),
      center.dy + innerRadius * sin(endAngle),
    );

    path.arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      endAngle,
      -sweepAngle,
      false,
    );

    path.close();

    canvas.drawPath(path, paint);

    if (isHighlighted) {
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_SlicePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isHighlighted != isHighlighted;
  }}