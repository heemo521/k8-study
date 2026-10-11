// Fills web/sw.js's precache list and build hash in build/web/sw.js.
//
// Run after `flutter build web`:
//   dart run tool/gen_precache.dart [build/web]
//
// Precached: the app shell, all assets (study content, fonts, shaders), icons
// and the two CanvasKit variants a dart2js build can load. Skipped: debug
// symbols, Wasm-only renderers, licence NOTICES and Flutter's deprecated
// service worker — anything else still gets cached on first use.
import 'dart:convert';
import 'dart:io';

const _skipExact = {
  'sw.js',
  'flutter_service_worker.js',
  '.last_build_id',
  'assets/NOTICES',
};

final _skipPatterns = [
  RegExp(r'\.symbols$'),
  RegExp(r'^canvaskit/(skwasm|wimp)'),
  RegExp(r'^canvaskit/webparagraph/'),
];

bool _include(String path) =>
    !_skipExact.contains(path) && !_skipPatterns.any((p) => p.hasMatch(path));

/// 64-bit FNV-1a, enough to version the cache by build contents.
String _fnv1a(Iterable<List<int>> chunks) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final chunk in chunks) {
    for (final b in chunk) {
      hash = ((hash ^ BigInt.from(b)) * prime) & mask;
    }
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'build/web' : args.first);
  final sw = File('${root.path}/sw.js');
  if (!sw.existsSync()) {
    stderr.writeln('${sw.path} not found — run `flutter build web` first.');
    exit(1);
  }

  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.substring(root.path.length + 1).replaceAll('\\', '/'))
      .where(_include)
      .toList()
    ..sort();

  // Hash over path + contents. Small text files are hashed whole; for large
  // binaries the size and first/last 64 KB are enough to detect a change.
  final hash = _fnv1a([
    for (final path in files) ...[
      utf8.encode(path),
      () {
        final f = File('${root.path}/$path');
        final len = f.lengthSync();
        if (len <= 256 * 1024) return f.readAsBytesSync();
        final raf = f.openSync();
        final head = raf.readSync(64 * 1024);
        raf.setPositionSync(len - 64 * 1024);
        final tail = raf.readSync(64 * 1024);
        raf.closeSync();
        return [...utf8.encode('$len'), ...head, ...tail];
      }(),
    ],
  ]);

  final list = ['./', ...files];
  var source = sw.readAsStringSync();
  if (!source.contains('/*__PRECACHE_LIST__*/[]') ||
      !source.contains("'__BUILD_HASH__'")) {
    stderr.writeln('${sw.path} has no placeholders (already processed?).');
    exit(1);
  }
  source = source
      .replaceFirst('/*__PRECACHE_LIST__*/[]', jsonEncode(list))
      .replaceFirst("'__BUILD_HASH__'", "'$hash'");
  sw.writeAsStringSync(source);

  final bytes = files.fold<int>(
      0, (sum, p) => sum + File('${root.path}/$p').lengthSync());
  stdout.writeln('sw.js: ${list.length} entries, '
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB precached, build $hash');
}
