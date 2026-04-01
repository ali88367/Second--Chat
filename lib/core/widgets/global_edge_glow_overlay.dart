import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/edge_glow_notification_controller.dart';

class GlobalEdgeGlowOverlay extends StatefulWidget {
  const GlobalEdgeGlowOverlay({super.key});

  @override
  State<GlobalEdgeGlowOverlay> createState() => _GlobalEdgeGlowOverlayState();
}

class _GlobalEdgeGlowOverlayState extends State<GlobalEdgeGlowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final EdgeGlowNotificationController _edgeGlowCtrl;
  int _lastSequence = -1;

  @override
  void initState() {
    super.initState();
    _edgeGlowCtrl = Get.find<EdgeGlowNotificationController>();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final visible = _edgeGlowCtrl.isVisible.value;
      final sequence = _edgeGlowCtrl.sequence.value;
      final platform = _edgeGlowCtrl.activePlatform.value;

      if (visible && sequence != _lastSequence) {
        _lastSequence = sequence;
        _controller
          ..stop()
          ..reset()
          ..repeat();
      } else if (!visible && _controller.isAnimating) {
        _controller.stop();
      }

      final colors = _platformGlowColors(platform);

      return IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return CustomPaint(
                  painter: _EdgeGlowPainter(
                    progress: _controller.value,
                    colors: colors,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      );
    });
  }

  List<Color> _platformGlowColors(String platform) {
    final key = platform.toLowerCase().trim();
    switch (key) {
      case 'twitch':
        return const [
          Color(0xFF8F3DDB),
          Color(0xFFC45BFF),
        ];
      case 'kick':
        return const [
          Color(0xFF00FF87),
          Color(0xFF2BFF00),
          Color(0xFF00E6A8),
          Color(0xFF7CFF3A),
          Color(0xFF00FF5A),
        ];
      case 'youtube':
        return const [
          Color(0xFFFF1744),
          Color(0xFFFF5252),
        ];
      case 'tiktok':
        return const [
          Color(0xFF00F2EA),
          Color(0xFFFF0050),
          Color(0xFF69C9D0),
        ];
      default:
        return const [
          Color(0xFF8F3DDB),
          Color(0xFFC45BFF),
        ];
    }
  }
}

class _EdgeGlowPainter extends CustomPainter {
  _EdgeGlowPainter({
    required this.progress,
    required this.colors,
  });

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const margin = 10.0;
    final rect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(26)),
      );

    final breathing = 0.75 + (0.25 * sin(progress * pi * 2).abs());

    final gradient = SweepGradient(
      colors: colors,
      stops: List.generate(colors.length, (i) {
        if (colors.length <= 1) return 1.0;
        return i / (colors.length - 1);
      }),
      transform: GradientRotation(progress * pi * 2),
    );

    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20 * breathing
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25)
      ..shader = gradient.createShader(rect)
      ..color = Colors.white.withValues(alpha: 0.45);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * breathing
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..shader = gradient.createShader(rect)
      ..color = Colors.white.withValues(alpha: 0.85);

    final sharpPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = gradient.createShader(rect)
      ..color = Colors.white.withValues(alpha: 0.35);

    canvas.drawPath(path, outerPaint);
    canvas.drawPath(path, innerPaint);
    canvas.drawPath(path, sharpPaint);
  }

  @override
  bool shouldRepaint(covariant _EdgeGlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colors != colors;
  }
}
