// Summarises `coverage/lcov.info` per top-level `lib/` folder as a Markdown
// table (lines hit / lines found / percentage), so the numbers in README.md
// and docs/LOAD_TEST_REPORT.md come from the real run and not from memory.
//
// Usage:
//   flutter test --coverage --concurrency=4
//   dart run tool/coverage_summary.dart [coverage/lcov.info]
//
// Only LF/LH are read, so the output matches `lcov --summary`. Files are
// grouped by the first path segment under `lib/` (`lib/app.dart` and
// `lib/main.dart` fall under "lib (root)").
import 'dart:io';

void main(List<String> args) {
  final path = args.isEmpty ? 'coverage/lcov.info' : args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No lcov file at $path. Run flutter test --coverage first.');
    exitCode = 2;
    return;
  }
  final table = summarise(file.readAsLinesSync());
  stdout.write(render(table));
}

/// Lines found / hit per group, plus the total under the key `lib (total)`.
Map<String, ({int found, int hit})> summarise(List<String> lines) {
  final totals = <String, ({int found, int hit})>{};
  String? group;
  var found = 0;
  var hit = 0;
  void flush() {
    final key = group;
    if (key == null) return;
    final current = totals[key] ?? (found: 0, hit: 0);
    totals[key] = (found: current.found + found, hit: current.hit + hit);
    group = null;
    found = 0;
    hit = 0;
  }

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      group = groupOf(line.substring(3));
    } else if (line.startsWith('LF:')) {
      found = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit = int.parse(line.substring(3));
    } else if (line == 'end_of_record') {
      flush();
    }
  }
  flush();
  final totalFound = totals.values.fold(0, (sum, r) => sum + r.found);
  final totalHit = totals.values.fold(0, (sum, r) => sum + r.hit);
  final sorted = Map.fromEntries(
    totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  sorted['lib (total)'] = (found: totalFound, hit: totalHit);
  return sorted;
}

/// `lib/core/money/money.dart` → `lib/core`; `lib/app.dart` → `lib (root)`.
String groupOf(String sourcePath) {
  final normalised = sourcePath.replaceAll(r'\', '/');
  final index = normalised.indexOf('lib/');
  final relative = index < 0 ? normalised : normalised.substring(index + 4);
  final slash = relative.indexOf('/');
  if (slash < 0) return 'lib (root)';
  return 'lib/${relative.substring(0, slash)}';
}

/// The Markdown table, total last.
String render(Map<String, ({int found, int hit})> table) {
  final buffer = StringBuffer()
    ..writeln('| Folder | Lines hit | Lines found | Coverage |')
    ..writeln('|---|---:|---:|---:|');
  for (final entry in table.entries) {
    final r = entry.value;
    final pct = r.found == 0 ? 0.0 : r.hit * 100 / r.found;
    final name = entry.key == 'lib (total)'
        ? '**${entry.key}**'
        : '`${entry.key}`';
    buffer.writeln(
      '| $name | ${r.hit} | ${r.found} | ${pct.toStringAsFixed(1)} % |',
    );
  }
  return buffer.toString();
}
