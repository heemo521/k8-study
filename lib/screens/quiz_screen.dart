import 'dart:math';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../app/session_store.dart';
import '../content/models.dart';
import '../engine/quiz.dart';
import '../progress/progress_store.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/question_view.dart';

/// S5 — 10-question topic quiz with instant feedback.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.topicId, this.retryMissed = false});

  final String topicId;

  /// Only the questions missed last time; doesn't count toward best score.
  final bool retryMissed;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuizAttempt? _attempt;
  late bool _retryMissed;
  int _index = 0;
  Set<String> _selected = {};
  bool _revealed = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final topic = context.read<ContentBundle>().topic(widget.topicId);
    if (topic == null) return;
    final random = context.read<Random>();
    final stats = context.read<ProgressStore>().quizStats(topic.id);
    final missed = {...?stats?.missed};
    _retryMissed = widget.retryMissed && missed.isNotEmpty;
    _attempt = QuizAttempt(
      _retryMissed
          ? drawQuiz(
              bank: topic.questions.where((q) => missed.contains(q.id)).toList(),
              random: random,
              count: missed.length,
            )
          : drawQuiz(bank: topic.questions, random: random, priorityIds: missed),
    );
  }

  PresentedQuestion get _current => _attempt!.questions[_index];

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
    if (_retryMissed) {
      progress.recordRetryMissed(widget.topicId, attempt.missedIds);
    } else {
      progress.recordQuiz(widget.topicId, attempt.percent, attempt.missedIds);
    }
    context.read<SessionStore>().lastQuiz = QuizResult(
      topicId: widget.topicId,
      attempt: attempt,
      retryMissed: _retryMissed,
    );
    // Interstitial (if any) shows before the results screen renders.
    await context
        .read<AdsService>()
        .maybeShowInterstitial(context, AdPlacement.quizComplete);
    if (mounted) context.go('/topic/${widget.topicId}/quiz/result');
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
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) context.go('/topic/${widget.topicId}');
  }

  @override
  Widget build(BuildContext context) {
    final topic = context.read<ContentBundle>().topic(widget.topicId);
    final attempt = _attempt;
    if (topic == null || attempt == null || attempt.questions.isEmpty) {
      return const NotFoundView(message: 'Quiz not available.');
    }
    final total = attempt.questions.length;
    final answered = attempt.answers.length;
    final score = attempt.questions
        .take(answered)
        .where(attempt.correct)
        .length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: CloseButton(onPressed: _confirmLeave),
          title: Text(_retryMissed ? 'Retry missed' : '${topic.title} · Quiz'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Text('Q ${_index + 1}/$total',
                    key: const ValueKey('quiz-position'),
                    style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                Text('Score $score/$answered',
                    style: Theme.of(context).textTheme.labelLarge),
              ]),
            ),
          ),
        ),
        body: PageList(children: [
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
        ]),
      ),
    );
  }
}
