// Driver for the on-device integration tests (spec §7b):
//
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/app_flows_test.dart --no-dds -d <device id>
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/perf_test.dart --profile --no-dds -d <device id>
//
// Every `binding.traceAction(..., reportKey: '<name>_timeline')` in a target
// is summarised with `TimelineSummary` and written to
// `build/perf/<name>.timeline_summary.json` (plus the raw timeline);
// `binding.watchPerformance(..., reportKey: '<name>_performance')` results
// are already summaries and are written as `build/perf/<name>.performance.json`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

const String outputDirectory = 'build/perf';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final directory = Directory(outputDirectory)..createSync(recursive: true);
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      if (entry.key.endsWith('_timeline')) {
        final name = entry.key.substring(
          0,
          entry.key.length - '_timeline'.length,
        );
        final summary = TimelineSummary.summarize(Timeline.fromJson(value));
        if (summary.countFrames() == 0) {
          // A section that did not render (e.g. a guarded step was skipped)
          // has nothing to summarise; `writeTimelineToFile` would throw.
          stdout.writeln('$name: no frames recorded, summary skipped');
          continue;
        }
        await summary.writeTimelineToFile(
          name,
          destinationDirectory: directory.path,
        );
        stdout.writeln(
          '$name: avg build ${summary.computeAverageFrameBuildTimeMillis()}'
          ' ms, p90 ${summary.computePercentileFrameBuildTimeMillis(90)} ms,'
          ' p99 ${summary.computePercentileFrameBuildTimeMillis(99)} ms,'
          ' avg raster ${summary.computeAverageFrameRasterizerTimeMillis()}'
          ' ms, missed build ${summary.computeMissedFrameBuildBudgetCount()},'
          ' missed raster '
          '${summary.computeMissedFrameRasterizerBudgetCount()}',
        );
      } else if (entry.key.endsWith('_performance')) {
        final name = entry.key.substring(
          0,
          entry.key.length - '_performance'.length,
        );
        File(
          '${directory.path}/$name.performance.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));
        stdout.writeln('$name: ${jsonEncode(value)}');
      }
    }
  },
);
