// Renders the app icon and splash artwork from code, so the brand assets are
// an original design that lives in the repo as Dart, not as downloaded art.
//
// Run (needs the Flutter engine for `dart:ui`, hence `flutter test`):
//
//   flutter test tool/render_brand_assets.dart --dart-define=FINPAY_RENDER_ASSETS=true
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Without the define the file registers one skipped test and writes nothing,
// so a plain `flutter test` (which only looks under test/ anyway) is never
// affected.
//
// Design (D-070): a near-black NeoPOP tile in `FpColors.background`, an
// accent plate with the solid offset "edge" that every NeoPOP surface in
// the app has, and a bold geometric F cut out of the plate in the tile
// colour. The same mark, at different scales, is the legacy icon, the
// adaptive-icon foreground, the monochrome (themed) icon and the splash.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fin_pay/design_system/tokens/fp_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// True when started with `--dart-define=FINPAY_RENDER_ASSETS=true`.
const bool renderEnabled = bool.fromEnvironment('FINPAY_RENDER_ASSETS');

/// Output folder (the pubspec `flutter_launcher_icons` / `flutter_native_splash`
/// sections point here).
const String outputDir = 'assets/brand';

/// The outputs: file name, canvas size, mark scale (1 = the 1024 design) and
/// whether the tile is painted behind the mark.
const List<BrandAsset> assets = [
  BrandAsset('icon.png', 1024, 1, tile: true),
  BrandAsset('icon_foreground.png', 1024, 0.62),
  BrandAsset('icon_monochrome.png', 1024, 0.62, monochrome: true),
  BrandAsset('splash.png', 512, 0.5),
  BrandAsset('splash_android12.png', 1152, 0.55),
];

void main() {
  if (!renderEnabled) {
    test(
      'brand assets',
      () {},
      skip:
          'Run: flutter test tool/render_brand_assets.dart '
          '--dart-define=FINPAY_RENDER_ASSETS=true',
    );
    return;
  }

  for (final asset in assets) {
    testWidgets('renders ${asset.name}', (tester) async {
      await tester.runAsync(() async {
        final bytes = await renderPng(asset);
        final file = File('$outputDir/${asset.name}')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
        expect(file.lengthSync(), greaterThan(1000));
      });
    });
  }
}

/// One rendered file.
class BrandAsset {
  const BrandAsset(
    this.name,
    this.size,
    this.scale, {
    this.tile = false,
    this.monochrome = false,
  });

  final String name;
  final int size;
  final double scale;
  final bool tile;
  final bool monochrome;
}

/// Paints [asset] and encodes it as PNG.
Future<List<int>> renderPng(BrandAsset asset) async {
  final recorder = ui.PictureRecorder();
  final size = asset.size.toDouble();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
  BrandMarkPainter(
    scale: asset.scale,
    tile: asset.tile,
    monochrome: asset.monochrome,
  ).paint(canvas, Size(size, size));
  final picture = recorder.endRecording();
  final image = await picture.toImage(asset.size, asset.size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// The FinPay mark: a NeoPOP plate with a solid offset edge and a cut-out F.
///
/// Geometry is designed in a 1024 × 1024 space and scaled about the centre,
/// so every asset shares the same proportions.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
    this.scale = 1,
    this.tile = false,
    this.monochrome = false,
  });

  /// Mark size relative to the 1024 design.
  final double scale;

  /// Paint the background tile (legacy / iOS icon) or leave it transparent
  /// (adaptive foreground, splash).
  final bool tile;

  /// White silhouette with the F punched out (Android themed icon).
  final bool monochrome;

  /// Design-space constants.
  static const double design = 1024;
  static const double plateSize = 560;
  static const double plateRadius = 72;
  static const double edgeDepth = 56;
  static const double stroke = 92;

  @override
  void paint(Canvas canvas, Size size) {
    if (tile) {
      canvas.drawRect(Offset.zero & size, Paint()..color = FpColors.background);
    }
    final factor = size.shortestSide / design * scale;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(factor)
      ..translate(-design / 2, -design / 2);
    if (monochrome) {
      _paintMonochrome(canvas);
    } else {
      _paintMark(canvas);
    }
    canvas.restore();
  }

  Rect get _plate => Rect.fromCenter(
    center: const Offset(
      design / 2 - edgeDepth / 2,
      design / 2 - edgeDepth / 2,
    ),
    width: plateSize,
    height: plateSize,
  );

  RRect _rounded(Rect rect) =>
      RRect.fromRectAndRadius(rect, const Radius.circular(plateRadius));

  void _paintMark(Canvas canvas) {
    final plate = _plate;
    // The NeoPOP edge: the same plate pushed down-right, in the deep accent.
    canvas
      ..drawRRect(
        _rounded(plate.shift(const Offset(edgeDepth, edgeDepth))),
        Paint()..color = FpColors.accentDeep,
      )
      ..drawRRect(_rounded(plate), Paint()..color = FpColors.accent)
      ..drawPath(_letterF(plate), Paint()..color = FpColors.onPop);
    // A small success-green chip on the edge: the "paid" dot of the app.
    final chip = Rect.fromLTWH(
      plate.right - stroke * 0.9,
      plate.bottom - stroke * 0.9,
      stroke * 0.7,
      stroke * 0.7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chip, const Radius.circular(16)),
      Paint()..color = FpColors.success,
    );
  }

  void _paintMonochrome(Canvas canvas) {
    final plate = _plate;
    final bounds = plate.inflate(edgeDepth * 2);
    canvas
      ..saveLayer(bounds, Paint())
      ..drawRRect(
        _rounded(plate.shift(const Offset(edgeDepth, edgeDepth))),
        Paint()..color = Colors.white,
      )
      ..drawRRect(_rounded(plate), Paint()..color = Colors.white)
      ..drawPath(_letterF(plate), Paint()..blendMode = BlendMode.clear)
      ..restore();
  }

  /// A bold geometric F: a stem, a long top bar and a shorter middle bar,
  /// sized from the plate so it reads at launcher sizes.
  Path _letterF(Rect plate) {
    final left = plate.left + plate.width * 0.27;
    final top = plate.top + plate.height * 0.22;
    final height = plate.height * 0.56;
    final topBar = plate.width * 0.46;
    final midBar = plate.width * 0.34;
    final midTop = top + stroke * 1.55;
    return Path()
      ..addRect(Rect.fromLTWH(left, top, stroke, height))
      ..addRect(Rect.fromLTWH(left, top, topBar, stroke))
      ..addRect(Rect.fromLTWH(left, midTop, midBar, stroke));
  }

  @override
  bool shouldRepaint(covariant BrandMarkPainter old) =>
      old.scale != scale || old.tile != tile || old.monochrome != monochrome;
}
