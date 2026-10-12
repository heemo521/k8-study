/// Grading for typed `command` questions (spec §15.5). Pure Dart.
///
/// A typed command matches an accepted answer when both normalise to the
/// same shape: the same positional words in order, and the same set of
/// flags with the same values, in any order. Normalising covers the
/// equivalent spellings `kubectl` accepts:
///
/// - `k` for `kubectl`; a leading `$ ` prompt is ignored;
/// - short and long flags (`-n` = `--namespace`), `--flag=value` =
///   `--flag value`, and combined boolean shorts (`-it` = `-i -t`);
/// - resource short names and plurals (`deploy`, `deployments` =
///   `deployment`), and `type/name` = `type name`;
/// - quotes around a single word.
///
/// Everything after `--` (the command run in a container) is compared
/// word for word.
library;

/// Short flag → long flag.
const _flagAliases = {
  '-n': '--namespace',
  '-o': '--output',
  '-l': '--selector',
  '-f': '--filename',
  '-A': '--all-namespaces',
  '-i': '--stdin',
  '-t': '--tty',
  '-c': '--container',
  '-w': '--watch',
  '-R': '--recursive',
  '-k': '--kustomize',
};

/// Flags that never take a value, so the next word stays positional.
const _booleanFlags = {
  '--all-namespaces',
  '--stdin',
  '--tty',
  '--watch',
  '--recursive',
  '--rm',
  '--force',
  '--ignore-daemonsets',
  '--delete-emptydir-data',
  '--show-labels',
  '--overwrite',
  '--all',
  '--previous',
  '--follow',
  '--wait',
};

/// Short boolean flags that may be combined, as in `-it`.
const _booleanShorts = {'i', 't', 'A', 'w', 'R'};

/// Resource short names and plurals → canonical singular.
const _resourceAliases = {
  'po': 'pod',
  'pods': 'pod',
  'deploy': 'deployment',
  'deployments': 'deployment',
  'svc': 'service',
  'services': 'service',
  'ns': 'namespace',
  'namespaces': 'namespace',
  'no': 'node',
  'nodes': 'node',
  'cm': 'configmap',
  'configmaps': 'configmap',
  'secrets': 'secret',
  'rs': 'replicaset',
  'replicasets': 'replicaset',
  'ds': 'daemonset',
  'daemonsets': 'daemonset',
  'sts': 'statefulset',
  'statefulsets': 'statefulset',
  'pv': 'persistentvolume',
  'persistentvolumes': 'persistentvolume',
  'pvc': 'persistentvolumeclaim',
  'persistentvolumeclaims': 'persistentvolumeclaim',
  'sa': 'serviceaccount',
  'serviceaccounts': 'serviceaccount',
  'ing': 'ingress',
  'ingresses': 'ingress',
  'jobs': 'job',
  'cj': 'cronjob',
  'cronjobs': 'cronjob',
  'netpol': 'networkpolicy',
  'networkpolicies': 'networkpolicy',
  'hpa': 'horizontalpodautoscaler',
  'horizontalpodautoscalers': 'horizontalpodautoscaler',
  'sc': 'storageclass',
  'storageclasses': 'storageclass',
  'roles': 'role',
  'rolebindings': 'rolebinding',
  'clusterroles': 'clusterrole',
  'clusterrolebindings': 'clusterrolebinding',
  'ep': 'endpoints',
  'ev': 'event',
  'events': 'event',
};

final _resourceNames = {..._resourceAliases.values};

String _resource(String word) => _resourceAliases[word] ?? word;

/// Splits on whitespace, keeping quoted text as one word without quotes.
List<String> _words(String text) {
  final words = <String>[];
  final buf = StringBuffer();
  String? quote;
  var inWord = false;
  for (final ch in text.split('')) {
    if (quote != null) {
      if (ch == quote) {
        quote = null;
      } else {
        buf.write(ch);
      }
    } else if (ch == '"' || ch == "'") {
      quote = ch;
      inWord = true;
    } else if (ch.trim().isEmpty) {
      if (inWord) words.add(buf.toString());
      buf.clear();
      inWord = false;
    } else {
      buf.write(ch);
      inWord = true;
    }
  }
  if (inWord) words.add(buf.toString());
  return words;
}

/// The comparable shape of one command line.
class CommandShape {
  const CommandShape(this.positional, this.flags, this.trailing);

  final List<String> positional;

  /// `--flag` or `--flag=value`, sorted.
  final List<String> flags;

  /// Words after `--`, verbatim.
  final List<String> trailing;

  @override
  bool operator ==(Object other) =>
      other is CommandShape &&
      _eq(positional, other.positional) &&
      _eq(flags, other.flags) &&
      _eq(trailing, other.trailing);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(positional),
    Object.hashAll(flags),
    Object.hashAll(trailing),
  );

  @override
  String toString() => '$positional $flags -- $trailing';

  static bool _eq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

CommandShape normalizeCommand(String text) {
  var words = _words(text.trim());
  if (words.isNotEmpty && words.first == r'$') words = words.sublist(1);
  if (words.isNotEmpty && words.first == 'k') words[0] = 'kubectl';

  final positional = <String>[];
  final flags = <String>[];
  final trailing = <String>[];
  var i = 0;
  while (i < words.length) {
    final w = words[i++];
    if (w == '--') {
      trailing.addAll(words.sublist(i));
      break;
    }
    if (!w.startsWith('-') || w == '-') {
      // `type/name` → `type name` when the type is a known resource.
      final slash = w.indexOf('/');
      final type = slash > 0 ? _resource(w.substring(0, slash)) : null;
      if (type != null && _resourceNames.contains(type)) {
        positional
          ..add(type)
          ..add(w.substring(slash + 1));
      } else {
        positional.add(_resource(w));
      }
      continue;
    }
    // Combined boolean shorts: -it → -i -t.
    if (!w.startsWith('--') &&
        w.length > 2 &&
        w.substring(1).split('').every(_booleanShorts.contains)) {
      for (final c in w.substring(1).split('')) {
        flags.add(_flagAliases['-$c'] ?? '-$c');
      }
      continue;
    }
    var name = w;
    String? value;
    final eq = w.indexOf('=');
    if (eq > 0) {
      name = w.substring(0, eq);
      value = w.substring(eq + 1);
    }
    name = _flagAliases[name] ?? name;
    if (value == null &&
        !_booleanFlags.contains(name) &&
        i < words.length &&
        words[i] != '--' &&
        !words[i].startsWith('-')) {
      value = words[i++];
    }
    flags.add(value == null ? name : '$name=$value');
  }
  flags.sort();
  return CommandShape(positional, flags, trailing);
}

/// Whether [typed] matches any of [accepted].
bool commandMatches(String typed, List<String> accepted) {
  if (typed.trim().isEmpty) return false;
  final shape = normalizeCommand(typed);
  return accepted.any((a) => normalizeCommand(a) == shape);
}
