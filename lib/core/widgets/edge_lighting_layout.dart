import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fully responsive metrics for edge LED overlays on any phone size.
class EdgeLightingLayout {
  const EdgeLightingLayout({
    required this.pathInset,
    required this.halfMaxStroke,
    required this.cornerRadius,
    required this.highlightLength,
    required this.trailLength,
    required this.paintSize,
  });

  /// Distance from the canvas edge to the glow path (prevents clipping).
  final EdgeInsets pathInset;

  final double halfMaxStroke;
  final double cornerRadius;
  final double highlightLength;
  final double trailLength;
  final Size paintSize;

  double get strokeWidth => halfMaxStroke * 2;

  @override
  bool operator ==(Object other) {
    return other is EdgeLightingLayout &&
        other.pathInset == pathInset &&
        other.halfMaxStroke == halfMaxStroke &&
        other.cornerRadius == cornerRadius &&
        other.highlightLength == highlightLength &&
        other.trailLength == trailLength &&
        other.paintSize == paintSize;
  }

  @override
  int get hashCode => Object.hash(
    pathInset,
    halfMaxStroke,
    cornerRadius,
    highlightLength,
    trailLength,
    paintSize,
  );

  static EdgeLightingLayout resolveFromView({
    required Size size,
    required EdgeInsets viewPadding,
    EdgeInsets padding = EdgeInsets.zero,
    required double devicePixelRatio,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    return resolve(
      size: size,
      viewPadding: viewPadding,
      padding: padding,
      devicePixelRatio: devicePixelRatio,
      platform: platform,
    );
  }

  static EdgeInsets safeAreaInsets({
    required EdgeInsets viewPadding,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return EdgeInsets.fromLTRB(
      math.max(viewPadding.left, padding.left),
      math.max(viewPadding.top, padding.top),
      math.max(viewPadding.right, padding.right),
      math.max(viewPadding.bottom, padding.bottom),
    );
  }

  /// Read system insets directly from the [FlutterView] (immune to MediaQuery overrides).
  static EdgeInsets insetsFromContext(BuildContext context) {
    final view = View.of(context);
    final data = MediaQueryData.fromView(view);
    return safeAreaInsets(
      viewPadding: data.viewPadding,
      padding: data.padding,
    );
  }

  static EdgeLightingLayout resolve({
    required Size size,
    required EdgeInsets viewPadding,
    EdgeInsets padding = EdgeInsets.zero,
    required double devicePixelRatio,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    if (size.isEmpty) {
      return const EdgeLightingLayout(
        pathInset: EdgeInsets.all(6),
        halfMaxStroke: 4,
        cornerRadius: 14,
        highlightLength: 80,
        trailLength: 120,
        paintSize: Size.zero,
      );
    }

    final dpr = devicePixelRatio.clamp(1.0, 4.0);
    final width = size.width;
    final height = size.height;
    final shortest = math.min(width, height);
    final longest = math.max(width, height);
    final aspect = longest / shortest;

    // 0 = compact (SE/mini), 1 = large (Pro Max / Ultra)
    final sizeT = ((shortest - 320) / 120).clamp(0.0, 1.0);

    final strokeWidth = _adaptiveStrokeWidth(
      shortestSide: shortest,
      devicePixelRatio: dpr,
      sizeT: sizeT,
    );
    final halfStroke = strokeWidth / 2;

    // Outward glow extends ~half the widest layer; keep it inside the canvas.
    final glowBleed = halfStroke * (1.05 + (0.15 * (1 - sizeT)));

    // Android: start below status bar / nav bar safe areas.
    // iOS: full-screen edge-to-edge (display corners).
    final edgePad = glowBleed + halfStroke;
    final safe = safeAreaInsets(viewPadding: viewPadding, padding: padding);
    final topInset =
        platform == TargetPlatform.android ? edgePad + safe.top : edgePad;
    final bottomInset =
        platform == TargetPlatform.android ? edgePad + safe.bottom : edgePad;

    final pathInset = EdgeInsets.fromLTRB(
      edgePad,
      topInset,
      edgePad,
      bottomInset,
    );

    final drawableWidth = width - pathInset.horizontal;
    final drawableHeight = height - pathInset.vertical;

    final cornerRadius = _adaptiveCornerRadius(
      drawableWidth: drawableWidth,
      drawableHeight: drawableHeight,
      shortestSide: shortest,
      sizeT: sizeT,
      platform: platform,
      devicePixelRatio: dpr,
      halfStroke: halfStroke,
      topCutout: platform == TargetPlatform.android ? safe.top : 0,
    );

    final perimeter = _estimatePerimeter(
      width: drawableWidth,
      height: drawableHeight,
      cornerRadius: cornerRadius,
    );

    final highlightLength = (perimeter * _highlightFraction(aspect, sizeT)).clamp(
      strokeWidth * 3,
      perimeter * 0.18,
    );
    final trailLength = (perimeter * _trailFraction(aspect, sizeT)).clamp(
      strokeWidth * 4,
      perimeter * 0.22,
    );

    return EdgeLightingLayout(
      pathInset: pathInset,
      halfMaxStroke: halfStroke,
      cornerRadius: cornerRadius,
      highlightLength: highlightLength,
      trailLength: trailLength,
      paintSize: size,
    );
  }

  static double _adaptiveStrokeWidth({
    required double shortestSide,
    required double devicePixelRatio,
    required double sizeT,
  }) {
    // ~24–40 physical px, thinner on compact phones to avoid corner clipping.
    final nativePx = 22 + (18 * sizeT);
    final logical = nativePx / devicePixelRatio;
    final compactCap = shortestSide < 360 ? 8.5 : 11.5;
    return logical.clamp(3.5, compactCap);
  }

  static double _adaptiveCornerRadius({
    required double drawableWidth,
    required double drawableHeight,
    required double shortestSide,
    required double sizeT,
    required TargetPlatform platform,
    required double devicePixelRatio,
    required double halfStroke,
    required double topCutout,
  }) {
    if (drawableWidth <= 8 || drawableHeight <= 8) return 10;

    final minSide = math.min(drawableWidth, drawableHeight);
    final maxRadius = (minSide / 2) - halfStroke - 1;

    final displayCorner = platform == TargetPlatform.iOS
        ? _iosDisplayCornerRadius(shortestSide, sizeT, topCutout)
        : _androidDisplayCornerRadius(
            shortestSide,
            sizeT,
            devicePixelRatio: devicePixelRatio,
          );

    // Path sits inside the display corner arc.
    final pathRadius = displayCorner - halfStroke - 1;

    return pathRadius.clamp(8.0, maxRadius);
  }

  /// Continuous iOS corner scale: SE (~28 pt) → Pro Max (~55 pt).
  static double _iosDisplayCornerRadius(
    double shortestSide,
    double sizeT,
    double topCutout,
  ) {
    var radius = _lerp(28.0, 55.0, sizeT);

    // Smooth width-based fine tuning between size classes.
    if (shortestSide >= 430) {
      radius = _lerp(radius, 55.0, 0.65);
    } else if (shortestSide >= 390) {
      radius = _lerp(radius, 47.0, 0.55);
    } else if (shortestSide >= 360) {
      radius = _lerp(radius, 39.0, 0.45);
    }

    // Dynamic Island / notch devices have slightly rounder visible corners.
    if (topCutout >= 50) {
      radius += 2.0;
    } else if (topCutout >= 44) {
      radius += 1.0;
    }

    return radius.clamp(24.0, 58.0);
  }

  /// Continuous Android corner scale: small (~14 pt) → large (~32 pt).
  static double _androidDisplayCornerRadius(
    double shortestSide,
    double sizeT, {
    required double devicePixelRatio,
  }) {
    final ratioBased = shortestSide * _lerp(0.038, 0.052, sizeT);
    final physicalBased = (36 + 16 * sizeT) / devicePixelRatio;
    return _lerp(ratioBased, physicalBased, 0.5).clamp(10.0, 36.0);
  }

  static double _estimatePerimeter({
    required double width,
    required double height,
    required double cornerRadius,
  }) {
    if (width <= 0 || height <= 0) return 0;
    final r = cornerRadius.clamp(0.0, math.min(width, height) / 2);
    return 2 * (width + height - 4 * r) + 2 * math.pi * r;
  }

  static double _highlightFraction(double aspectRatio, double sizeT) {
    final base =
        aspectRatio >= 2.15
            ? 0.070
            : aspectRatio >= 2.05
            ? 0.066
            : 0.060;
    return base + (0.006 * sizeT);
  }

  static double _trailFraction(double aspectRatio, double sizeT) {
    final base =
        aspectRatio >= 2.15
            ? 0.100
            : aspectRatio >= 2.05
            ? 0.094
            : 0.086;
    return base + (0.008 * sizeT);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
