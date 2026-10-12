import 'dart:math';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../content/models.dart';
import '../engine/clock.dart';
import '../engine/flashcards.dart';
import '../progress/insights.dart';
import '../progress/progress_store.dart';
import '../widgets/inline_text.dart';
import '../widgets/key_handler.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/source_link.dart';

/// S4 — spaced-repetition review. Space flips; 1 = Again, 2 = Got it.
/// With no [topicId] it reviews every due card in the subject.
class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, this.topicId});

  final String? topicId;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  FlashcardSession? _session;
  bool _flipped = false;

  Topic? get _topic => widget.topicId == null
      ? null
      : context.read<ContentBundle>().topic(widget.topicId!);

  bool get _allDue => widget.topicId == null;

  String get _exitPath => _allDue ? '/progress' : '/topic/${widget.topicId}';

  int get _dueQuestions => dueQuestions(
    context.read<ContentBundle>(),
    context.read<ProgressStore>(),
    context.read<Clock>().now(),
  ).length;

  /// After a topic's cards: its quiz. After the due-card review: the due
  /// questions, if any (spec §15.3).
  String get _nextPath => !_allDue
      ? '/topic/${widget.topicId}/quiz'
      : _dueQuestions > 0
      ? '/progress/review?kind=missed'
      : '/progress';

  String get _nextLabel {
    if (!_allDue) return 'Next: Quiz';
    final n = _dueQuestions;
    return n > 0
        ? 'Next: $n ${n == 1 ? 'question' : 'questions'} to review'
        : 'Back to Progress';
  }

  @override
  void initState() {
    super.initState();
    final topic = _topic;
    if (topic != null) {
      context.read<ProgressStore>().markTopicVisited(
        context.read<ContentBundle>().subject.id,
        topic.id,
      );
    }
    _startSession(practice: false);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _startSession({required bool practice}) {
    final topic = _topic;
    final content = context.read<ContentBundle>();
    if (topic == null && !_allDue) return;
    final pool =
        topic?.flashcards ??
        dueCards(
          content,
          context.read<ProgressStore>(),
          context.read<Clock>().now(),
        );
    final cards = practice
        ? ([...pool]..shuffle(context.read<Random>()))
        : buildSession(
            cards: pool,
            states: context.read<ProgressStore>().cardStates,
            now: context.read<Clock>().now(),
            random: context.read<Random>(),
          );
    setState(() {
      _session = FlashcardSession(cards: cards, practiceMode: practice);
      _flipped = false;
    });
  }

  void _flip() {
    if (_session == null || _session!.isDone) return;
    setState(() => _flipped = !_flipped);
  }

  void _answer(bool knewIt) {
    final session = _session;
    if (session == null || session.isDone || !_flipped) return;
    final progress = context.read<ProgressStore>();
    final card = session.current;
    final next = session.answer(
      knewIt: knewIt,
      previous: progress.cardState(card.id),
      now: context.read<Clock>().now(),
    );
    if (next != null) progress.setCardState(card.id, next);
    setState(() => _flipped = false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      _flip();
    } else if (key == LogicalKeyboardKey.digit1) {
      _answer(false);
    } else if (key == LogicalKeyboardKey.digit2) {
      _answer(true);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topic;
    if (topic == null && !_allDue) {
      return const NotFoundView(message: 'Topic not found.');
    }
    final session = _session!;
    final content = context.read<ContentBundle>();

    return KeyHandler(
      onKey: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            topic == null ? 'Due flashcards' : '${topic.title} · Cards',
          ),
          leading: BackButton(onPressed: () => context.go(_exitPath)),
        ),
        body: PageWidth(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: session.length == 0
                ? _CaughtUp(
                    topic: topic,
                    nextLabel: _nextLabel,
                    nextPath: _nextPath,
                    onPracticeAnyway: topic == null
                        ? null
                        : () => _startSession(practice: true),
                  )
                : session.isDone
                ? _Summary(
                    session: session,
                    onAgain: () =>
                        _startSession(practice: session.practiceMode),
                    nextLabel: _nextLabel,
                    onNext: () => context.go(_nextPath),
                  )
                : _CardView(
                    session: session,
                    topicTitle: topic == null
                        ? content.topic(session.current.topicId)?.title
                        : null,
                    flipped: _flipped,
                    onFlip: _flip,
                    onAnswer: _answer,
                  ),
          ),
        ),
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({
    required this.session,
    required this.topicTitle,
    required this.flipped,
    required this.onFlip,
    required this.onAnswer,
  });

  final FlashcardSession session;

  /// Shown in cross-topic sessions.
  final String? topicTitle;
  final bool flipped;
  final VoidCallback onFlip;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final card = session.current;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final keys = MediaQuery.sizeOf(context).width >= 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: session.position / session.length,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        Text(
          '${session.remaining} left'
          '${session.practiceMode ? ' · practice (schedule unchanged)' : ''}'
          '${topicTitle == null ? '' : ' · $topicTitle'}',
          style: textTheme.labelMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Semantics(
            button: true,
            label: flipped
                ? 'Card answer. Tap to flip back'
                : 'Card prompt. Tap to flip',
            child: GestureDetector(
              key: const ValueKey('flashcard'),
              onTap: onFlip,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Card(
                  key: ValueKey('${card.id}-$flipped'),
                  color: flipped ? scheme.secondaryContainer : null,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flipped ? 'ANSWER' : 'PROMPT',
                          style: textTheme.labelSmall,
                        ),
                        const SizedBox(height: 12),
                        InlineText(
                          flipped ? card.back : card.front,
                          style: textTheme.headlineSmall,
                        ),
                        if (flipped) ...[
                          const SizedBox(height: 16),
                          SourceLink(url: card.sourceUrl),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Keyboard hints only where a keyboard is likely (as in quizzes).
        if (!flipped)
          FilledButton(
            key: const ValueKey('flip'),
            onPressed: onFlip,
            child: Text(keys ? 'Show answer (Space)' : 'Show answer'),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('again'),
                  onPressed: () => onAnswer(false),
                  child: Text(keys ? 'Again (1)' : 'Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('got-it'),
                  onPressed: () => onAnswer(true),
                  child: Text(keys ? 'Got it (2)' : 'Got it'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.session,
    required this.onAgain,
    required this.nextLabel,
    required this.onNext,
  });

  final FlashcardSession session;
  final VoidCallback onAgain;
  final String nextLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('cards-summary'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Session done',
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${session.reviewed} reviewed · ${session.gotItCount} got it',
          style: textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        if (comeBackText(
              context.read<ContentBundle>(),
              context.read<ProgressStore>(),
              context.read<Clock>().now(),
            )
            case final nudge?) ...[
          const SizedBox(height: 4),
          Text(
            nudge,
            key: const ValueKey('come-back'),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(onPressed: onAgain, child: const Text('Review again')),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('next-quiz'),
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward),
          label: Text(nextLabel),
        ),
      ],
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp({
    required this.topic,
    required this.nextLabel,
    required this.nextPath,
    required this.onPracticeAnyway,
  });

  final Topic? topic;
  final String nextLabel;
  final String nextPath;
  final VoidCallback? onPracticeAnyway;

  @override
  Widget build(BuildContext context) {
    final progress = context.read<ProgressStore>();
    final now = context.read<Clock>().now();
    final cards =
        topic?.flashcards ??
        context.read<ContentBundle>().allFlashcards.toList();
    final next = nextDueDate(cards, progress.cardStates, now);
    final days = next?.difference(dateOnly(now)).inDays;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'All caught up',
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          days == null
              ? 'No cards are due.'
              : 'Next review in $days ${days == 1 ? 'day' : 'days'}.',
          style: textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (onPracticeAnyway != null) ...[
          OutlinedButton(
            onPressed: onPracticeAnyway,
            child: const Text('Practice anyway'),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: () => context.go(nextPath),
          child: Text(nextLabel),
        ),
      ],
    );
  }
}
