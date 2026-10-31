import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/utils/utils.dart' as sqflite_utils;

/// Runs before every test file.
///
/// 1. Loads the bundled Manrope and Instrument Serif fonts, so goldens render
///    the real type instead of the test-only "Ahem" boxes.
/// 2. Installs a golden comparator that tolerates up to 0.5 % differing
///    pixels, so anti-aliasing differences between Linux machines do not
///    flake CI. `--update-goldens` still works.
/// 3. Disables sqflite's "database locked" warning timer. Every query that
///    waits for the database lock arms a 10 s `Timer` under the test's fake
///    clock; a slow runner can finish the widget test before the real-thread
///    query returns, and the still-armed timer fails the test with
///    "A Timer is still pending even after the widget tree was disposed"
///    (CI run for a9aee63). The warning only exists to flag deadlocks in
///    development, so tests do without it (D-080).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // `setLockWarningInfo` cannot clear the duration (`duration ?? current`),
  // so the deprecated setter is the only way to switch the timer off.
  // ignore: deprecated_member_use
  sqflite_utils.lockWarningDuration = null;
  await loadFpFonts();
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = FpGoldenComparator(
      current.basedir.resolve('placeholder_test.dart'),
    );
  }
  await testMain();
}

bool _fontsLoaded = false;

/// Loads the bundled fonts from `assets/fonts` (idempotent).
Future<void> loadFpFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final root = _findPackageRoot();
  if (root == null) return;
  final dir = Directory('${root.path}/assets/fonts');
  if (!dir.existsSync()) return;
  Future<ByteData> read(String name) async {
    final bytes = await File('${dir.path}/$name').readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final manrope = FontLoader('Manrope')
    ..addFont(read('Manrope-Regular.ttf'))
    ..addFont(read('Manrope-Medium.ttf'))
    ..addFont(read('Manrope-SemiBold.ttf'))
    ..addFont(read('Manrope-Bold.ttf'))
    ..addFont(read('Manrope-ExtraBold.ttf'));
  final serif = FontLoader('InstrumentSerif')
    ..addFont(read('InstrumentSerif-Regular.ttf'))
    ..addFont(read('InstrumentSerif-Italic.ttf'));
  await manrope.load();
  await serif.load();
}

Directory? _findPackageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

/// A [LocalFileComparator] that passes when at most [tolerance] of the
/// pixels differ.
class FpGoldenComparator extends LocalFileComparator {
  FpGoldenComparator(super.testFile, {this.tolerance = 0.005});

  /// Maximum allowed fraction of differing pixels (0.005 = 0.5 %).
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= tolerance) {
      debugPrint(
        'Golden $golden differs by '
        '${(result.diffPercent * 100).toStringAsFixed(3)} % '
        '(within ${(tolerance * 100).toStringAsFixed(1)} % tolerance)',
      );
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}
