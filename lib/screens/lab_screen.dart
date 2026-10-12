import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../content/models.dart';
import '../engine/command_grading.dart';
import '../engine/labs.dart';
import '../progress/progress_store.dart';
import '../widgets/inline_text.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/source_link.dart';

const _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Courier New', 'Courier'],
);

/// Guided lab (spec §14.8): type each step's command. The first run shows
/// every command, the second only how each starts, later runs nothing.
class LabScreen extends StatefulWidget {
  const LabScreen({super.key, required this.topicId, required this.labId});

  final String topicId;
  final String labId;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  final _controller = TextEditingController();
  late final LabGuidance _guidance = guidanceFor(
    context.read<ProgressStore>().labRuns(widget.labId),
  );
  int _step = 0;

  /// null = not checked yet; true = right; false = wrong (may retry).
  bool? _ok;
  bool _shown = false;
  bool _done = false;

  Lab? get _lab {
    final topic = context.read<ContentBundle>().topic(widget.topicId);
    for (final l in topic?.labs ?? const <Lab>[]) {
      if (l.id == widget.labId) return l;
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check(LabStep step) =>
      setState(() => _ok = commandMatches(_controller.text, step.answers));

  void _next(Lab lab) {
    if (_step + 1 < lab.steps.length) {
      setState(() {
        _step++;
        _ok = null;
        _shown = false;
        _controller.clear();
      });
      return;
    }
    context.read<ProgressStore>().recordLabRun(lab.id);
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final lab = _lab;
    if (lab == null) {
      return NotFoundView(
        message: 'Lab not found.',
        backTo: '/topic/${widget.topicId}',
      );
    }
    final exit = '/topic/${widget.topicId}';
    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(onPressed: () => context.go(exit)),
        title: Text(lab.title, overflow: TextOverflow.ellipsis),
      ),
      body: PageList(children: _done ? _doneView(lab, exit) : _stepView(lab)),
    );
  }

  List<Widget> _stepView(Lab lab) {
    final step = lab.steps[_step];
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final answered = _ok == true || _shown;
    final guide = switch (_guidance) {
      _ when _shown => step.answers.first,
      LabGuidance.worked => step.answers.first,
      LabGuidance.partial => partialHint(step.answers.first),
      LabGuidance.solo => null,
    };
    return [
      Wrap(
        spacing: 8,
        children: [
          Chip(
            key: const ValueKey('lab-guidance'),
            label: Text(guidanceLabel(_guidance)),
          ),
          Chip(label: Text('Step ${_step + 1} of ${lab.steps.length}')),
        ],
      ),
      const SizedBox(height: 8),
      if (_step == 0) ...[
        InlineText(lab.scenario, style: textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          'Run each command in your own practice cluster as you go.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
      ],
      Semantics(
        container: true,
        child: InlineText(step.prompt, style: textTheme.titleMedium),
      ),
      const SizedBox(height: 12),
      if (guide != null) ...[
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              guide,
              key: const ValueKey('lab-guide'),
              style: textTheme.bodyLarge?.merge(_mono),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Semantics(
        container: true,
        child: TextField(
          key: ValueKey('lab-input-$_step'),
          controller: _controller,
          enabled: !answered,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          style: textTheme.bodyLarge?.merge(_mono),
          decoration: const InputDecoration(
            labelText: 'Type the command',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (_ok == false) setState(() => _ok = null);
          },
          onSubmitted: (_) => answered ? null : _check(step),
        ),
      ),
      const SizedBox(height: 12),
      if (_ok == false && !_shown) ...[
        Text(
          'Not quite. Try again, or show the answer.',
          key: const ValueKey('lab-wrong'),
          style: textTheme.bodyMedium?.copyWith(color: scheme.wrong),
        ),
        const SizedBox(height: 8),
      ],
      if (answered) ...[
        if (_ok == true)
          Text(
            'Correct',
            key: const ValueKey('lab-right'),
            style: textTheme.labelLarge?.copyWith(color: scheme.correct),
          ),
        const SizedBox(height: 4),
        InlineText(step.explanation, style: textTheme.bodyMedium),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('lab-next'),
          onPressed: () => _next(lab),
          child: Text(
            _step + 1 < lab.steps.length ? 'Next step' : 'Finish lab',
          ),
        ),
      ] else
        Row(
          children: [
            if (_ok == false || _guidance != LabGuidance.worked)
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('lab-show'),
                  onPressed: () => setState(() => _shown = true),
                  child: const Text('Show answer'),
                ),
              ),
            if (_ok == false || _guidance != LabGuidance.worked)
              const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const ValueKey('lab-check'),
                onPressed: () => _check(step),
                child: const Text('Check'),
              ),
            ),
          ],
        ),
      const SizedBox(height: 16),
      SourceLink(url: lab.sourceUrl),
    ];
  }

  List<Widget> _doneView(Lab lab, String exit) {
    final textTheme = Theme.of(context).textTheme;
    final next = guidanceFor(context.read<ProgressStore>().labRuns(lab.id));
    return [
      Text(
        'Lab complete',
        key: const ValueKey('lab-done'),
        style: textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        next == _guidance
            ? 'Run it again on another day to keep it fresh.'
            : 'Next time: ${guidanceLabel(next).toLowerCase()}, with less help.',
        style: textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => context.go(exit),
        child: const Text('Back to topic'),
      ),
    ];
  }
}
