import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../content/models.dart';
import '../engine/quiz.dart';
import 'inline_text.dart';
import 'source_link.dart';

/// Question stem + options. Before reveal the user selects; after reveal the
/// options lock, correct options go green, wrong picks red, and every option
/// shows its explanation.
class QuestionView extends StatelessWidget {
  const QuestionView({
    super.key,
    required this.presented,
    required this.selected,
    required this.revealed,
    this.onChanged,
    this.hideExplanations = false,
  });

  final PresentedQuestion presented;
  final Set<String> selected;
  final bool revealed;

  /// After the reveal, hold back the explanations so the learner first
  /// explains the answer to themselves (spec §15.7).
  final bool hideExplanations;
  final ValueChanged<Set<String>>? onChanged;

  bool get _multi => presented.question.type == QuestionType.multi;

  /// Selection after choosing option [id]: toggles for multi-select,
  /// replaces for single choice. Shared with keyboard shortcuts.
  static Set<String> toggle(
    PresentedQuestion presented,
    Set<String> selected,
    String id,
  ) {
    if (presented.question.type != QuestionType.multi) return {id};
    final next = {...selected};
    if (!next.remove(id)) next.add(id);
    return next;
  }

  void _tap(String id) {
    if (revealed || onChanged == null) return;
    onChanged!(toggle(presented, selected, id));
  }

  @override
  Widget build(BuildContext context) {
    final q = presented.question;
    if (q.type == QuestionType.command) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Own node, so it isn't merged into the text field's label.
          Semantics(
            container: true,
            child: InlineText(
              q.stem,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 12),
          _CommandAnswer(
            key: ValueKey('command-${q.id}'),
            question: q,
            typed: selected.isEmpty ? '' : selected.first,
            revealed: revealed,
            onChanged: onChanged,
          ),
          if (revealed) SourceLink(url: q.sourceUrl),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineText(q.stem, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final (i, o) in presented.options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionTile(
              // Keyboard hint on wide (desktop) layouts only.
              shortcut: MediaQuery.sizeOf(context).width >= 600 && !revealed
                  ? '${i + 1}'
                  : null,
              option: o,
              multi: _multi,
              selected: selected.contains(o.id),
              revealed: revealed,
              showExplanation: revealed && !hideExplanations,
              onTap: () => _tap(o.id),
            ),
          ),
        if (_multi && !revealed && onChanged != null)
          Text(
            'Selected ${selected.length} of '
            '${q.options.where((o) => o.correct).length}',
            key: const ValueKey('multi-count'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        if (revealed) SourceLink(url: q.sourceUrl),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.shortcut,
    required this.option,
    required this.multi,
    required this.selected,
    required this.revealed,
    required this.showExplanation,
    required this.onTap,
  });

  final String? shortcut;
  final AnswerOption option;
  final bool multi;
  final bool selected;
  final bool revealed;
  final bool showExplanation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var border = selected ? scheme.primary : scheme.outlineVariant;
    Color? fill = selected
        ? scheme.primaryContainer.withValues(alpha: 0.4)
        : null;
    String? verdict;
    if (revealed) {
      if (option.correct) {
        border = scheme.correct;
        fill = scheme.correctContainer;
        verdict = selected ? 'Correct — your answer' : 'Correct answer';
      } else if (selected) {
        border = scheme.wrong;
        fill = scheme.wrongContainer;
        verdict = 'Your answer — incorrect';
      } else {
        border = scheme.outlineVariant;
        fill = null;
      }
    }
    final icon = multi
        ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
        : (selected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked);

    return Semantics(
      button: !revealed,
      selected: selected,
      inMutuallyExclusiveGroup: !multi,
      child: Material(
        color: fill ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border, width: selected || revealed ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: revealed ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 22, color: border),
                  if (shortcut != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, top: 2),
                      child: Text(
                        shortcut!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InlineText(
                          option.text,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (verdict != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              verdict,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: border),
                            ),
                          ),
                        if (showExplanation)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InlineText(
                              option.explanation,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Courier New', 'Courier'],
);

/// Typed answer for a `command` question (spec §15.5). Before reveal: a
/// text field. After: the typed command marked right or wrong, the model
/// answer and the explanation.
class _CommandAnswer extends StatefulWidget {
  const _CommandAnswer({
    super.key,
    required this.question,
    required this.typed,
    required this.revealed,
    required this.onChanged,
  });

  final Question question;
  final String typed;
  final bool revealed;
  final ValueChanged<Set<String>>? onChanged;

  @override
  State<_CommandAnswer> createState() => _CommandAnswerState();
}

class _CommandAnswerState extends State<_CommandAnswer> {
  late final _controller = TextEditingController(text: widget.typed);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _field(TextTheme textTheme) => TextField(
    key: const ValueKey('command-input'),
    controller: _controller,
    enabled: widget.onChanged != null,
    autocorrect: false,
    enableSuggestions: false,
    textCapitalization: TextCapitalization.none,
    keyboardType: TextInputType.visiblePassword,
    style: textTheme.bodyLarge?.merge(_mono),
    decoration: const InputDecoration(
      labelText: 'Type the command',
      hintText: 'kubectl …',
      border: OutlineInputBorder(),
    ),
    onChanged: (text) =>
        widget.onChanged?.call(text.trim().isEmpty ? {} : {text}),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final q = widget.question;
    if (!widget.revealed) {
      // Own semantics node: otherwise the field's role and size merge into
      // the surrounding column's node.
      return Semantics(container: true, child: _field(textTheme));
    }
    final ok = isCorrect(q, {widget.typed});
    final color = ok ? scheme.correct : scheme.wrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: ok ? scheme.correctContainer : scheme.wrongContainer,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.typed.trim().isEmpty ? '(no answer)' : widget.typed,
                  key: const ValueKey('command-typed'),
                  style: textTheme.bodyLarge?.merge(_mono),
                ),
                const SizedBox(height: 4),
                Text(
                  ok ? 'Correct — your answer' : 'Your answer — incorrect',
                  style: textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          q.answers.length > 1 ? 'Model answer (others accepted)' : 'Answer',
          style: textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        SelectableText(
          q.answers.first,
          key: const ValueKey('command-model'),
          style: textTheme.bodyLarge?.merge(_mono),
        ),
        const SizedBox(height: 8),
        InlineText(q.explanation ?? '', style: textTheme.bodyMedium),
      ],
    );
  }
}

/// Collapsible review of a finished attempt (used by S6 and S9).
class AttemptReview extends StatelessWidget {
  const AttemptReview({super.key, required this.attempt});

  final QuizAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < attempt.questions.length; i++)
          Builder(
            builder: (context) {
              final p = attempt.questions[i];
              final ok = attempt.correct(p);
              final skipped = !attempt.isAnswered(p.question.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  key: PageStorageKey('review-${p.question.id}'),
                  leading: Icon(
                    skipped
                        ? Icons.remove_circle_outline
                        : ok
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: skipped
                        ? scheme.outline
                        : ok
                        ? scheme.correct
                        : scheme.wrong,
                    semanticLabel: skipped
                        ? 'Not answered'
                        : ok
                        ? 'Correct'
                        : 'Incorrect',
                  ),
                  title: InlineText(
                    '${i + 1}. ${p.question.stem}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    QuestionView(
                      presented: p,
                      selected: attempt.answers[p.question.id] ?? const {},
                      revealed: true,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
