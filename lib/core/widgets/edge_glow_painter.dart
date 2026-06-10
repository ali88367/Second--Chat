import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'edge_lighting_layout.dart';

/// Edge LED that travels around the full screen perimeter (iOS + Android).
class EdgeGlowPainter extends CustomPainter {
  EdgeGlowPainter({
    required this.progress,
    required this.colors,
    required this.layout,
    this.animate = true,
  });

  final double progress;
  final List<Color> colors;
  final EdgeLightingLayout layout;
  final bool animate;

  static const Duration rotationDuration = Duration(milliseconds: 2800);

  static List<Color> platformColors(String platform) {
    final key = platform.toLowerCase().trim();
    switch (key) {
      case 'twitch':
        return const [Color(0xFF8F3DDB), Color(0xFFC45BFF)];
      case 'kick':
        return const [
          Color(0xFF00FF87),
          Color(0xFF2BFF00),
          Color(0xFF00E6A8),
          Color(0xFF7CFF3A),
          Color(0xFF00FF5A),
        ];
      case 'youtube':
        return const [Color(0xFFFF1744), Color(0xFFFF5252)];
      case 'tiktok':
        return const [Color(0xFF00F2EA), Color(0xFFFF0050), Color(0xFF69C9D0)];
      default:
        return const [Color(0xFF8F3DDB), Color(0xFFC45BFF)];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final inset = layout.pathInset;
    final halfStroke = layout.halfMaxStroke;

    final rect = Rect.fromLTRB(
      inset.left,
      inset.top,
      size.width - inset.right,
      size.height - inset.bottom,
    );
    if (rect.width <= 4 || rect.height <= 4) return;

    final maxRadius = rect.shortestSide / 2;
    final radius = layout.cornerRadius.clamp(0.0, maxRadius);

    final borderPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    final phase = animate ? progress : 0.18;
    final breathing = animate
        ? 0.88 + 0.12 * (0.5 + 0.5 * math.sin(phase * math.pi * 2))
        : 1.0;

    _paintAmbientRing(canvas, rect, borderPath, phase, breathing, halfStroke);

    final metrics = borderPath.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    if (total <= 1) return;

    final head = (phase % 1.0) * total;
    _paintTravelingHighlight(
      canvas: canvas,
      metric: metric,
      totalLength: total,
      headDistance: head,
      breathing: breathing,
      halfStroke: halfStroke,
    );
  }

  void _paintAmbientRing(
    Canvas canvas,
    Rect rect,
    Path borderPath,
    double phase,
    double breathing,
    double halfStroke,
  ) {
    final loopColors = <Color>[...colors, colors.first];
    final shader = SweepGradient(
      colors: loopColors,
      stops: List<double>.generate(
        loopColors.length,
        (i) => i / (loopColors.length - 1),
      ),
      transform: GradientRotation(phase * math.pi * 2),
      tileMode: TileMode.clamp,
    ).createShader(rect);

    final outer = halfStroke * 2;
    final ambientLayers = <_GlowLayer>[
      _GlowLayer(width: outer, alpha: 0.12),
      _GlowLayer(width: outer * 0.58, alpha: 0.22),
      _GlowLayer(width: outer * 0.18, alpha: 0.45),
    ];

    for (final layer in ambientLayers) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer.width * breathing
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..shader = shader
        ..color = Color.fromRGBO(255, 255, 255, layer.alpha);
      canvas.drawPath(borderPath, paint);
    }
  }

  void _paintTravelingHighlight({
    required Canvas canvas,
    required ui.PathMetric metric,
    required double totalLength,
    required double headDistance,
    required double breathing,
    required double halfStroke,
  }) {
    final highlightLength = layout.highlightLength;
    final trailLength = layout.trailLength;

    double norm(double d) {
      var v = d % totalLength;
      if (v < 0) v += totalLength;
      return v;
    }

    final segStart = norm(headDistance - trailLength);
    final segEnd = norm(headDistance + highlightLength);

    final headColors = <Color>[
      colors.last.withValues(alpha: 0.0),
      ...colors,
      colors.first.withValues(alpha: 0.0),
    ];

    final outer = halfStroke * 2;

    void drawSegment(double from, double to, double opacity) {
      if (to <= from) return;
      final extracted = metric.extractPath(from, to);
      final bounds = extracted.getBounds();
      if (bounds.isEmpty) return;

      final shader = LinearGradient(
        colors: headColors,
        stops: List<double>.generate(
          headColors.length,
          (i) => i / (headColors.length - 1),
        ),
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds);

      for (final w in [outer * 0.9, outer * 0.5, outer * 0.16]) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * breathing
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..shader = shader
          ..color = Color.fromRGBO(255, 255, 255, opacity);
        canvas.drawPath(extracted, paint);
      }
    }

    if (segStart < segEnd) {
      drawSegment(segStart, segEnd, 0.68);
    } else {
      drawSegment(segStart, totalLength, 0.68);
      drawSegment(0, segEnd, 0.68);
    }
  }

  @override
  bool shouldRepaint(covariant EdgeGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animate != animate ||
        oldDelegate.colors != colors ||
        oldDelegate.layout != layout;
  }
}

class _GlowLayer {
  const _GlowLayer({required this.width, required this.alpha});
  final double width;
  final double alpha;
}
