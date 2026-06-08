import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../controllers/rtmp_broadcast_controller.dart';

/// Per-route lifecycle for [GoLiveScreen].
/// Rx updates are deferred to after the route build frame (GetX bindings run during build).
class GoLiveRouteController extends GetxController {
  RtmpBroadcastController get broadcast =>
      Get.isRegistered<RtmpBroadcastController>()
          ? Get.find<RtmpBroadcastController>()
          : Get.put(RtmpBroadcastController(), permanent: true);

  @override
  void onInit() {
    super.onInit();
    _afterFrame(() {
      if (isClosed) return;
      broadcast.onEnterGoLiveScreen();
      if (!broadcast.isReady.value && !broadcast.isInitializing.value) {
        unawaited(broadcast.ensureInitialized());
      }
    });
  }

  @override
  void onClose() {
    if (Get.isRegistered<RtmpBroadcastController>()) {
      final keepBroadcasting = broadcast.hasActiveBroadcast;
      broadcast.onLeaveGoLiveScreen(keepBroadcasting: keepBroadcasting);
      if (keepBroadcasting) {
        broadcast.revealFloatingPipIfNeeded();
      }
    }
    super.onClose();
  }

  void _afterFrame(VoidCallback action) {
    SchedulerBinding.instance.addPostFrameCallback((_) => action());
  }
}
