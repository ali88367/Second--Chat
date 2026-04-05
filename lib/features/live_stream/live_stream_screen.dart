import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';

import '../../../../core/themes/textstyles.dart';
import 'package:second_chat/core/utils/app_clock_format.dart';
import '../../../controllers/Main Section Controllers/settings_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../core/constants/app_colors/app_colors.dart';
import '../../core/widgets/stream_header_buttons.dart';
import '../../core/localization/l10n.dart';
import '../Invite/Invite_screen.dart';
import '../Streaks/Compact_freeze.dart';
import '../Streaks/Freeze_bottomsheet.dart';
import '../Streaks/Streaksbottomsheet.dart';
import '../main_section/settings/settings_bottomsheet_column.dart';
import 'widgets/chat_bottom_section.dart';
import 'widgets/live_stream_helper_widgets.dart';
import 'widgets/live_stream_embed_stack.dart';

class Livestreaming extends StatefulWidget {
  const Livestreaming({super.key});

  @override
  State<Livestreaming> createState() => _LivestreamingState();
}

class _LivestreamingState extends State<Livestreaming> {
  final ValueNotifier<bool> _showServiceCard = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _selectedPlatform = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _showActivity = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _titleSelected = ValueNotifier<bool>(false);

  final ValueNotifier<String> _topBarImage = ValueNotifier<String>(
    'assets/images/topbarshade.png',
  );

  final ValueNotifier<String?> _chatFilter = ValueNotifier<String?>(null);
  bool _streakCompletionChecked = false;
  bool _streakSheetOpening = false;

  // Resizable bottom section state
  double _bottomSectionHeight = 0;
  bool _activityPanelExpanded = false;
  double _activityLayoutMin = 0;
  double _activityLayoutMax = 0;
  double? _bottomSectionHeightBeforeActivityExpand;
  bool _isInitialHeightSet = false;
  static const double _dragSensitivity = 1.8;
  static const double _minBottomSectionHeightFactor = 0.20;
  static const double _minUpperSectionHeight = 50.0;
  final Map<String, double> _lastLayoutLogs = {};

  // ── Activity section state ──────────────────────────────────────────
  double _activityHeight = 0;
  bool _isDraggingActivity = false;
  static const double _activityMinHeight = 0.3;
  static const double _activityMaxHeight = 0.65;
  final ScrollController _activityScrollController = ScrollController();

  late final SettingsController _settingsCtrl;
  late final StreamStreaksController _streakCtrl;

