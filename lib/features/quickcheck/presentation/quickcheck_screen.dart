import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../domain/quickcheck_entities.dart';
import 'quickcheck_controller.dart';
import 'widgets/swipe_answer_pad.dart';

class QuickCheckScreen extends StatefulWidget {
  const QuickCheckScreen({super.key});

  @override
  State<QuickCheckScreen> createState() => _QuickCheckScreenState();
}

class _QuickCheckScreenState extends State<QuickCheckScreen>
    with TickerProviderStateMixin {
  final QuickCheckController _ctrl = QuickCheckController();
  bool _loading = true;

  // Feedback state during practice
  String? _feedbackAnswer;
  bool? _feedbackCorrect;
  Timer? _feedbackTimer;

  // Animation controllers
  late AnimationController _resultSlideCtrl;
  late Animation<Offset> _resultSlideAnim;

  @override
  void initState() {
    super.initState();
    _resultSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resultSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _resultSlideCtrl, curve: Curves.easeOutCubic));

    _init();
  }

  Future<void> _init() async {
    await _ctrl.init();
    _ctrl.addListener(_onControllerUpdate);
    if (mounted) setState(() => _loading = false);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.dispose();
    _feedbackTimer?.cancel();
    _resultSlideCtrl.dispose();
    super.dispose();
  }

  // ── Answer Key Input ──

  void _showAddAnswerKeySheet() {
    final pageCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final answersCtrl = TextEditingController();
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: AppColors.slate800.withOpacity(0.98),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: const Border(
                  top: BorderSide(color: AppColors.slate600, width: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.slate500,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("Add Answer Key",
                        style: AppTypography.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      "Give it a name, type answers as letters: ABCDEABC...",
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.slate400),
                    ),
                    const SizedBox(height: 20),
                    // Row: Page number + Session name
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: pageCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: AppTypography.bodyLarge,
                            decoration: InputDecoration(
                              labelText: "Page #",
                              labelStyle: AppTypography.bodySmall
                                  .copyWith(color: AppColors.slate400),
                              filled: true,
                              fillColor: AppColors.slate700.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppColors.govBlue, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            style: AppTypography.bodyLarge,
                            decoration: InputDecoration(
                              labelText: "Session Name (optional)",
                              hintText: "e.g. Physics Ch3",
                              hintStyle: AppTypography.bodySmall
                                  .copyWith(color: AppColors.slate600),
                              labelStyle: AppTypography.bodySmall
                                  .copyWith(color: AppColors.slate400),
                              filled: true,
                              fillColor: AppColors.slate700.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppColors.govBlue, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Answers
                    TextField(
                      controller: answersCtrl,
                      maxLines: 5,
                      minLines: 3,
                      textCapitalization: TextCapitalization.characters,
                      style: AppTypography.bodyLarge.copyWith(
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: "Answers (one page per line)",
                        hintText: "ABCDEBAC\nDCBAEABD",
                        hintStyle: AppTypography.bodyMedium
                            .copyWith(color: AppColors.slate600),
                        labelStyle: AppTypography.bodyMedium
                            .copyWith(color: AppColors.slate400),
                        filled: true,
                        fillColor: AppColors.slate700.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.govBlue, width: 1.5),
                        ),
                        errorText: errorText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Preview
                    Builder(builder: (context) {
                      final lines = answersCtrl.text
                          .split('\n')
                          .where((l) => l.trim().isNotEmpty)
                          .toList();
                      final startPage =
                          int.tryParse(pageCtrl.text) ?? 0;
                      if (lines.isEmpty || startPage == 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          "${lines.length} page(s): p$startPage–p${startPage + lines.length - 1}  •  ${lines.map((l) => l.replaceAll(RegExp(r'[^A-Ea-e]'), '').length).join(', ')} Qs",
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.govGreen),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          final startPage =
                              int.tryParse(pageCtrl.text);
                          final rawLines = answersCtrl.text
                              .split('\n')
                              .where((l) => l.trim().isNotEmpty)
                              .toList();

                          if (startPage == null || startPage <= 0) {
                            setSheetState(() =>
                                errorText = 'Enter a valid page number');
                            return;
                          }
                          if (rawLines.isEmpty) {
                            setSheetState(
                                () => errorText = 'Enter at least one line of answers');
                            return;
                          }

                          // Clean: keep only A-E characters
                          final cleaned = rawLines
                              .map((l) => l
                                  .toUpperCase()
                                  .replaceAll(RegExp(r'[^A-E]'), ''))
                              .where((l) => l.isNotEmpty)
                              .toList();

                          if (cleaned.isEmpty) {
                            setSheetState(() =>
                                errorText = 'No valid answers found (A-E only)');
                            return;
                          }

                          // Build names list: user-given name for first, auto-increment for rest
                          final baseName = nameCtrl.text.trim();
                          final names = List.generate(cleaned.length, (i) {
                            if (baseName.isEmpty) return '';
                            if (cleaned.length == 1) return baseName;
                            return '$baseName (${i + 1})';
                          });

                          _ctrl.addAnswerKeys(startPage, cleaned, names: names);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.govBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text("Save Answer Key",
                            style: AppTypography.labelLarge
                                .copyWith(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Practice Answer Handler ──

  void _onSwipeAnswer(String answer) {
    final session = _ctrl.activeSession;
    if (session == null || session.isFinished) return;
    if (_feedbackAnswer != null) return; // Already processing

    _ctrl.submitAnswer(answer).then((isCorrect) {
      if (!mounted) return;
      setState(() {
        _feedbackAnswer = answer;
        _feedbackCorrect = isCorrect;
      });

      HapticFeedback.mediumImpact();

      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        _ctrl.advanceToNext();
        setState(() {
          _feedbackAnswer = null;
          _feedbackCorrect = null;
        });

        // Check if session just ended
        if (_ctrl.activeSession?.isFinished == true) {
          _resultSlideCtrl.forward(from: 0);
        }
      });
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    if (_ctrl.activeSession != null) {
      return _buildPracticeView(context);
    }
    return _buildPageGridView(context);
  }

  // ═══════════════════════════════════════════
  // PAGE GRID VIEW
  // ═══════════════════════════════════════════

  Widget _buildPageGridView(BuildContext context) {
    final pages = _ctrl.pageStates;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.slate900.withOpacity(0.5),
          title: Text("MCQ Practice", style: AppTypography.titleLarge),
          actions: [
            if (pages.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.slate300),
                color: AppColors.slate800,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (val) {
                  if (val == 'clear_all') {
                    _showClearAllDialog();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Text('Clear All Data',
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppColors.govBlue))
            : pages.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      _buildStatsHeader(pages),
                      Expanded(child: _buildGrid(pages)),
                    ],
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddAnswerKeySheet,
          backgroundColor: AppColors.govBlue,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text("Add Keys",
              style: AppTypography.labelLarge.copyWith(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.govBlue.withOpacity(0.2),
                    AppColors.govGreen.withOpacity(0.2),
                  ],
                ),
                border: Border.all(
                  color: AppColors.govBlue.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 56,
                color: AppColors.govBlue,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "Ready to Practice?",
              style: AppTypography.headlineMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Add answer keys to start practicing MCQs.\nType answers as ABCDE... per page.",
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.govBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.govBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                "Tap the + button to add your first key",
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.govBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(List<PageState> pages) {
    final total = _ctrl.totalPages;
    final completed = _ctrl.completedPages;
    final perfected = _ctrl.perfectedPages;
    final accuracy = _ctrl.overallAccuracy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              "📊",
              "$completed",
              "/$total",
              AppColors.govBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              "🎯",
              "${(accuracy * 100).toStringAsFixed(0)}",
              "%",
              accuracy >= 0.8 ? AppColors.govGreen : AppColors.govGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              "⭐",
              "$perfected",
              "",
              const Color(0xFFEAB308),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String value, String suffix, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AppTypography.titleLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: AppTypography.bodySmall.copyWith(
                      color: color.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<PageState> pages) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: pages.length,
      itemBuilder: (context, i) => _buildPageCard(pages[i]),
    );
  }

  Widget _buildPageCard(PageState page) {
    Color statusColor;
    IconData statusIcon;
    switch (page.status) {
      case PageStatus.notStarted:
        statusColor = AppColors.slate600;
        statusIcon = Icons.circle_outlined;
        break;
      case PageStatus.inProgress:
        statusColor = AppColors.govGold;
        statusIcon = Icons.show_chart;
        break;
      case PageStatus.completed:
        statusColor = AppColors.govGreen;
        statusIcon = Icons.check_circle;
        break;
      case PageStatus.perfected:
        statusColor = const Color(0xFFEAB308);
        statusIcon = Icons.star_rounded;
        break;
    }

    final progressValue = page.attemptedCount / page.totalQuestions;

    return GestureDetector(
      onTap: () => _showPageActions(page),
      onLongPress: () => _showPageDeleteDialog(page),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.slate800.withOpacity(0.9),
              AppColors.slate800.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background gradient accent
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
               Padding(
                 padding: const EdgeInsets.all(16),
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Header: Title and questions count
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           page.answerKey.displayName,
                           style: AppTypography.headlineSmall.copyWith(
                             color: Colors.white,
                             fontWeight: FontWeight.w700,
                           ),
                           softWrap: true,
                           maxLines: 4,
                         ),
                         const SizedBox(height: 3),
                         Text(
                           "${page.totalQuestions} questions",
                           style: AppTypography.bodySmall.copyWith(
                             color: AppColors.slate400,
                           ),
                         ),
                       ],
                     ),
                     // Progress bar
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         ClipRRect(
                           borderRadius: BorderRadius.circular(6),
                           child: LinearProgressIndicator(
                             value: progressValue,
                             minHeight: 5,
                             backgroundColor: AppColors.slate700,
                             valueColor: AlwaysStoppedAnimation<Color>(
                               page.status == PageStatus.perfected
                                   ? const Color(0xFFEAB308)
                                   : page.status == PageStatus.completed
                                       ? AppColors.govGreen
                                       : page.status == PageStatus.inProgress
                                           ? AppColors.govGold
                                           : AppColors.slate600,
                             ),
                           ),
                         ),
                         const SizedBox(height: 6),
                         // Stats row
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "${page.correctCount}",
                                    style: AppTypography.labelLarge.copyWith(
                                      color: AppColors.govGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                   TextSpan(
                                     text: " ✓",
                                     style: AppTypography.bodySmall.copyWith(
                                       color: AppColors.govGreen,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                             RichText(
                               text: TextSpan(
                                 children: [
                                   TextSpan(
                                     text: "${page.wrongCount}",
                                     style: AppTypography.labelLarge.copyWith(
                                       color: AppColors.error,
                                       fontWeight: FontWeight.w700,
                                     ),
                                   ),
                                   TextSpan(
                                     text: " ✗",
                                     style: AppTypography.bodySmall.copyWith(
                                       color: AppColors.error,
                                     ),
                                   ),
                                ],
                              ),
                            ),
                            Text(
                              "${(page.accuracy * 100).toStringAsFixed(0)}%",
                              style: AppTypography.labelLarge.copyWith(
                                color: page.accuracy >= 0.8
                                    ? AppColors.govGreen
                                    : AppColors.govGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPageActions(PageState page) {
    final wrongCount = page.wrongCount;
    final resumeIdx = _ctrl.getResumeIndex(page.answerKey.pageNumber);
    final canContinue = resumeIdx >= 0 && page.status == PageStatus.inProgress;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.slate800.withOpacity(0.98),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slate500,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
               const SizedBox(height: 20),
               Text(
                 page.answerKey.displayName,
                 style: AppTypography.headlineSmall,
                 softWrap: true,
                 maxLines: 4,
               ),
               const SizedBox(height: 4),
               Text(
                 "${page.answerKey.questionCount} questions  •  ${page.correctCount}✓ ${wrongCount}✗",
                 style: AppTypography.bodySmall
                     .copyWith(color: AppColors.slate400, letterSpacing: 1.5),
                 softWrap: true,
               ),
              const SizedBox(height: 24),
              // Continue button (only if in-progress)
              if (canContinue) ...[
                _actionButton(
                  icon: Icons.fast_forward_rounded,
                  label: "Continue from Q${resumeIdx + 1}",
                  color: AppColors.govGreen,
                  onTap: () {
                    Navigator.pop(ctx);
                    _ctrl.continuePractice(page.answerKey.pageNumber);
                  },
                ),
                const SizedBox(height: 10),
              ],
              // Practice All button
              _actionButton(
                icon: Icons.play_arrow_rounded,
                label: "Practice All",
                color: AppColors.govBlue,
                onTap: () {
                  Navigator.pop(ctx);
                  _ctrl.startPractice(page.answerKey.pageNumber);
                },
              ),
              if (wrongCount > 0) ...[
                const SizedBox(height: 10),
                _actionButton(
                  icon: Icons.replay_rounded,
                  label: "Retry Mistakes ($wrongCount)",
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(ctx);
                    _ctrl.startRetryMistakes(page.answerKey.pageNumber);
                  },
                ),
              ],
              const SizedBox(height: 10),
              _actionButton(
                icon: Icons.restart_alt_rounded,
                label: "Reset Progress",
                color: AppColors.slate500,
                onTap: () {
                  Navigator.pop(ctx);
                  _ctrl.resetPageProgress(page.answerKey.pageNumber);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(label,
            style: AppTypography.labelLarge.copyWith(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
      ),
    );
  }

  void _showPageDeleteDialog(PageState page) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text("Delete ${page.answerKey.displayName}?",
            style: AppTypography.titleLarge),
        content: Text(
          "This will remove the answer key and all attempt history for this session.",
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.slate400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel",
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ctrl.deleteAnswerKey(page.answerKey.pageNumber);
            },
            child: Text("Delete",
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text("Clear All Data?", style: AppTypography.titleLarge),
        content: Text(
          "This will permanently delete all answer keys and attempt history. This cannot be undone.",
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.slate400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel",
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ctrl.deleteAllData();
            },
            child: Text("Delete Everything",
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PRACTICE VIEW
  // ═══════════════════════════════════════════

  Widget _buildPracticeView(BuildContext context) {
    final session = _ctrl.activeSession!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _ctrl.endSession();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.slate900,
        body: SafeArea(
          child: session.isFinished
              ? _buildSessionResults(session)
              : _buildActiveQuestion(session),
        ),
      ),
    );
  }

  Widget _buildActiveQuestion(PracticeSession session) {
    final questionNum = session.currentQuestionNumber;
    final total = session.totalQuestions;
    final progress = session.progress;
    // We show 5 options if any answer on this page uses E
    final hasE = session.answers.contains('E');
    final optionCount = hasE ? 5 : 4;

    return Column(
      children: [
        // ── Top bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => _showExitPracticeDialog(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.slate800,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close, color: AppColors.slate400, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.isRetryMode
                          ? "Retry • ${session.sessionName}"
                          : session.isContinueMode
                              ? "Continue • ${session.sessionName}"
                              : session.sessionName,
                      style: AppTypography.titleMedium
                          .copyWith(color: AppColors.slate300),
                    ),
                    const SizedBox(height: 4),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.slate700,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _feedbackCorrect == true
                              ? AppColors.govGreen
                              : _feedbackCorrect == false
                                  ? AppColors.error
                                  : AppColors.govBlue,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
               // Score - show all-time right/wrong for this page, not just session
               Container(
                 padding:
                     const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: AppColors.slate800,
                   borderRadius: BorderRadius.circular(10),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text("${_ctrl.getCorrectCountForPage(session.pageNumber)}✓",
                         style: AppTypography.titleSmall
                             .copyWith(color: AppColors.govGreen, fontWeight: FontWeight.bold)),
                     const SizedBox(width: 8),
                     Text("${_ctrl.getWrongCountForPage(session.pageNumber)}✗",
                         style: AppTypography.titleSmall
                             .copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
                   ],
                 ),
               ),
            ],
          ),
        ),

        // ── Question Number ──
        Expanded(
          flex: 2,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(session.currentIndex),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Q$questionNum",
                    style: AppTypography.displayLarge.copyWith(
                      color: _feedbackCorrect == true
                          ? AppColors.govGreen
                          : _feedbackCorrect == false
                              ? AppColors.error
                              : Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showJumpToQuestionSheet(session),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.slate800,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.slate700.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$questionNum of $total",
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.slate400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: AppColors.slate500,
                          ),
                        ],
                      ),
                    ),
                   ),
                   // Show correct answer on both correct and wrong
                   if (_feedbackCorrect != null) ...[
                     const SizedBox(height: 12),
                     Text(
                       "Answer: ${session.correctAnswer}",
                       style: AppTypography.titleMedium.copyWith(
                         color: AppColors.govGreen,
                         fontWeight: FontWeight.w700,
                       ),
                     ),
                   ],
                 ],
               ),
             ),
           ),
         ),

        // ── Swipe Pad ──
        Expanded(
          flex: 3,
          child: SwipeAnswerPad(
            optionCount: optionCount,
            enabled: _feedbackAnswer == null,
            onAnswer: _onSwipeAnswer,
            feedbackAnswer: _feedbackAnswer,
            feedbackCorrect: _feedbackCorrect,
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  void _showJumpToQuestionSheet(PracticeSession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.slate900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Create a GlobalKey for the current question button for auto-scroll
            final currentQuestionKey = GlobalKey();
            
            // Schedule scroll to current question after the first frame
            Future.delayed(const Duration(milliseconds: 100), () {
              try {
                Scrollable.ensureVisible(
                  currentQuestionKey.currentContext!,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: 0.5, // Center the button on screen
                );
              } catch (e) {
                // Ignore if context no longer available
              }
            });
            
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Jump to Question",
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.slate800,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: AppColors.slate400, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                     Flexible(
                       child: SingleChildScrollView(
                         child: Wrap(
                           spacing: 10,
                           runSpacing: 10,
                           children: List.generate(session.questionIndices.length, (i) {
                             final qIndex = session.questionIndices[i];
                             final qNum = qIndex + 1;
                             final isCurrent = qIndex == session.currentQuestionIndex;

                            // Check attempt status
                            final attempt = _ctrl.getAttemptForQuestion(session.pageNumber, qIndex);
                            Color bgColor = AppColors.slate800;
                            Color borderCol = Colors.transparent;
                            Color textColor = AppColors.slate300;
                            
                            if (attempt != null) {
                              if (attempt.isCorrect) {
                                bgColor = AppColors.govGreen.withOpacity(0.15);
                                borderCol = AppColors.govGreen.withOpacity(0.3);
                                textColor = AppColors.govGreen;
                              } else {
                                bgColor = AppColors.error.withOpacity(0.15);
                                borderCol = AppColors.error.withOpacity(0.3);
                                textColor = AppColors.error;
                              }
                            }
                            
                            if (isCurrent) {
                              borderCol = AppColors.govBlue;
                              bgColor = AppColors.govBlue.withOpacity(0.2);
                              textColor = Colors.white;
                            }
                            
                             return GestureDetector(
                               key: isCurrent ? currentQuestionKey : null,
                               onTap: () {
                                 Navigator.pop(context);
                                 setState(() {
                                   _feedbackAnswer = null;
                                   _feedbackCorrect = null;
                                   _feedbackTimer?.cancel();
                                   _ctrl.jumpToQuestionIndex(qIndex);
                                 });
                               },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  border: Border.all(
                                    color: borderCol, 
                                    width: isCurrent ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    "$qNum",
                                    style: AppTypography.titleSmall.copyWith(
                                      color: textColor,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                     ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showExitPracticeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text("Exit Practice?", style: AppTypography.titleLarge),
        content: Text(
          "Your progress so far has been saved.",
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.slate400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Continue",
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.govBlue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ctrl.endSession();
            },
            child: Text("Exit",
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.slate400)),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionResults(PracticeSession session) {
    final total = _ctrl.sessionCorrect + _ctrl.sessionWrong;
    final accuracy = total == 0 ? 0.0 : _ctrl.sessionCorrect / total;
    final isGreat = accuracy >= 0.8;
    final isPerfect = accuracy == 1.0;

    return SlideTransition(
      position: _resultSlideAnim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji
              Text(
                isPerfect
                    ? "⭐"
                    : isGreat
                        ? "🎉"
                        : "📊",
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 20),
              Text(
                isPerfect
                    ? "Perfect!"
                    : isGreat
                        ? "Great Job!"
                        : "Keep Practicing",
                style: AppTypography.headlineMedium.copyWith(
                  color: isPerfect
                      ? const Color(0xFFEAB308)
                      : isGreat
                          ? AppColors.govGreen
                          : AppColors.slate300,
                ),
              ),
              const SizedBox(height: 24),
              // Stats row
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.slate800,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.slate700),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _resultStat("Correct", "${_ctrl.sessionCorrect}",
                        AppColors.govGreen),
                    Container(
                        width: 1,
                        height: 36,
                        color: AppColors.slate700),
                    _resultStat(
                        "Wrong", "${_ctrl.sessionWrong}", AppColors.error),
                    Container(
                        width: 1,
                        height: 36,
                        color: AppColors.slate700),
                    _resultStat(
                      "Accuracy",
                      "${(accuracy * 100).toStringAsFixed(0)}%",
                      isGreat ? AppColors.govGreen : AppColors.govGold,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                session.isRetryMode
                    ? "${session.sessionName} • Retry Mode"
                    : session.isContinueMode
                        ? "${session.sessionName} • Continued"
                        : session.sessionName,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.slate500),
              ),
              const SizedBox(height: 28),
              // Actions
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _ctrl.endSession(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.govBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text("Back to Pages",
                      style: AppTypography.labelLarge
                          .copyWith(color: Colors.white)),
                ),
              ),
              if (_ctrl.sessionWrong > 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      _ctrl.startRetryMistakes(session.pageNumber);
                      _resultSlideCtrl.reset();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color: AppColors.error.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text("Retry ${_ctrl.sessionWrong} Mistakes",
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.error)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: AppTypography.headlineSmall
                .copyWith(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style:
                AppTypography.micro.copyWith(color: AppColors.slate400)),
      ],
    );
  }
}
