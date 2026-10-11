import 'dart:async';
import 'dart:math';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../app/session_store.dart';
import '../content/models.dart';
import '../engine/clock.dart';
import '../engine/practice.dart';
import '../engine/quiz.dart';
import '../progress/progress_store.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/question_view.dart';

/// S8 — timed test with deferred feedback, flags and a question grid.
class PracticeRunScreen extends StatefulWidget {
  const PracticeRunScreen({super.key, required this.testId});

  final String testId;

  @override
  State<PracticeRunScreen> createState() => _PracticeRunScreenState();
}

class _PracticeRunScreenState extends State<PracticeRunScreen> {
  PracticeTestDef? _test;
  QuizAttempt? _attempt;
  late TestTimer _timer;
  Timer? _ticker;
  final Set<String> _flagged = {};
  int _index = 0;
  bool _finishing = false;

  Clock get _clock => context.read<Clock>();

  @override
  void initState() {
    super.initState();
    final content = context.read<ContentBundle>();
    final test = content.practiceTest(widget.testId);
    if (test == null) return;
    _test = test;
    _attempt = QuizAttempt(
      drawPractice(
        test: test,
        content: content,
        random: context.read<Random>(),
      ),
    );
    _timer = TestTimer(
      startedAt: _clock.now(),
      limit: context.read<ProgressStore>().practiceTimerOn
          ? Duration(minutes: test.timeLimitMinutes)
          : null,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    if (_timer.expired(_clock.now())) {
      _finish();
    } else {
      setState(() {});
    }
  }

  PresentedQuestion get _current => _attempt!.questions[_index];

  void _goTo(int i) => setState(() => _index = i);

  Future<void> _confirmFinish() async {
    final unanswered = _attempt!.questions
        .where((p) => !_attempt!.isAnswered(p.question.id))
        .length;
    if (unanswered > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finish the test?'),
          content: Text(
            '$unanswered unanswered '
            '${unanswered == 1 ? 'question' : 'questions'} will be marked wrong.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going'),
            ),
            TextButton(
              key: const ValueKey('confirm-finish'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finish'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_finishing || !mounted) return;
    _finishing = true;
    _ticker?.cancel();
    final attempt = _attempt!;
    final content = context.read<ContentBundle>();
    final duration = _timer.elapsed(_clock.now());
    final breakdown = domainBreakdown(attempt, content);
    final progress = context.read<ProgressStore>()..recordAnswers(attempt);
    progress.recordPractice(
      PracticeRecord(
        testId: widget.testId,
        pct: attempt.percent,
        perDomain: breakdown,
        durationSec: duration.inSeconds,
        at: _clock.now(),
      ),
    );
    context.read<SessionStore>().lastPractice = PracticeResult(
      testId: widget.testId,
      attempt: attempt,
      duration: duration,
      breakdown: breakdown,
    );
    await context.read<AdsService>().maybeShowInterstitial(
      context,
      AdPlacement.practiceComplete,
    );
    if (mounted) context.go('/practice/${widget.testId}/result');
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the test?'),
        content: const Text('This attempt will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.go('/practice');
  }

  void _showGrid() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: PageWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _attempt!.questions.length; i++)
                    Builder(
                      builder: (_) {
                        final id = _attempt!.questions[i].question.id;
                        final answered = _attempt!.isAnswered(id);
                        final flagged = _flagged.contains(id);
                        return SizedBox.square(
                          dimension: 48,
                          child: Semantics(
                            label:
                                'Question ${i + 1}'
                                '${answered ? ', answered' : ', blank'}'
                                '${flagged ? ', flagged' : ''}',
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: answered
                                    ? scheme.primaryContainer
                                    : null,
                                side: BorderSide(
                                  color: flagged
                                      ? scheme.tertiary
                                      : (i == _index
                                            ? scheme.primary
                                            : scheme.outlineVariant),
                                  width: flagged || i == _index ? 2 : 1,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _goTo(i);
                              },
                              child: Text(flagged ? '${i + 1}⚑' : '${i + 1}'),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final test = _test;
    final attempt = _attempt;
    if (test == null || attempt == null || attempt.questions.isEmpty) {
      return const NotFoundView(
        message: 'Practice test not found.',
        backTo: '/practice',
      );
    }
    final total = attempt.questions.length;
    final id = _current.question.id;
    final remaining = _timer.remaining(_clock.now());
    final flagged = _flagged.contains(id);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: CloseButton(onPressed: _confirmLeave),
          title: Text(
            'Q ${_index + 1}/$total',
            key: const ValueKey('practice-position'),
          ),
          actions: [
            if (remaining != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _fmt(remaining),
                    key: const ValueKey('practice-timer'),
                    semanticsLabel: 'Time left ${_fmt(remaining)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            IconButton(
              tooltip: 'All questions',
              icon: const Icon(Icons.grid_view),
              onPressed: _showGrid,
            ),
          ],
        ),
        body: PageList(
          children: [
            QuestionView(
              key: ValueKey(id),
              presented: _current,
              selected: attempt.answers[id] ?? const {},
              revealed: false,
              onChanged: (s) => setState(() => attempt.answer(id, s)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('flag'),
                onPressed: () => setState(
                  () => flagged ? _flagged.remove(id) : _flagged.add(id),
                ),
                icon: Icon(flagged ? Icons.flag : Icons.outlined_flag),
                label: Text(flagged ? 'Flagged for review' : 'Flag for review'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _index + 1 < total
                      ? FilledButton(
                          key: const ValueKey('practice-next'),
                          onPressed: () => _goTo(_index + 1),
                          child: const Text('Next'),
                        )
                      : FilledButton(
                          key: const ValueKey('practice-finish'),
                          onPressed: _confirmFinish,
                          child: const Text('Finish'),
                        ),
                ),
              ],
            ),
            if (_index + 1 < total) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _confirmFinish,
                child: const Text('Finish test'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
