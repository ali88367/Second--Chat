import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../controllers/rtmp_broadcast_controller.dart';
import '../../core/localization/l10n.dart';
import '../../core/themes/textstyles.dart';

/// Shown in the live stream embed area when the user is broadcasting via RTMP
/// but the platform player is not live yet (no stream overlay state).
class BroadcastEmbedPreview extends StatelessWidget {
  const BroadcastEmbedPreview({
    super.key,
    required this.platformKey,
    this.fillConstraints = false,
    this.height = 1,
  });

  final String platformKey;
  final bool fillConstraints;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<RtmpBroadcastController>()) {
      return const SizedBox.shrink();
    }
    final broadcast = Get.find<RtmpBroadcastController>();
    if (!broadcast.shouldShowBroadcastPreviewForPlatform(platformKey)) {
      return const SizedBox.shrink();
    }

    final live = broadcast.liveController;
    if (live == null) return const SizedBox.shrink();

    Widget preview(double w, double h) {
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          ApiVideoCameraPreview(
            controller: live,
            fit: BoxFit.cover,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '● BROADCASTING',
                      style: sfProText700(11.sp, Colors.white),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      context.l10n.noStreamAtTheMoment,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sfProText400(
                        11.sp,
                        Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (fillConstraints) {
      return LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          if (w <= 0 || h <= 0) {
            return const ColoredBox(color: Colors.black);
          }
          return preview(w, h);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite && c.maxWidth > 0
            ? c.maxWidth
            : MediaQuery.sizeOf(context).width;
        return SizedBox(
          width: w,
          height: height,
          child: preview(w, height),
        );
      },
    );
  }
}
