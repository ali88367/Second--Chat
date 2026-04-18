import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';

import 'Compact_freeze.dart';
import 'Freeze_bottomsheet.dart';
import 'Streaksbottomsheet.dart';

class StreakSheetRouter extends StatefulWidget {
  const StreakSheetRouter({super.key, this.forceFreezePreview = false});

  final bool forceFreezePreview;

  @override
  State<StreakSheetRouter> createState() => _StreakSheetRouterState();
}

class _StreakSheetRouterState extends State<StreakSheetRouter> {
  late final StreamStreaksController _streakCtrl;

  @override
  void initState() {
    super.initState();
    _streakCtrl = Get.find<StreamStreaksController>();
    // Refresh in the background; this widget must never block sheet opening.
    unawaited(_streakCtrl.fetchCurrentStreak(force: true, silent: true));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final streak = _streakCtrl.current.value;
      if (streak == null) {
        // While loading, show the compact view (no loader). If loading finished
        // and still null, treat it as "no streak created yet".
        if (_streakCtrl.isLoading.value) {
          return StreakFreezeSingleRowPreviewBottomSheet(
            fetchOnInit: false,
          );
        }
        return const StreamStreakSetupBottomSheet();
      }
      final isInDanger =
          widget.forceFreezePreview || streak.isInDanger;

      // Use [StreakData.isConfigured], not [hasCreatedStreak]: new accounts can
      // have a server-side streak with count 0 before any check-ins.
      if (!streak.isConfigured) {
        return const StreamStreakSetupBottomSheet();
      }
      if (isInDanger) {
        return const StreakFreezePreviewBottomSheet(fetchOnInit: false);
      }
      return const StreakFreezeSingleRowPreviewBottomSheet(fetchOnInit: false);
    });
  }
}
