import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/motion/fp_pressable.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_depth.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';
import 'package:neopop/neopop.dart';

/// Visual weight of an [FpSurface].
enum FpSurfaceVariant {
  /// Flat surface with a hairline border, no edge.
  flat,

  /// Plunk surface: solid bottom/right edge faces (NeoPOP).
  plunk,

  /// Raised: lighter face plus edge, for the topmost layer.
  raised,
}

/// A NeoPOP surface (card, row, panel). Replaces `NeoPopCard` and
/// `NeumorphicContainer`.
///
/// When [onTap] is set the surface is pressable: it plunks into its edge,
/// plays a haptic and exposes button semantics.
class FpSurface extends StatelessWidget {
  const FpSurface({
    required this.child,
    super.key,
    this.variant = FpSurfaceVariant.plunk,
    this.padding = FpSpacing.card,
    this.color,
    this.edge,
    this.depth,
    this.onTap,
    this.semanticLabel,
    this.haptics,
    this.width,
    this.height,
  });

  final Widget child;
  final FpSurfaceVariant variant;
  final EdgeInsetsGeometry padding;

  /// Face colour. Defaults by [variant].
  final Color? color;

  /// Edge colours. Defaults by [variant].
  final FpEdge? edge;

  /// Edge depth in pixels. Defaults to the surface depth token.
  final double? depth;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final HapticService? haptics;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final face =
        color ??
        switch (variant) {
          FpSurfaceVariant.flat => c.surface,
          FpSurfaceVariant.plunk => c.surface,
          FpSurfaceVariant.raised => c.surfaceRaised,
        };
    final edges =
        edge ??
        switch (variant) {
          FpSurfaceVariant.flat => null,
          FpSurfaceVariant.plunk => FpEdge.surface,
          FpSurfaceVariant.raised => FpEdge.surfaceRaised,
        };
    final d = variant == FpSurfaceVariant.flat
        ? 0.0
        : (depth ?? fp.metrics.depthSurface);

    final content = Padding(padding: padding, child: child);
    Widget body;
    if (edges == null) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: face,
          border: Border.all(color: c.border),
        ),
        child: SizedBox(width: width, height: height, child: content),
      );
    } else {
      body = Padding(
        // NeoPopCard paints its edges outside its own box; reserve the room
        // so neighbours never overlap the edge.
        padding: EdgeInsets.only(right: d, bottom: d),
        child: NeoPopCard(
          color: face,
          depth: d,
          hShadowColor: edges.right,
          vShadowColor: edges.bottom,
          borderColor: c.border,
          // The card draws a 1 px border around its child; subtract it so
          // the requested size is the outer size.
          child: SizedBox(
            width: width == null ? null : width! - d - 2,
            height: height == null ? null : height! - d - 2,
            child: content,
          ),
        ),
      );
    }

    final tap = onTap;
    if (tap == null) {
      final label = semanticLabel;
      return label == null
          ? body
          : Semantics(
              container: true,
              explicitChildNodes: true,
              label: label,
              child: body,
            );
    }
    return FpPressable(
      onPressed: tap,
      semanticLabel: semanticLabel,
      depth: d,
      scale: 0.985,
      haptics: haptics,
      child: body,
    );
  }
}
