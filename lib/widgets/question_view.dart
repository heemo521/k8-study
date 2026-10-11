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
  });

  final PresentedQuestion presented;
  final Set<String> selected;
  final bool revealed;
  final ValueChanged<Set<String>>? onChanged;

  bool get _multi => presented.question.type == QuestionType.multi;

  void _tap(String id) {
    if (revealed || onChanged == null) return;
    if (_multi) {
      final next = {...selected};
      if (!next.remove(id)) next.add(id);
      onChanged!(next);
    } else {
      onChanged!({id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = presented.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineText(q.stem, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final o in presented.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionTile(
              option: o,
              multi: _multi,
              selected: selected.contains(o.id),
              revealed: revealed,
              onTap: () => _tap(o.id),
            ),
          ),
        if (revealed) SourceLink(url: q.sourceUrl),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.multi,
    required this.selected,
    required this.revealed,
    required this.onTap,
  });

  final AnswerOption option;
  final bool multi;
  final bool selected;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var border = selected ? scheme.primary : scheme.outlineVariant;
    Color? fill = selected ? scheme.primaryContainer.withValues(alpha: 0.4) : null;
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
        : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked);

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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InlineText(option.text,
                            style: Theme.of(context).textTheme.bodyLarge),
                        if (verdict != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(verdict,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: border)),
                          ),
                        if (revealed)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InlineText(option.explanation,
                                style: Theme.of(context).textTheme.bodyMedium),
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
          Builder(builder: (context) {
            final p = attempt.questions[i];
            final ok = attempt.correct(p);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                key: PageStorageKey('review-${p.question.id}'),
                leading: Icon(ok ? Icons.check_circle : Icons.cancel,
                    color: ok ? scheme.correct : scheme.wrong,
                    semanticLabel: ok ? 'Correct' : 'Incorrect'),
                title: InlineText('${i + 1}. ${p.question.stem}',
                    style: Theme.of(context).textTheme.bodyMedium),
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
          }),
      ],
    );
  }
}
