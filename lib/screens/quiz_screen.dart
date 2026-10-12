import 'dart:math';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../app/quiz_spec.dart';
import '../app/session_store.dart';
import '../content/models.dart';
import '../engine/clock.dart';
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
  bool _whyShown = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final content = context.read<ContentBundle>();
    final progress = context.read<ProgressStore>();
    final random = context.read<Random>();
    switch (_spec) {
      case TopicQuizSpec(:final topicId, warmup: true):
        final topic = content.topic(topicId);
        if (topic == null) return;
        progress.markTopicVisited(content.subject.id, topicId);
        _title = '${topic.title} · Warm-up';
        _attempt = QuizAttempt(
          drawWarmup(bank: topic.questions, random: random),
        );
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
        final pool = reviewPool(
          content,
          progress,
          kind: kind,
          id: id,
          now: context.read<Clock>().now(),
        );
        _title = switch (kind) {
          'missed' => 'Questions to review',
          'plan' => 'Re-test my gaps',
          'competency' => 'Review: ${content.competencyText(id ?? '') ?? id}',
          'domain' => 'Review: ${content.domain(id ?? '')?.title ?? id}',
          _ => 'Review',
        };
        // Due reviews: confident mistakes first. Other reviews: anything
        // not answered right-and-sure last time, then unseen ones.
        final weak = {
          for (final q in pool)
            if (progress.answerStats(q.id) case final s?
                when kind == 'missed' ? !s.lastCorrect && s.lastSure : !s.solid)
              q.id
            else if (kind != 'missed' && progress.answerStats(q.id) == null)
              q.id,
        };
        _attempt = QuizAttempt(
          drawQuiz(bank: pool, random: random, priorityIds: weak),
        );
    }
  }

  PresentedQuestion get _current => _attempt!.questions[_index];

  /// Self-explanation prompt (spec §14.7): after a right answer to a harder
  /// multiple-choice question, ask "why?" before showing the explanations.
  bool get _askWhy =>
      _revealed &&
      !_isWarmup &&
      _current.question.difficulty >= 2 &&
      _current.question.type != QuestionType.command &&
      _attempt!.correct(_current);

  bool get _isWarmup {
    final spec = _spec;
    return spec is TopicQuizSpec && spec.warmup;
  }

  /// Desktop shortcuts: 1–5 pick an option, Enter submits as sure (U as not
  /// sure) / continues.
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
    if (key == LogicalKeyboardKey.keyU && !_revealed && _selected.isNotEmpty) {
      _submit(sure: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!_revealed && _selected.isNotEmpty) {
        _submit(sure: true);
      } else if (_revealed) {
        _next();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit({required bool sure}) {
    _attempt!.answer(_current.question.id, _selected, sure: sure);
    setState(() => _revealed = true);
  }

  Future<void> _next() async {
    if (_index + 1 < _attempt!.questions.length) {
      setState(() {
        _index++;
        _selected = {};
        _revealed = false;
        _whyShown = false;
      });
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final attempt = _attempt!;
    // A warm-up is a guess before studying: no evidence, no score, no ad.
    if (_isWarmup) {
      context.go(_spec.resultPath);
      return;
    }
    final progress = context.read<ProgressStore>();
    progress.recordAnswers(attempt);
    if (_spec case TopicQuizSpec(:final topicId, :final retryMissed)) {
      if (retryMissed) {
        progress.recordRetryMissed(topicId, attempt.missedIds);
      } else {
        progress.recordQuiz(topicId, attempt.percent, attempt.missedIds);
      }
    }
    context.read<SessionStore>().lastQuiz = QuizResult(
      spec: _spec,
      attempt: attempt,
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
                hideExplanations: _askWhy && !_whyShown,
                onChanged: (s) => setState(() => _selected = s),
              ),
              if (_askWhy && !_whyShown)
                _WhyPrompt(onShow: () => setState(() => _whyShown = true)),
              const SizedBox(height: 16),
              if (!_revealed)
                _ConfidenceButtons(
                  enabled: _selected.isNotEmpty,
                  onSubmit: (sure) => _submit(sure: sure),
                )
              else ...[
                _ConfidenceFeedback(
                  correct: attempt.correct(_current),
                  sure: attempt.isSure(_current.question.id),
                ),
                FilledButton(
                  key: const ValueKey('next'),
                  onPressed: _next,
                  child: Text(
                    _index + 1 < total
                        ? 'Next'
                        : _isWarmup
                        ? 'Start the notes'
                        : 'See results',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Submit with a confidence rating (spec §14.1): "Sure" or "Not sure".
class _ConfidenceButtons extends StatelessWidget {
  const _ConfidenceButtons({required this.enabled, required this.onSubmit});

  final bool enabled;
  final ValueChanged<bool> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          child: Text(
            'How sure are you?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('submit-unsure'),
                onPressed: enabled ? () => onSubmit(false) : null,
                child: const Text('Not sure'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const ValueKey('submit'),
                onPressed: enabled ? () => onSubmit(true) : null,
                child: const Text('Sure'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One line on what the answer's confidence means for review.
class _ConfidenceFeedback extends StatelessWidget {
  const _ConfidenceFeedback({required this.correct, required this.sure});

  final bool correct;
  final bool sure;

  @override
  Widget build(BuildContext context) {
    final text = switch ((correct, sure)) {
      (false, true) =>
        'Confident mistake: read the explanation closely. '
            'Corrected surprises tend to stick.',
      (true, false) =>
        'Right, but unsure: it will come back for review tomorrow.',
      (false, false) => 'It will come back for review.',
      (true, true) => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('confidence-feedback'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// Asks the learner to explain a right answer before reading why.
class _WhyPrompt extends StatelessWidget {
  const _WhyPrompt({required this.onShow});

  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('why-prompt'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Why is it right?', style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Explain it to yourself in one sentence, then check.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('show-why'),
                onPressed: onShow,
                child: const Text('Show the explanation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
