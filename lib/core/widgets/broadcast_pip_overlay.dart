import 'dart:async';

import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../controllers/rtmp_broadcast_controller.dart';
import '../../features/go_live/go_live_screen.dart' show openGoLiveScreen;

/// Draggable floating camera preview while broadcasting outside [GoLiveScreen].
class BroadcastPipOverlay extends StatelessWidget {
  const BroadcastPipOverlay({super.key});

  static const double _pipWidth = 112;
  static const double _pipHeight = 168;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<RtmpBroadcastController>()) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<RtmpBroadcastController>();

    return Obx(() {
      if (!controller.canShowCameraPreviewInPip) {
        return const SizedBox.shrink();
      }

      final live = controller.liveController;
      if (live == null) return const SizedBox.shrink();

      final media = MediaQuery.of(context);
      final pipW = _pipWidth.w;
      final pipH = _pipHeight.h;
      final maxX = media.size.width - pipW - 8.w;
      final maxY = media.size.height - pipH - media.padding.bottom - 80.h;
      final left = controller.pipOffsetX.value.clamp(8.0, maxX);
      final top = controller.pipOffsetY.value.clamp(
        media.padding.top + 8,
        maxY,
      );

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: left,
            top: top,
            width: pipW,
            height: pipH,
            child: _DraggablePipCard(
              controller: controller,
              live: live,
              width: pipW,
              height: pipH,
              maxX: maxX,
              maxY: maxY,
              topInset: media.padding.top + 8,
            ),
          ),
        ],
      );
    });
  }
}

class _DraggablePipCard extends StatelessWidget {
  const _DraggablePipCard({
    required this.controller,
    required this.live,
    required this.width,
    required this.height,
    required this.maxX,
    required this.maxY,
    required this.topInset,
  });

  final RtmpBroadcastController controller;
  final ApiVideoLiveStreamController live;
  final double width;
  final double height;
  final double maxX;
  final double maxY;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final nextX = (controller.pipOffsetX.value + details.delta.dx)
              .clamp(8.0, maxX);
          final nextY = (controller.pipOffsetY.value + details.delta.dy)
              .clamp(topInset, maxY);
          controller.updatePipPosition(nextX, nextY);
        },
        onTap: () {
          controller.hideFloatingPip();
          openGoLiveScreen();
        },
        child: Material(
          elevation: 12,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(14.r),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ApiVideoCameraPreview(
                  controller: live,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 6.h,
                  left: 6.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4.h,
                  right: 4.w,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(controller.stopBroadcast()),
                    child: Container(
                      width: 24.w,
                      height: 24.w,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.close, size: 14.sp, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
