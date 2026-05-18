import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../controllers/Main Section Controllers/settings_controller.dart';
import '../../controllers/edge_glow_notification_controller.dart';
import 'edge_glow_painter.dart';

/// Full-screen edge LED glow for realtime activity / notifications (iOS + Android).
class GlobalEdgeGlowOverlay extends StatefulWidget {
  const GlobalEdgeGlowOverlay({super.key});

  @override
  State<GlobalEdgeGlowOverlay> createState() => _GlobalEdgeGlowOverlayState();
}

class _GlobalEdgeGlowOverlayState extends State<GlobalEdgeGlowOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _fadeDuration = Duration(milliseconds: 240);

  late final AnimationController _rotationController;
  late final EdgeGlowNotificationController _edgeGlowCtrl;
  late final SettingsController _settingsCtrl;

  Worker? _sequenceWorker;
  Worker? _visibilityWorker;

  @override
  void initState() {
    super.initState();
    _edgeGlowCtrl = Get.find<EdgeGlowNotificationController>();
    _settingsCtrl = Get.find<SettingsController>();

    _rotationController = AnimationController(
      vsync: this,
      duration: EdgeGlowPainter.rotationDuration,
    );

    _sequenceWorker = ever<int>(_edgeGlowCtrl.sequence, (_) => _syncAnimation());
    _visibilityWorker =
        ever<bool>(_edgeGlowCtrl.isVisible, (_) => _syncAnimation());
  }

  void _syncAnimation() {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!mounted) return;

      final visible = _edgeGlowCtrl.isVisible.value;
      if (!visible) {
        _rotationController.stop();
        return;
      }

      final slow = _settingsCtrl.reduceMotion;
      _rotationController.duration = slow
          ? const Duration(milliseconds: 5600)
          : EdgeGlowPainter.rotationDuration;

      _rotationController
        ..stop()
        ..reset()
        ..repeat();
    });
  }

  @override
  void dispose() {
    _sequenceWorker?.dispose();
    _visibilityWorker?.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final visible = _edgeGlowCtrl.isVisible.value;
      if (!visible) {
        return const SizedBox.shrink();
      }

      _settingsCtrl.animations.value;
      _settingsCtrl.lowPowerMode.value;

      final platform = _edgeGlowCtrl.activePlatform.value;
      final colors = EdgeGlowPainter.platformColors(platform);
      final animate = _settingsCtrl.animationsEnabled;

      return Positioned.fill(
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: 1,
            duration: _fadeDuration,
            curve: Curves.easeOutCubic,
            child: RepaintBoundary(
              child: ClipRect(
                clipBehavior: Clip.none,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                      animation: _rotationController,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: EdgeGlowPainter(
                            progress:
                                animate ? _rotationController.value : 0.18,
                            colors: colors,
                            animate: animate,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
