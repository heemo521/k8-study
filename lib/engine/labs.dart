/// Guided labs with fading guidance (spec §15.8). Pure Dart.
library;

/// How much help a lab run gives: the full command, its start, or none.
enum LabGuidance { worked, partial, solo }

/// First run: worked example. Second: partly guided. Then on your own.
LabGuidance guidanceFor(int completedRuns) => switch (completedRuns) {
  0 => LabGuidance.worked,
  1 => LabGuidance.partial,
  _ => LabGuidance.solo,
};

String guidanceLabel(LabGuidance g) => switch (g) {
  LabGuidance.worked => 'Worked example',
  LabGuidance.partial => 'Partly guided',
  LabGuidance.solo => 'On your own',
};

/// Verbs whose sub-command is part of what to remember (`rollout undo`).
const _twoWordVerbs = {'rollout', 'config', 'set', 'create', 'top'};

/// The start of [command] for a partly guided step: the tool and its verb
/// (plus a sub-command such as `rollout undo`), then an ellipsis.
String partialHint(String command) {
  final words = command.trim().split(RegExp(r'\s+'));
  final keep = words.length > 1 && _twoWordVerbs.contains(words[1]) ? 3 : 2;
  if (words.length <= keep) return '${words.take(keep - 1).join(' ')} …';
  return '${words.take(keep).join(' ')} …';
}
