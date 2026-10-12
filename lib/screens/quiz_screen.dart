import 'dart:math';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../app/quiz_spec.dart';
import '../app/session_store.dart';
import '../content/models.dart';
import '../engine/quiz.dart';
import '../progress/insights.dart';
import '../progress/progress_store.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/key_handler.dart';
import '../widgets/question_view.dart';

/// S5 — 10-question quiz with instant feedback. Draws from one topic, or from
/// a cross-topic review pool (missed questions, a competency, a domain).
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.spec});

  final QuizSpec spec;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuizAttempt? _attempt;
  late QuizSpec _spec = widget.spec;
  String _title = 'Quiz';
  int _index = 0;
  Set<String> _selected = {};
  bool _revealed = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final content = context.read<ContentBundle>();
    final progress = context.read<ProgressStore>();
    final random = context.read<Random>();
    switch (_spec) {
      case TopicQuizSpec(:final topicId, :final retryMissed):
        final topic = content.topic(topicId);
        if (topic == null) return;
        progress.markTopicVisited(content.subject.id, topicId);
        // Only ids that still exist (content updates can remove questions).
        final missed = {
          for (final id
              in progress.quizStats(topicId)?.missed ?? const <String>[])
            if (topic.questions.any((q) => q.id == id)) id,
        };
        final retry = retryMissed && missed.isNotEmpty;
        _spec = TopicQuizSpec(topicId, retryMissed: retry);
        _title = retry ? 'Retry missed' : '${topic.title} · Quiz';
        _attempt = QuizAttempt(
          retry
              ? drawQuiz(
                  bank: topic.questions
                      .where((q) => missed.contains(q.id))
                      .toList(),
                  random: random,
                  count: missed.length,
                )
              : drawQuiz(
                  bank: topic.questions,
                  random: random,
                  priorityIds: missed,
                ),
        );
      case ReviewQuizSpec(:final kind, :final id):
        final pool = reviewPool(content, progress, kind: kind, id: id);
        _title = switch (kind) {
          'missed' => 'Review missed questions',
          'plan' => 'Re-test my gaps',
          'competency' => 'Review: ${content.competencyText(id ?? '') ?? id}',
          'domain' => 'Review: ${content.domain(id ?? '')?.title ?? id}',
          _ => 'Review',
        };
        // Prioritise questions answered wrong last time, then unseen ones.
        final weak = {
          for (final q in pool)
            if (progress.answerStats(q.id)?.lastCorrect != true) q.id,
        };
        _attempt = QuizAttempt(
          drawQuiz(bank: pool, random: random, priorityIds: weak),
        );
    }
  }

  PresentedQuestion get _current => _attempt!.questions[_index];

  /// Desktop shortcuts: 1–5 pick an option, Enter submits / continues.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _attempt == null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ];
    final i = digits.indexOf(key);
    if (i >= 0 && !_revealed && i < _current.options.length) {
      setState(
        () => _selected = QuestionView.toggle(
          _current,
          _selected,
          _current.options[i].id,
        ),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!_revealed && _selected.isNotEmpty) {
        _submit();
      } else if (_revealed) {
        _next();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit() {
    _attempt!.answer(_current.question.id, _selected);
    setState(() => _revealed = true);
  }

  Future<void> _next() async {
    if (_index + 1 < _attempt!.questions.length) {
      setState(() {
        _index++;
        _selected = {};
        _revealed = false;
      });
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final attempt = _attempt!;
    final progress = context.read<ProgressStore>();
    var xp = progress.recordAnswers(attempt);
    if (_spec case TopicQuizSpec(:final topicId, :final retryMissed)) {
      if (retryMissed) {
        progress.recordRetryMissed(topicId, attempt.missedIds);
      } else {
        xp += progress.recordQuiz(topicId, attempt.percent, attempt.missedIds);
      }
    }
    context.read<SessionStore>().lastQuiz = QuizResult(
      spec: _spec,
      attempt: attempt,
      xpEarned: xp,
    );
    // Interstitial (if any) shows before the results screen renders.
    await context.read<AdsService>().maybeShowInterstitial(
      context,
      AdPlacement.quizComplete,
    );
    if (mounted) context.go(_spec.resultPath);
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the quiz?'),
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
    if (leave == true && mounted) context.go(_spec.exitPath);
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    if (attempt == null || attempt.questions.isEmpty) {
      return _spec is ReviewQuizSpec
          ? const NotFoundView(
              title: 'Review',
              icon: Icons.task_alt,
              message:
                  'Nothing to review yet. Questions you get wrong in '
                  'quizzes and practice tests will show up here.',
              backTo: '/',
              actionLabel: 'Find a topic to study',
            )
          : NotFoundView(
              message: 'Quiz not available.',
              backTo: _spec.exitPath,
            );
    }
    final total = attempt.questions.length;
    final answered = attempt.answers.length;
    final score = attempt.questions
        .take(answered)
        .where(attempt.correct)
        .length;
    final topicTitle = _spec is ReviewQuizSpec
        ? context.read<ContentBundle>().topic(_current.question.topicId)?.title
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: KeyHandler(
        onKey: _onKey,
        child: Scaffold(
          appBar: AppBar(
            leading: CloseButton(onPressed: _confirmLeave),
            title: Text(_title, overflow: TextOverflow.ellipsis),
            bottom: PreferredSize(
              // Grows with the text size so large text isn't clipped.
              preferredSize: Size.fromHeight(
                14 + MediaQuery.textScalerOf(context).scale(20),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: (_index + (_revealed ? 1 : 0)) / total,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Q ${_index + 1}/$total',
                            key: const ValueKey('quiz-position'),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Score $score/$answered',
                            key: const ValueKey('quiz-running-score'),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: PageList(
            children: [
              if (topicTitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'From: $topicTitle',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              QuestionView(
                key: ValueKey(_current.question.id),
                presented: _current,
                selected: _selected,
                revealed: _revealed,
                onChanged: (s) => setState(() => _selected = s),
              ),
              const SizedBox(height: 16),
              if (!_revealed)
                FilledButton(
                  key: const ValueKey('submit'),
                  onPressed: _selected.isEmpty ? null : _submit,
                  child: const Text('Submit'),
                )
              else
                FilledButton(
                  key: const ValueKey('next'),
                  onPressed: _next,
                  child: Text(_index + 1 < total ? 'Next' : 'See results'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