  @override
  void initState() {
    super.initState();
    _settingsCtrl = Get.find<SettingsController>();
    _streakCtrl = Get.find<StreamStreaksController>();
    _chatFilter.addListener(_updateImageBasedOnFilter);
    _chatFilter.addListener(_syncSelectedPlatformFromFilter);
    _showActivity.addListener(_onShowActivityOpened);
    _maybeCompleteStreakForToday();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(Get.find<ChatController>().ensureStreamRealtimeBootstrap());
    });
  }

  void _onShowActivityOpened() {
    if (!_showActivity.value || !mounted) return;
    setState(() {
      _activityPanelExpanded = false;
      _activityHeight = 0;
      _bottomSectionHeightBeforeActivityExpand = null;
    });
  }

  void _syncSelectedPlatformFromFilter() {
    final chatCtrl = Get.find<ChatController>();
    final selected = _chatFilter.value ?? 'twitch';
    if (chatCtrl.platform.value.toLowerCase().trim() == selected) return;
    chatCtrl.selectPlatformInstant(selected);
  }

  void _updateImageBasedOnFilter() {
    switch (_chatFilter.value) {
      case 'twitch':
        _topBarImage.value = 'assets/images/twitchshade.png';
        break;
      case 'kick':
        _topBarImage.value = 'assets/images/youtubeshade.png';
        break;
      case 'youtube':
        _topBarImage.value = 'assets/images/kickshade.png';
        break;
      default:
        _topBarImage.value = 'assets/images/topbarshade.png';
        break;
    }
  }

  Future<void> _maybeCompleteStreakForToday() async {
    if (_streakCompletionChecked) return;
    _streakCompletionChecked = true;

    try {
      await _streakCtrl.markStreakComplete(
        date: DateTime.now(),
        showErrors: false,
      );
    } catch (e) {
      debugPrint('STREAK COMPLETE ERROR: $e');
    }
  }

  Future<void> _openStreakSheet() async {
    if (_streakSheetOpening) return;
    _streakSheetOpening = true;
    try {
      if (!mounted) return;
      await Get.bottomSheet(
        _LiveStreamStreakEntryBottomSheet(streakCtrl: _streakCtrl),
        isDismissible: true,
        isScrollControlled: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        enterBottomSheetDuration: const Duration(milliseconds: 120),
        exitBottomSheetDuration: const Duration(milliseconds: 120),
      );
    } finally {
      _streakSheetOpening = false;
      if (mounted) {
        unawaited(_streakCtrl.fetchCurrentStreak(force: true, silent: true));
      }
    }
  }

  @override
  void dispose() {
    _chatFilter.removeListener(_updateImageBasedOnFilter);
    _chatFilter.removeListener(_syncSelectedPlatformFromFilter);
    _showActivity.removeListener(_onShowActivityOpened);
    _showServiceCard.dispose();
    _selectedPlatform.dispose();
    _showActivity.dispose();
    _titleSelected.dispose();
    _topBarImage.dispose();
    _chatFilter.dispose();
    _activityScrollController.dispose();
    super.dispose();
  }

  void _collapseActivityExpandedIfNeeded(BuildContext context) {
    if (!_activityPanelExpanded) return;
    final screenHeight = Get.height;
    final minHeight = _bottomSectionMinHeight(screenHeight);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final maxBottom =
        screenHeight -
        _layoutTopPadding(context) -
        16.h -
        _minUpperSectionHeight -
        12.h -
        bottomInset;
    final clampedMaxBottom = maxBottom > minHeight ? maxBottom : minHeight;
    setState(() {
      final restored =
          (_bottomSectionHeightBeforeActivityExpand ?? clampedMaxBottom)
              .clamp(minHeight, clampedMaxBottom)
              .toDouble();
      _bottomSectionHeight = restored;
      _bottomSectionHeightBeforeActivityExpand = null;
      if (_activityLayoutMin > 0) {
        _activityHeight = _activityLayoutMin;
      }
      _activityPanelExpanded = false;
    });
  }

  void _handleFilterTap(String platformKey) {
    if (mounted) {
      _collapseActivityExpandedIfNeeded(context);
    }
    if (_chatFilter.value == platformKey) {
      _chatFilter.value = null;
    } else {
      _chatFilter.value = platformKey;
    }
  }

  void _handlePlatformSwipe(bool swipeRight) {
    if (mounted) {
      _collapseActivityExpandedIfNeeded(context);
    }
    const platforms = [null, 'twitch', 'kick', 'youtube'];
    final currentIndex = platforms.indexOf(_chatFilter.value);

    if (swipeRight) {
      final nextIndex = (currentIndex + 1) % platforms.length;
      _chatFilter.value = platforms[nextIndex];
    } else {
      final prevIndex =
          (currentIndex - 1 + platforms.length) % platforms.length;
      _chatFilter.value = platforms[prevIndex];
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[LiveStreamScreen] $message');
    }
  }

  void _logValueChange(String key, double value) {
    final prev = _lastLayoutLogs[key];
    if (prev == null || (prev - value).abs() > 0.5) {
      _lastLayoutLogs[key] = value;
      _log('$key=$value');
    }
  }

  String _formatViewerCount(int? count) {
    if (count == null) return '—';
    if (count < 1000) return '$count';
    if (count < 1000000) {
      final v = (count / 1000);
      final s = v.toStringAsFixed(v < 10 ? 1 : 0);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}K';
    }
    if (count < 1000000000) {
      final v = (count / 1000000);
      final s = v.toStringAsFixed(v < 10 ? 1 : 0);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}M';
    }
    final v = (count / 1000000000);
    final s = v.toStringAsFixed(v < 10 ? 1 : 0);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}B';
  }

  String _assetForPlatform(String platform) {
    switch (_normalizeUiPlatform(platform)) {
      case 'kick':
        return 'assets/images/kick.png';
      case 'youtube':
        return 'assets/images/youtube.png';
      case 'twitch':
      default:
        return 'assets/images/twitch.png';
    }
  }

  String _normalizeUiPlatform(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v.contains('kick')) return 'kick';
    if (v.contains('youtube') || v == 'yt' || v.contains('google')) {
      return 'youtube';
    }
    return 'twitch';
  }

  /// Primary line: `{username} joined|followed|unfollowed` when [type] matches; else fallback.
  (String primary, String secondary) _activityRowLines({
    required String user,
    required String typeRaw,
  }) {
    final type = typeRaw.toLowerCase().trim();
    final u = user.trim();
    if (type == 'join' || type == 'viewer_join' || type == 'viewer join') {
      return (u.isNotEmpty ? '$u joined' : 'Someone joined', '');
    }
    if (type == 'follow' || type == 'new_follower' || type == 'new follow') {
      return (u.isNotEmpty ? '$u followed' : 'Someone followed', '');
    }
    if (type == 'unfollow' ||
        type == 'unfollowed' ||
        type == 'follow_off' ||
        type == 'followoff') {
      return (u.isNotEmpty ? '$u unfollowed' : 'Someone unfollowed', '');
    }
    final primary = u.isNotEmpty ? u : (typeRaw.isNotEmpty ? typeRaw : 'Activity');
    final secondary =
        u.isNotEmpty && typeRaw.isNotEmpty && typeRaw.toLowerCase() != u.toLowerCase()
            ? typeRaw
            : '';
    return (primary, secondary);
  }

  String _formatActivityTime(dynamic tsRaw) {
    return formatAppClockTimeFromRaw(
      tsRaw,
      clockFormat: _settingsCtrl.clockFormat.value,
    );
  }

  double _bottomSectionMinHeight(double screenHeight) {
    final minByFactor = screenHeight * _minBottomSectionHeightFactor;

    // Keep collapsed size large enough for fixed header UI + counter row.
    final minByContent =
        (12.h + 59.4.h + 12.h) + // counter row wrapper in parent
        (10.h + 8.h + 4.h + 8.h + 16.h + 36.h + 16.h) + // chat header chrome
        8.h; // small safety buffer to avoid edge overflow on some devices

    return minByFactor > minByContent ? minByFactor : minByContent;
  }

  double _mainContentTopOffset(BuildContext context) {
    final safeTop = MediaQuery.of(context).viewPadding.top;
    final dynamicOffset =
        safeTop +
        28.h + // top padding used by top icon row
        36.w + // icon row visual height
        12.h; // spacing below row
    final legacyOffset = 117.h;
    return dynamicOffset > legacyOffset ? dynamicOffset : legacyOffset;
  }

  double _layoutTopPadding(BuildContext context) {
    return _mainContentTopOffset(context) + 5.h;
  }

  void _toggleActivityPanelExpand(BuildContext context) {
    final screenHeight = Get.height;
    final minHeight = _bottomSectionMinHeight(screenHeight);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final maxBottom =
        screenHeight -
        _layoutTopPadding(context) -
        16.h -
        _minUpperSectionHeight -
        12.h -
        bottomInset;
    final clampedMaxBottom = maxBottom > minHeight ? maxBottom : minHeight;

    setState(() {
      final nextExpanded = !_activityPanelExpanded;
      if (nextExpanded) {
        _bottomSectionHeightBeforeActivityExpand ??=
            _bottomSectionHeight.clamp(minHeight, clampedMaxBottom).toDouble();
        _bottomSectionHeight = minHeight;
        if (_activityLayoutMax > 0) {
          _activityHeight = _activityLayoutMax;
        }
      } else {
        final restored =
            (_bottomSectionHeightBeforeActivityExpand ?? clampedMaxBottom)
                .clamp(minHeight, clampedMaxBottom)
                .toDouble();
        _bottomSectionHeight = restored;
        _bottomSectionHeightBeforeActivityExpand = null;
        if (_activityLayoutMin > 0) {
          _activityHeight = _activityLayoutMin;
        }
      }
      _activityPanelExpanded = nextExpanded;
    });
  }

  Widget _buildInteractiveCounterRow() {
    return Obx(() {
      final chatCtrl = Get.find<ChatController>();
      final showViewerCounts = _settingsCtrl.viewerCount.value;
      final twitchViews = chatCtrl.platformViewerCounts['twitch'];
      final kickViews = chatCtrl.platformViewerCounts['kick'];
      final youtubeViews = chatCtrl.platformViewerCounts['youtube'];

      return Container(
        width: 297.w,
        height: 59.4.h,
        decoration: BoxDecoration(
          color: black,
          borderRadius: BorderRadius.circular(33.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _handleFilterTap('twitch'),
              child: Obx(() {
                final color = _settingsCtrl.getPlatformColor('twitch');
                return counterPill(
                  asset: 'assets/images/twitch.png',
                  count: showViewerCounts
                      ? _formatViewerCount(twitchViews)
                      : '-',
                  color: color,
                  bgColor: color.withOpacity(0.25),
                );
              }),
            ),
            SizedBox(width: 13.2.w),
            GestureDetector(
              onTap: () => _handleFilterTap('kick'),
              child: Obx(() {
                final color = _settingsCtrl.getPlatformColor('kick');
                return counterPill(
                  asset: 'assets/images/kick.png',
                  count: showViewerCounts
                      ? _formatViewerCount(kickViews)
                      : '-',
                  color: color,
                  bgColor: color.withOpacity(0.25),
                );
              }),
            ),
            SizedBox(width: 13.2.w),
            GestureDetector(
              onTap: () => _handleFilterTap('youtube'),
              child: Obx(() {
                final color = _settingsCtrl.getPlatformColor('youtube');
                return counterPill(
                  asset: 'assets/images/youtube.png',
                  count: showViewerCounts
                      ? _formatViewerCount(youtubeViews)
                      : '-',
                  color: color,
                  bgColor: color.withOpacity(0.25),
                );
              }),
            ),
          ],
        ),
      );
    });
  }

  // ── Resizable activity container ────────────────────────────────────
  static const double _activityDragSensitivity = 1.5;

  Widget _buildResizableActivityContainer(
    BuildContext context,
    double availableHeight,
  ) {
    final double screenHeight = Get.height;
    final double minHeightFromScreen = screenHeight * _activityMinHeight;
    final double maxHeightFromScreen = screenHeight * _activityMaxHeight;
    final double slotCap =
        (availableHeight > 0 ? availableHeight : maxHeightFromScreen)
            .toDouble();
    // Fill the upper stream slot when expanded (no artificial shrink).
    final double maxHeight = math.max(minHeightFromScreen, slotCap);
    final double originalHeight =
        minHeightFromScreen.clamp(0, maxHeight).toDouble();

    if (_activityHeight == 0) {
      _activityHeight =
          _activityPanelExpanded ? maxHeight : originalHeight;
    }

    final double clampedHeight = _activityHeight.clamp(
      originalHeight,
      maxHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentMax =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : slotCap;
        final effectiveMax =
            math.min(parentMax, maxHeight).clamp(0.0, double.infinity).toDouble();
        final effectiveMin = originalHeight.clamp(0, effectiveMax).toDouble();
        _activityLayoutMin = effectiveMin;
        _activityLayoutMax = effectiveMax;

        final double height;
        if (_isDraggingActivity) {
          height = clampedHeight.clamp(effectiveMin, effectiveMax).toDouble();
        } else if (_activityPanelExpanded) {
          height = effectiveMax;
        } else {
          height = _activityHeight.clamp(effectiveMin, effectiveMax).toDouble();
        }
        final activityPanel = AnimatedContainer(
          duration: Duration(milliseconds: _isDraggingActivity ? 0 : 250),
          curve: Curves.easeOut,
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(22, 21, 24, 1),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10.h,
                left: 12.w,
                child: Text(
                  context.l10n.activity,
                  style: sfProText600(13.sp, Colors.white),
                ),
              ),
              // ─── Scrollable activity rows ───────────────────────
              Positioned.fill(
                child: ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thumbColor: MaterialStateProperty.all(
                      Colors.grey.shade500,
                    ),
                  ),
                  child: Scrollbar(
                    controller: _activityScrollController,
                    thumbVisibility: true,
                    thickness: 3.w,
                    radius: Radius.circular(8.r),
                    scrollbarOrientation: ScrollbarOrientation.right,
                    child: SingleChildScrollView(
                      controller: _activityScrollController,
                      padding: EdgeInsets.only(
                        left: 12.w,
                        right: 12.w,
                        top: 22.h,
                        bottom: 28.h,
                      ),
                      physics:
                          _isDraggingActivity
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                      child: Obx(() {
                        final chatCtrl = Get.find<ChatController>();
                        chatCtrl.platform.value;
                        _settingsCtrl.clockFormat.value;
                        final selected =
                            _normalizeUiPlatform(chatCtrl.platform.value);
                        // Prefer controller activity list (wired to sockets).
                        // Chat "normal" lines stay in chat; activity = everything else.
                        final events = chatCtrl.activityEvents
                            .where((e) {
                              final t = (e['type'] ?? e['eventType'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              return t != 'normal';
                            })
                            .where((e) {
                              final raw =
                                  (e['platform'] ?? '').toString().trim();
                              if (raw.isEmpty) return true;
                              return _normalizeUiPlatform(raw) == selected;
                            })
                            .toList(growable: false);
                        if (events.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 24.h),
                              child: Text(
                                context.l10n.noActivityYet,
                                textAlign: TextAlign.center,
                                style: sfProText400(
                                  13.sp,
                                  Colors.white54,
                                ),
                              ),
                            ),
                          );
                        }
                        // Render newest first.
                        final list = events.reversed.toList(growable: false);
                        return RepaintBoundary(
                          child: Column(
                            key: ValueKey<String>('activity_$selected'),
                            children: [
                              for (var i = 0; i < list.length; i++) ...[
                                Builder(
                                  builder: (ctx) {
                                    final e = list[i];
                                    final platform =
                                        (e['platform'] ?? '').toString();
                                    final meta = e['metadata'];
                                    final metaMap = meta is Map
                                        ? meta.cast<String, dynamic>()
                                        : const <String, dynamic>{};
                                    final user = (metaMap['user'] ??
                                            metaMap['username'] ??
                                            metaMap['user_name'] ??
                                            metaMap['user_login'] ??
                                            metaMap['name'] ??
                                            e['username'] ??
                                            '')
                                        .toString()
                                        .trim();
                                    final type =
                                        (e['type'] ?? e['eventType'] ?? '')
                                            .toString()
                                            .trim();
                                    final time = _formatActivityTime(
                                      e['timestamp'] ?? e['created_at'],
                                    );
                                    final lines = _activityRowLines(
                                      user: user,
                                      typeRaw: type,
                                    );
                                    final pKey = _normalizeUiPlatform(
                                      platform.isNotEmpty
                                          ? platform
                                          : selected,
                                    );
                                    return activityRow(
                                      _assetForPlatform(pKey),
                                      pKey,
                                      lines.$1,
                                      time,
                                      lines.$2,
                                    );
                                  },
                                ),
                                if (i != list.length - 1)
                                  SizedBox(height: 12.h),
                              ],
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12.w,
                bottom: 10.h,
                child: GestureDetector(
                  onTap: () => _toggleActivityPanelExpand(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(38, 37, 41, 1),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white12, width: 1.w),
                    ),
                    child: Text(
                      _activityPanelExpanded
                          ? context.l10n.seeLess
                          : context.l10n.seeMore,
                      style: sfProText400(11.sp, Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        // Expanded: no parent vertical-drag — avoids collapsing when scrolling /
        // tapping the list. Collapse only via See less (or filter / other controls).
        if (_activityPanelExpanded) {
          return activityPanel;
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (_) {
            setState(() {
              _isDraggingActivity = true;
              final startH =
                  _activityHeight.clamp(effectiveMin, effectiveMax);
              _activityHeight = startH;
            });
          },
          onVerticalDragUpdate: (details) {
            final delta = details.delta.dy * _activityDragSensitivity;
            if (delta < 0 && _activityHeight <= effectiveMin) {
              return;
            }
            setState(() {
              _activityHeight = (_activityHeight + delta).clamp(
                effectiveMin,
                effectiveMax,
              );
            });
          },
          onVerticalDragEnd: (_) {
            setState(() {
              _isDraggingActivity = false;
            });
          },
          onVerticalDragCancel: () {
            setState(() {
              _isDraggingActivity = false;
            });
          },
          child: activityPanel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Stack(
            children: [
              // ── Top bar shade image ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 230.h,
                child: ClipRect(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _topBarImage,
                    builder: (context, imagePath, child) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: _chatFilter,
                        builder: (context, filter, _) {
                          if (filter == null) {
                            return Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              key: ValueKey(imagePath),
                            );
                          }

                          return Obx(() {
                            Color filterColor;
                            if (filter == 'twitch') {
                              filterColor =
                                  _settingsCtrl.twitchColor.value ??
                                  twitchPurple;
                            } else if (filter == 'kick') {
                              filterColor =
                                  _settingsCtrl.kickColor.value ?? kickGreen;
                            } else if (filter == 'youtube') {
                              filterColor =
                                  _settingsCtrl.youtubeColor.value ??
                                  youtubeRed;
                            } else {
                              filterColor = Colors.transparent;
                            }

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  key: ValueKey(imagePath),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        filterColor.withOpacity(0.8),
                                        filterColor.withOpacity(0.0),
                                      ],
                                      stops: const [0.0, 1.0],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          });
                        },
                      );
                    },
                  ),
                ),
              ),

              // ── Full-screen gradient overlay ──
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x661A1A1A), Color(0xFF0A0A0A)],
                    ),
                  ),
                ),
              ),

              // ── Top bar buttons ──
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 28.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Obx(() {
                        final streakTotal =
                            _streakCtrl.current.value?.headerStreakTotal ?? 0;
                        return StreakButton(
                          count: streakTotal,
                          onTap: _openStreakSheet,
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                        );
                      }),
                      Row(
                        children: [
                          // SizedBox(width: 6.w),
                          // GestureDetector(
                          //   onTap: () {
                          //     Get.to(() => const SocketLogScreen());
                          //   },
                          //   child: Container(
                          //     width: 36.w,
                          //     height: 36.w,
                          //     alignment: Alignment.center,
                          //     decoration: BoxDecoration(
                          //       color: const Color(0xFF2C2C2E),
                          //       borderRadius: BorderRadius.circular(10.r),
                          //     ),
                          //     child: Icon(
                          //       Icons.terminal_rounded,
                          //       size: 20.sp,
                          //       color: Colors.white70,
                          //     ),
                          //   ),
                          // ),
                          // SizedBox(width: 6.w),
                          GestureDetector(
                            onTap: () {
                              Get.bottomSheet(
                                Container(
                                  height: Get.height * .9,
                                  decoration: BoxDecoration(
                                    color: bottomSheetGrey,
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(18.r),
                                      topLeft: Radius.circular(18.r),
                                    ),
                                  ),
                                  child: InviteBottomSheet(),
                                ),
                                isDismissible: true,
                                isScrollControlled: true,
                                enableDrag: true,
                                enterBottomSheetDuration: const Duration(
                                  milliseconds: 300,
                                ),
                                exitBottomSheetDuration: const Duration(
                                  milliseconds: 250,
                                ),
                              );
                            },
                            child: buildImageButton(
                              'assets/images/gift.png',
                              width: 36.w,
                              height: 36.w,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          GestureDetector(
                            onTap: () {
                              Get.bottomSheet(
                                Container(
                                  height: Get.height * .9,
                                  decoration: BoxDecoration(
                                    color: bottomSheetGrey,
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(18.r),
                                      topLeft: Radius.circular(18.r),
                                    ),
                                  ),
                                  child: SettingsBottomsheetColumn(),
                                ),
                                isDismissible: true,
                                isScrollControlled: true,
                                enableDrag: true,
                                enterBottomSheetDuration: const Duration(
                                  milliseconds: 300,
                                ),
                                exitBottomSheetDuration: const Duration(
                                  milliseconds: 250,
                                ),
                              );
                            },
                            child: buildImageButton(
                              'assets/images/settings.png',
                              width: 36.w,
                              height: 36.w,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Main content area ──
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final layoutTopPadding = _layoutTopPadding(context);
                      final mainContentTopOffset = _mainContentTopOffset(
                        context,
                      );
                      if (!_isInitialHeightSet) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            final screenHeight = Get.height;
                            final topPadding = layoutTopPadding;
                            final spacing = 12.h;
                            final bottomPadding =
                                16.h +
                                MediaQuery.of(context).viewPadding.bottom;
                            final minHeight = _bottomSectionMinHeight(
                              screenHeight,
                            );
                            final maxHeight =
                                screenHeight -
                                topPadding -
                                spacing -
                                _minUpperSectionHeight -
                                bottomPadding;
                            final safeMaxHeight =
                                maxHeight > minHeight ? maxHeight : minHeight;
                            final upperSectionHeight = 236.h + spacing;
                            final counterRowHeight = 59.4.h + 24.h;
                            final availableHeight =
                                screenHeight - topPadding - bottomPadding;
                            final calculatedHeight =
                                availableHeight -
                                upperSectionHeight -
                                spacing -
                                counterRowHeight;
                            final initialBottomHeight = calculatedHeight * 1.4;
                            final legacyInitialHeight =
                                initialBottomHeight > 200.h
                                    ? initialBottomHeight
                                    : 200.h;
                            setState(() {
                              _bottomSectionHeight =
                                  legacyInitialHeight
                                      .clamp(minHeight, safeMaxHeight)
                                      .toDouble();
                              _isInitialHeightSet = true;
                            });
                          }
                        });
                      }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          SizedBox(height: mainContentTopOffset),

                          // ── Upper section ──
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, upperConstraints) {
                                final upperSectionHeight =
                                    upperConstraints.maxHeight.isFinite &&
                                            upperConstraints.maxHeight > 0
                                        ? upperConstraints.maxHeight
                                        : 226.h;
                                final streamPreviewHeight =
                                    upperSectionHeight.toDouble();

                                return ValueListenableBuilder<bool>(
                                  valueListenable: _showActivity,
                                  builder: (context, showActivity, _) {
                                    return SizedBox(
                                      height: upperSectionHeight,
                                      width: double.infinity,
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          IgnorePointer(
                                            ignoring: showActivity,
                                            child: SingleChildScrollView(
                                              physics:
                                                  _isDraggingActivity
                                                      ? const NeverScrollableScrollPhysics()
                                                      : const ClampingScrollPhysics(),
                                              padding: EdgeInsets.only(
                                                bottom:
                                                    MediaQuery.of(
                                                      context,
                                                    ).viewPadding.bottom,
                                              ),
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  minHeight: upperSectionHeight,
                                                ),
                                                child: ValueListenableBuilder<bool>(
                                                  valueListenable: _showServiceCard,
                                                  builder: (context, showCard, child) {
                                            final chatCtrl =
                                                Get.find<ChatController>();
                                            final settingsCtrl =
                                                Get.find<SettingsController>();

                                            final webView = SizedBox(
                                              height: streamPreviewHeight,
                                              child: Obx(() {
                                                final multi =
                                                    settingsCtrl
                                                        .multiScreenPreview
                                                        .value ==
                                                    true;
                                                return Container(
                                                  width:
                                                      MediaQuery.of(
                                                        context,
                                                      ).size.width,
                                                  margin: EdgeInsets.symmetric(
                                                    horizontal: 5.w,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24.r,
                                                        ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24.r,
                                                        ),
                                                    child: Padding(
                                                      padding: EdgeInsets.all(
                                                        multi ? 8.w : 0,
                                                      ),
                                                      child: multi
                                                          ? LiveStreamMultiEmbedGrid(
                                                              streamPreviewHeight:
                                                                  streamPreviewHeight,
                                                            )
                                                          : LiveStreamSingleEmbedStack(
                                                              streamPreviewHeight:
                                                                  streamPreviewHeight,
                                                            ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            );

                                            return SizedBox(
                                              height: streamPreviewHeight,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                clipBehavior: Clip.hardEdge,
                                                children: [
                                                  Offstage(
                                                    offstage: showCard,
                                                    child: webView,
                                                  ),
                                                  if (showCard)
                                                    Positioned.fill(
                                                      child: ValueListenableBuilder<bool>(
                                                        valueListenable:
                                                            _titleSelected,
                                                        builder: (
                                                          context,
                                                          titleSelected,
                                                          _,
                                                        ) {
                                                          if (titleSelected) {
                                                            return ValueListenableBuilder<
                                                              String?
                                                            >(
                                                              valueListenable:
                                                                  _selectedPlatform,
                                                              builder: (
                                                                context,
                                                                platform,
                                                                _,
                                                              ) {
                                                                if (platform !=
                                                                    null) {
                                                                  final activePlatform =
                                                                      _normalizeUiPlatform(
                                                                        platform,
                                                                      );
                                                                  return Column(
                                                                    children: [
                                                                      Expanded(
                                                                        child: Container(
                                                                          width: double.infinity,
                                                                          padding: EdgeInsets.symmetric(
                                                                            horizontal: 12.w,
                                                                            vertical: 12.h,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color: black,
                                                                            borderRadius:
                                                                                BorderRadius.circular(
                                                                              20.r,
                                                                            ),
                                                                          ),
                                                                          child: Column(
                                                                        children: [
                                                                          Padding(
                                                                            padding: EdgeInsets.symmetric(
                                                                              horizontal:
                                                                                  8.w,
                                                                            ),
                                                                            child: Row(
                                                                              children: [
                                                                                GestureDetector(
                                                                                  onTap: () {
                                                                                    _collapseActivityExpandedIfNeeded(context);
                                                                                    _selectedPlatform.value = null;
                                                                                    _showServiceCard.value = false;
                                                                                    _titleSelected.value = false;
                                                                                    _showActivity.value = false;
                                                                                    _activityHeight =
                                                                                        0;
                                                                                    _isDraggingActivity =
                                                                                        false;
                                                                                  },
                                                                                  child: Container(
                                                                                    padding: EdgeInsets.all(
                                                                                      8.w,
                                                                                    ),
                                                                                    decoration: BoxDecoration(
                                                                                      color:
                                                                                          Colors.grey.shade900,
                                                                                      shape:
                                                                                          BoxShape.circle,
                                                                                    ),
                                                                                    child: Transform.translate(
                                                                                      offset: const Offset(
                                                                                        2,
                                                                                        0,
                                                                                      ),
                                                                                      child: Icon(
                                                                                        Icons.arrow_back_ios,
                                                                                        color:
                                                                                            Colors.white,
                                                                                        size:
                                                                                            16.sp,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                const Spacer(),
                                                                                ValueListenableBuilder<String?>(
                                                                                  valueListenable: _chatFilter,
                                                                                  builder: (
                                                                                    context,
                                                                                    chatFilterSnap,
                                                                                    _,
                                                                                  ) {
                                                                                    return Obx(() {
                                                                                      final liveP =
                                                                                          chatCtrl
                                                                                              .platform
                                                                                              .value
                                                                                              .toString()
                                                                                              .trim();
                                                                                      final raw =
                                                                                          (chatFilterSnap !=
                                                                                                      null &&
                                                                                                  chatFilterSnap
                                                                                                      .trim()
                                                                                                      .isNotEmpty)
                                                                                              ? chatFilterSnap
                                                                                              : (liveP.isNotEmpty
                                                                                                    ? liveP
                                                                                                    : activePlatform);
                                                                                      final displayKey =
                                                                                          _normalizeUiPlatform(
                                                                                        raw,
                                                                                      );
                                                                                      final iconAsset =
                                                                                          _assetForPlatform(
                                                                                        displayKey,
                                                                                      );
                                                                                      final iconColor =
                                                                                          _settingsCtrl
                                                                                              .getPlatformColor(
                                                                                        displayKey,
                                                                                      );
                                                                                      return Center(
                                                                                        child: Image.asset(
                                                                                          iconAsset,
                                                                                          color: iconColor,
                                                                                          width: 22.w,
                                                                                          height: 22.h,
                                                                                        ),
                                                                                      );
                                                                                    });
                                                                                  },
                                                                                ),
                                                                                const Spacer(),
                                                                                SizedBox(
                                                                                  width:
                                                                                      40.w,
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            height:
                                                                                16.h,
                                                                          ),
                                                                          ValueListenableBuilder<String?>(
                                                                            valueListenable: _chatFilter,
                                                                            builder:
                                                                                (
                                                                                  context,
                                                                                  chatFilter,
                                                                                  _,
                                                                                ) {
                                                                              return Obx(() {
                                                                                final metaKey =
                                                                                    _normalizeUiPlatform(
                                                                                      chatFilter ??
                                                                                          activePlatform,
                                                                                    )
                                                                                        .toString()
                                                                                        .trim();
                                                                                final titleLive =
                                                                                    (chatCtrl.streamTitleByPlatform[metaKey] ?? '')
                                                                                        .trim();
                                                                                final categoryLive =
                                                                                    (chatCtrl.streamCategoryByPlatform[metaKey] ?? '')
                                                                                        .trim();
                                                                                final titlePanel =
                                                                                    titleLive.isNotEmpty
                                                                                        ? titleLive
                                                                                        : context.l10n.streamMetaEmpty;
                                                                                final categoryPanel =
                                                                                    categoryLive.isNotEmpty
                                                                                        ? categoryLive
                                                                                        : context.l10n.streamMetaEmpty;
                                                                                return Column(
                                                                                  mainAxisSize:
                                                                                      MainAxisSize.min,
                                                                                  children: [
                                                                                    panelRow(titlePanel),
                                                                                    SizedBox(height: 12.h),
                                                                                    // Category row: no chevron / picker (disabled).
                                                                                    panelRow(
                                                                                      categoryPanel,
                                                                                      showChevron: false,
                                                                                      onTap: null,
                                                                                    ),
                                                                                  ],
                                                                                );
                                                                              });
                                                                            },
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              );
                                                          }

                                                          return Column(
                                                              children: [
                                                                Expanded(
                                                                  child: Center(
                                                                    child: Container(
                                                                      width:
                                                                          double.infinity,
                                                                      padding: EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            14.w,
                                                                        vertical:
                                                                            14.h,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color:
                                                                            black,
                                                                        borderRadius: BorderRadius.circular(
                                                                          20.r,
                                                                        ),
                                                                      ),
                                                                      child: Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.center,
                                                                        children: [
                                                                          Obx(() {
                                                                            final currentPlatform =
                                                                                _normalizeUiPlatform(
                                                                                  _chatFilter
                                                                                      .value ??
                                                                                      chatCtrl
                                                                                          .platform
                                                                                          .value,
                                                                                );
                                                                            return serviceRow(
                                                                              asset: _assetForPlatform(
                                                                                currentPlatform,
                                                                              ),
                                                                              iconColor: _settingsCtrl
                                                                                  .getPlatformColor(
                                                                                    currentPlatform,
                                                                                  ),
                                                                              title:
                                                                                  context.l10n.title,
                                                                              subtitle:
                                                                                  context.l10n.category,
                                                                              onTap: () {
                                                                                _collapseActivityExpandedIfNeeded(context);
                                                                                _selectedPlatform.value =
                                                                                    currentPlatform;
                                                                                _titleSelected.value = true;
                                                                                _showServiceCard.value = true;
                                                                              },
                                                                            );
                                                                          }),
                                                                          SizedBox(
                                                                            height:
                                                                                36.h,
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            );
                                                        },
                                                      );
                                                    }

                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                                          if (showActivity)
                                            Positioned.fill(
                                              child: _buildResizableActivityContainer(
                                                context,
                                                upperSectionHeight,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 12.h),
                          _buildResizableBottomSection(context, constraints),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResizableBottomSection(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    _logValueChange('layout.bottomInset', bottomInset);
    _logValueChange('layout.keyboardInset', keyboardInset);

    if (!_isInitialHeightSet) {
      return SizedBox(
        height: 200.h,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2.h, bottom: 12.h),
              child: _buildInteractiveCounterRow(),
            ),
            Expanded(
              child: ChatBottomSection(
                showServiceCard: _showServiceCard,
                showActivity: _showActivity,
                selectedPlatform: _selectedPlatform,
                titleSelected: _titleSelected,
                chatFilter: _chatFilter,
                onPlatformSwipe: _handlePlatformSwipe,
                onOverlayViewChange:
                    () => _collapseActivityExpandedIfNeeded(context),
              ),
            ),
          ],
        ),
      );
    }

    final screenHeight = Get.height;
    const double bottomGap = 16;
    final minHeight = _bottomSectionMinHeight(screenHeight);
    final maxHeight =
        screenHeight -
        _layoutTopPadding(context) -
        _minUpperSectionHeight -
        bottomGap.h -
        12.h -
        bottomInset;
    final clampedMaxHeight = maxHeight > minHeight ? maxHeight : minHeight;

    final currentHeight =
        _bottomSectionHeight.clamp(minHeight, clampedMaxHeight).toDouble();
    _logValueChange('layout.currentHeight', currentHeight);

    return SizedBox(
      height: currentHeight,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
            child: _buildInteractiveCounterRow(),
          ),
          Expanded(
            child: ChatBottomSection(
              showServiceCard: _showServiceCard,
              showActivity: _showActivity,
              selectedPlatform: _selectedPlatform,
              titleSelected: _titleSelected,
              chatFilter: _chatFilter,
              onOverlayViewChange:
                  () => _collapseActivityExpandedIfNeeded(context),
              onResize: (delta) {
                final adjustedDelta = delta * _dragSensitivity;
                setState(() {
                  _bottomSectionHeight =
                      (_bottomSectionHeight - adjustedDelta)
                          .clamp(minHeight, clampedMaxHeight)
                          .toDouble();
                });
              },
              onResizeEnd: () {
                setState(() {
                  _bottomSectionHeight =
                      _bottomSectionHeight
                          .clamp(minHeight, clampedMaxHeight)
                          .toDouble();
                });
              },
              onPlatformSwipe: _handlePlatformSwipe,
            ),
          ),
        ],
      ),
    );
  }
}

enum _StreakEntryView { loading, setup, danger, normal }

class _LiveStreamStreakEntryBottomSheet extends StatefulWidget {
  const _LiveStreamStreakEntryBottomSheet({required this.streakCtrl});

  final StreamStreaksController streakCtrl;

  @override
  State<_LiveStreamStreakEntryBottomSheet> createState() =>
      _LiveStreamStreakEntryBottomSheetState();
}

class _LiveStreamStreakEntryBottomSheetState
    extends State<_LiveStreamStreakEntryBottomSheet> {
  _StreakEntryView _view = _StreakEntryView.loading;

  @override
  void initState() {
    super.initState();
    _resolveSheetView();
  }

  Future<void> _resolveSheetView() async {
    final hasSession = await widget.streakCtrl.ensureSession(showErrors: true);
    if (!mounted) return;
    if (!hasSession) {
      if (Get.isBottomSheetOpen ?? false) {
        Get.back();
      }
      return;
    }

    final streak = await widget.streakCtrl.fetchCurrentStreak(
      force: true,
      silent: false,
    );
    if (!mounted) return;

    final hasCreatedStreak = streak?.hasCreatedStreak ?? false;
    final isInDanger = streak?.isInDanger == true;
    setState(() {
      if (!hasCreatedStreak) {
        _view = _StreakEntryView.setup;
      } else {
        _view = isInDanger ? _StreakEntryView.danger : _StreakEntryView.normal;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _StreakEntryView.setup:
        return const StreamStreakSetupBottomSheet();
      case _StreakEntryView.danger:
        return const StreakFreezePreviewBottomSheet(fetchOnInit: false);
      case _StreakEntryView.normal:
        return const StreakFreezeSingleRowPreviewBottomSheet(fetchOnInit: false);
      case _StreakEntryView.loading:
        return Container(
          height: Get.height * 0.9,
          decoration: BoxDecoration(
            color: bottomSheetGrey,
            borderRadius: BorderRadius.vertical(top: Radius.circular(38.r)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 2.8,
                  color: Colors.white,
                ),
                SizedBox(height: 12.h),
                Text(
                  'Loading streak...',
                  style: sfProText600(
                    15.sp,
                    const Color.fromRGBO(235, 235, 245, 0.85),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
