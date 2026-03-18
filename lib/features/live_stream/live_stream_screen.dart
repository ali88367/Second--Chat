import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/themes/textstyles.dart';
import '../../../controllers/Main Section Controllers/settings_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../core/constants/app_colors/app_colors.dart';
import '../../core/localization/l10n.dart';
import '../Invite/Invite_screen.dart';
import '../Streaks/Freeze_bottomsheet.dart';
import '../main_section/settings/settings_bottomsheet_column.dart';
import 'widgets/chat_bottom_section.dart';
import 'widgets/live_stream_helper_widgets.dart';
import 'widgets/stream_webview.dart';

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
  final GlobalKey _streamWebViewKey = GlobalKey(
    debugLabel: 'Livestreaming.streamWebView',
  );

  final ValueNotifier<String> _topBarImage = ValueNotifier<String>(
    'assets/images/topbarshade.png',
  );

  final ValueNotifier<String?> _chatFilter = ValueNotifier<String?>(null);
  bool _streakCompletionChecked = false;

  // Resizable bottom section state
  double _bottomSectionHeight = 0;
  double? _bottomSectionHeightBeforeActivityMore;
  bool _isActivitySeeMoreActive = false;
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

  @override
  void initState() {
    super.initState();
    _settingsCtrl = Get.find<SettingsController>();
    _chatFilter.addListener(_updateImageBasedOnFilter);
    _maybeCompleteStreakForToday();
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

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _weekdayKey(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  List<String> _extractSelectedDays(dynamic payload) {
    dynamic data = payload;
    if (data is Map && data['data'] != null) {
      data = data['data'];
    }
    if (data is Map) {
      final raw = data['selectedDays'];
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim().toLowerCase())
            .map((e) => e == 'thur' ? 'thu' : e)
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  Future<void> _maybeCompleteStreakForToday() async {
    if (_streakCompletionChecked) return;
    _streakCompletionChecked = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _dateKey(DateTime.now());
      const prefKey = 'second_chat.streak_complete_date';
      if (prefs.getString(prefKey) == todayKey) return;

      final auth = Get.find<AuthController>();
      final tokens = await auth.api.tokenStore.read();
      final accessToken = tokens?.accessToken?.trim();
      if (accessToken == null || accessToken.isEmpty) return;

      final res = await auth.api.client.dio.get<dynamic>(
        '/api/v1/streak',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      final selectedDays = _extractSelectedDays(res.data);
      final todayDay = _weekdayKey(DateTime.now());
      if (!selectedDays.contains(todayDay)) return;

      await auth.api.client.dio.post<dynamic>(
        '/api/v1/streak/complete',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      await prefs.setString(prefKey, todayKey);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        return;
      }
      if (status == 409 || status == 400) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'second_chat.streak_complete_date',
          _dateKey(DateTime.now()),
        );
      } else {
        debugPrint('STREAK COMPLETE ERROR: ${e.response?.data ?? e.message}');
      }
    } catch (e) {
      debugPrint('STREAK COMPLETE ERROR: $e');
    }
  }

  @override
  void dispose() {
    _chatFilter.removeListener(_updateImageBasedOnFilter);
    _showServiceCard.dispose();
    _selectedPlatform.dispose();
    _showActivity.dispose();
    _titleSelected.dispose();
    _topBarImage.dispose();
    _chatFilter.dispose();
    _activityScrollController.dispose();
    super.dispose();
  }

  void _handleFilterTap(String platformKey) {
    if (_chatFilter.value == platformKey) {
      _chatFilter.value = null;
    } else {
      _chatFilter.value = platformKey;
    }
    // Refresh overview for the selected platform so stream/embed updates.
    final chatCtrl = Get.find<ChatController>();
    final selected = _chatFilter.value ?? 'twitch';
    chatCtrl.refreshOverviewForPlatform(selected);
  }

  void _handlePlatformSwipe(bool swipeRight) {
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
    final chatCtrl = Get.find<ChatController>();
    final selected = _chatFilter.value ?? 'twitch';
    chatCtrl.refreshOverviewForPlatform(selected);
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

  void _toggleChatSheetForActivity(BuildContext context) {
    final screenHeight = Get.height;
    final minHeight = _bottomSectionMinHeight(screenHeight);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    const double bottomGap = 16;
    final maxHeight =
        screenHeight -
        _layoutTopPadding(context) -
        bottomGap.h -
        _minUpperSectionHeight -
        12.h -
        bottomInset;
    final clampedMaxHeight = maxHeight > minHeight ? maxHeight : minHeight;

    setState(() {
      if (!_isActivitySeeMoreActive) {
        _bottomSectionHeightBeforeActivityMore =
            _bottomSectionHeight.clamp(minHeight, clampedMaxHeight).toDouble();
        _bottomSectionHeight = minHeight;
        _isActivitySeeMoreActive = true;
      } else {
        final restoredHeight =
            (_bottomSectionHeightBeforeActivityMore ?? clampedMaxHeight)
                .clamp(minHeight, clampedMaxHeight)
                .toDouble();
        _bottomSectionHeight = restoredHeight;
        _isActivitySeeMoreActive = false;
      }
    });
  }

  Widget _buildInteractiveCounterRow() {
    return Obx(() {
      if (!_settingsCtrl.viewerCount.value) {
        return const SizedBox.shrink();
      }

      final chatCtrl = Get.find<ChatController>();
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
                  count: _formatViewerCount(twitchViews),
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
                  count: _formatViewerCount(kickViews),
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
                  count: _formatViewerCount(youtubeViews),
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
    final double maxHeight =
        (availableHeight > 0 ? availableHeight : maxHeightFromScreen)
            .toDouble();
    final double originalHeight =
        minHeightFromScreen.clamp(0, maxHeight).toDouble();

    if (_activityHeight == 0) {
      _activityHeight = maxHeight;
    }

    final double clampedHeight = _activityHeight.clamp(
      originalHeight,
      maxHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveMax =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight.clamp(0, maxHeight).toDouble()
                : maxHeight;
        final effectiveMin = originalHeight.clamp(0, effectiveMax).toDouble();
        // Keep activity filling the free space above the bottom sheet by default.
        final height =
            (_isDraggingActivity ? clampedHeight : effectiveMax)
                .clamp(effectiveMin, effectiveMax)
                .toDouble();
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (_) {
            setState(() {
              _isDraggingActivity = true;
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
          child: AnimatedContainer(
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
                          top: 34.h,
                          bottom: 42.h,
                        ),
                        physics:
                            _isDraggingActivity
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            activityRow(
                              'assets/images/kick.png',
                              context.l10n.newFollower,
                              '19:41',
                              '',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/kick.png',
                              context.l10n.newFollower,
                              '22:41',
                              '',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/kick.png',
                              context.l10n.megaSupporter,
                              '19:49',
                              '\$50',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/youtube1.png',
                              'Fun',
                              '19:49',
                              context.l10n.subscribed,
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/youtube1.png',
                              'Fun',
                              '19:49',
                              context.l10n.subscribed,
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/twitch1.png',
                              'Ranen',
                              '19:49',
                              context.l10n.subscribed,
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/kick.png',
                              context.l10n.newFollower,
                              '20:15',
                              '',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/twitch1.png',
                              context.l10n.superFan,
                              '20:30',
                              '\$100',
                            ),
                            SizedBox(height: 12.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12.w,
                  bottom: 10.h,
                  child: GestureDetector(
                    onTap: () => _toggleChatSheetForActivity(context),
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
                        _isActivitySeeMoreActive
                            ? context.l10n.seeLess
                            : context.l10n.seeMore,
                        style: sfProText400(11.sp, Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                      GestureDetector(
                        onTap: () {
                          Get.bottomSheet(
                            const StreakFreezePreviewBottomSheet(),
                            isDismissible: true,
                            isScrollControlled: true,
                            enableDrag: true,
                            backgroundColor: Colors.transparent,
                            enterBottomSheetDuration: const Duration(
                              milliseconds: 300,
                            ),
                            exitBottomSheetDuration: const Duration(
                              milliseconds: 250,
                            ),
                          );
                        },
                        child: buildImageButton(
                          'assets/images/streak_icon.png',
                          width: 72.w,
                          height: 36.w,
                        ),
                      ),
                      Row(
                        children: [
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
                                    final streamContent = SingleChildScrollView(
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

                                            Widget buildSingle() {
                                              final url =
                                                  chatCtrl.watchUrl.value ?? '';
                                              // If selected platform is offline, force placeholder.
                                              final selected =
                                                  _chatFilter.value ?? 'twitch';
                                              final isLive =
                                                  chatCtrl.isPlatformLive(
                                                    selected,
                                                  );
                                              final resolvedUrl =
                                                  isLive ? url : '';
                                              return StreamWebView(
                                                key: _streamWebViewKey,
                                                url: resolvedUrl,
                                                height: streamPreviewHeight,
                                              );
                                            }

                                            Widget buildMulti() {
                                              // Segmented layout: max 3 streams.
                                              const allPlatforms = [
                                                'twitch',
                                                'kick',
                                                'youtube',
                                              ];
                                              final platforms = allPlatforms;

                                              final tileGap = 8.w;
                                              const topFlex = 56;
                                              const bottomFlex = 44;

                                              Widget tile({
                                                required String platform,
                                                required BorderRadius radius,
                                                required double height,
                                              }) {
                                                final url = chatCtrl
                                                        .isPlatformLive(platform)
                                                    ? (chatCtrl.urlForPlatform(
                                                          platform,
                                                        ) ??
                                                        '')
                                                    : '';
                                                return ClipRRect(
                                                  borderRadius: radius,
                                                  child: StreamWebView(
                                                    key: ValueKey('stream_$platform'),
                                                    url: url,
                                                    height: height,
                                                  ),
                                                );
                                              }

                                              // Three streams: top row 2 tiles (only one outer top corner each),
                                              // bottom tile spans full width (only bottom corners).
                                              return Column(
                                                children: [
                                                  Expanded(
                                                    flex: topFlex,
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: tile(
                                                            platform: platforms[0],
                                                            radius: BorderRadius.only(
                                                              topLeft:
                                                                  Radius.circular(
                                                                    16.r,
                                                                  ),
                                                            ),
                                                            height: streamPreviewHeight,
                                                          ),
                                                        ),
                                                        SizedBox(width: tileGap),
                                                        Expanded(
                                                          child: tile(
                                                            platform: platforms[1],
                                                            radius: BorderRadius.only(
                                                              topRight:
                                                                  Radius.circular(
                                                                    16.r,
                                                                  ),
                                                            ),
                                                            height: streamPreviewHeight,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(height: tileGap),
                                                  Expanded(
                                                    flex: bottomFlex,
                                                    child: tile(
                                                      platform: platforms[2],
                                                      radius: BorderRadius.only(
                                                        bottomLeft:
                                                            Radius.circular(16.r),
                                                        bottomRight:
                                                            Radius.circular(16.r),
                                                      ),
                                                      height: streamPreviewHeight,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }

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
                                                          ? buildMulti()
                                                          : buildSingle(),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            );

                                            if (!showCard) {
                                              return webView;
                                            }

                                            return Stack(
                                              children: [
                                                // Keep the WebView alive to avoid platform-view recreation issues.
                                                Offstage(
                                                  offstage: true,
                                                  child: webView,
                                                ),
                                                ValueListenableBuilder<bool>(
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
                                                            final asset =
                                                                platform ==
                                                                        'twitch'
                                                                    ? 'assets/images/twitch1.png'
                                                                    : platform ==
                                                                        'kick'
                                                                    ? 'assets/images/kick.png'
                                                                    : 'assets/images/youtube1.png';

                                                            return SizedBox(
                                                              height:
                                                                  upperSectionHeight,
                                                              child: Column(
                                                                children: [
                                                                  Expanded(
                                                                    child: Container(
                                                                      width:
                                                                          double
                                                                              .infinity,
                                                                      padding: EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            12.w,
                                                                        vertical:
                                                                            12.h,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color:
                                                                            black,
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
                                                                                Center(
                                                                                  child: Image.asset(
                                                                                    asset,
                                                                                    width:
                                                                                        22.w,
                                                                                    height:
                                                                                        22.h,
                                                                                  ),
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
                                                                          panelRow(
                                                                            context.l10n.titleExample,
                                                                          ),
                                                                          SizedBox(
                                                                            height:
                                                                                12.h,
                                                                          ),
                                                                          panelRow(
                                                                            context.l10n.nameCategory,
                                                                            showChevron:
                                                                                true,
                                                                            onTap: () {
                                                                              showModalBottomSheet(
                                                                                context:
                                                                                    context,
                                                                                isScrollControlled:
                                                                                    true,
                                                                                backgroundColor:
                                                                                    Colors.transparent,
                                                                                builder: (
                                                                                  ctx,
                                                                                ) {
                                                                                  return Padding(
                                                                                    padding: EdgeInsets.only(
                                                                                      bottom:
                                                                                          MediaQuery.of(
                                                                                            ctx,
                                                                                          ).viewInsets.bottom,
                                                                                    ),
                                                                                    child: FractionallySizedBox(
                                                                                      heightFactor:
                                                                                          0.8,
                                                                                      child: AnimatedPadding(
                                                                                        padding: EdgeInsets.only(
                                                                                          bottom:
                                                                                              MediaQuery.of(
                                                                                                ctx,
                                                                                              ).viewInsets.bottom,
                                                                                        ),
                                                                                        duration: const Duration(
                                                                                          milliseconds:
                                                                                              250,
                                                                                        ),
                                                                                        curve:
                                                                                            Curves.easeOut,
                                                                                        child: Container(
                                                                                          decoration: BoxDecoration(
                                                                                            color: const Color.fromRGBO(
                                                                                              20,
                                                                                              18,
                                                                                              18,
                                                                                              1,
                                                                                            ),
                                                                                            borderRadius: const BorderRadius.vertical(
                                                                                              top: Radius.circular(
                                                                                                38,
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                          child: Stack(
                                                                                            children: [
                                                                                              Column(
                                                                                                children: [
                                                                                                  SizedBox(
                                                                                                    height:
                                                                                                        10.h,
                                                                                                  ),
                                                                                                  Padding(
                                                                                                    padding: EdgeInsets.symmetric(
                                                                                                      horizontal:
                                                                                                          18.w,
                                                                                                      vertical:
                                                                                                          10,
                                                                                                    ),
                                                                                                    child: Row(
                                                                                                      children: [
                                                                                                        GestureDetector(
                                                                                                          onTap:
                                                                                                              () =>
                                                                                                                  Navigator.of(
                                                                                                                    ctx,
                                                                                                                  ).pop(),
                                                                                                          child: Container(
                                                                                                            padding: EdgeInsets.all(
                                                                                                              8.w,
                                                                                                            ),
                                                                                                            decoration: const BoxDecoration(
                                                                                                              color: Color.fromRGBO(
                                                                                                                120,
                                                                                                                120,
                                                                                                                128,
                                                                                                                0.16,
                                                                                                              ),
                                                                                                              shape:
                                                                                                                  BoxShape.circle,
                                                                                                            ),
                                                                                                            child: Center(
                                                                                                              child: Transform.translate(
                                                                                                                offset: const Offset(
                                                                                                                  2.5,
                                                                                                                  0,
                                                                                                                ),
                                                                                                                child: Icon(
                                                                                                                  Icons.arrow_back_ios,
                                                                                                                  color:
                                                                                                                      Colors.white,
                                                                                                                  size:
                                                                                                                      18,
                                                                                                                ),
                                                                                                              ),
                                                                                                            ),
                                                                                                          ),
                                                                                                        ),
                                                                                                        const Spacer(),
                                                                                                        Text(
                                                                                                          context.l10n.category,
                                                                                                          style: sfProText600(
                                                                                                            18.sp,
                                                                                                            Colors.white,
                                                                                                          ),
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
                                                                                                        12.h,
                                                                                                  ),
                                                                                                  Expanded(
                                                                                                    child: ListView.separated(
                                                                                                      padding: EdgeInsets.only(
                                                                                                        left:
                                                                                                            16.w,
                                                                                                        right:
                                                                                                            16.w,
                                                                                                        top:
                                                                                                            8.h,
                                                                                                        bottom:
                                                                                                            100.h,
                                                                                                      ),
                                                                                                      itemCount:
                                                                                                          3,
                                                                                                      separatorBuilder:
                                                                                                          (
                                                                                                            _,
                                                                                                            __,
                                                                                                          ) => SizedBox(
                                                                                                            height:
                                                                                                                12.h,
                                                                                                          ),
                                                                                                      itemBuilder: (
                                                                                                        c,
                                                                                                        i,
                                                                                                      ) {
                                                                                                        return InkWell(
                                                                                                          onTap:
                                                                                                              () {},
                                                                                                          borderRadius: BorderRadius.circular(
                                                                                                            32.r,
                                                                                                          ),
                                                                                                          child: Container(
                                                                                                            padding: EdgeInsets.symmetric(
                                                                                                              horizontal:
                                                                                                                  20.w,
                                                                                                              vertical:
                                                                                                                  13.h,
                                                                                                            ),
                                                                                                            decoration: BoxDecoration(
                                                                                                              color: const Color.fromRGBO(
                                                                                                                37,
                                                                                                                37,
                                                                                                                37,
                                                                                                                1,
                                                                                                              ),
                                                                                                              borderRadius: BorderRadius.circular(
                                                                                                                28.r,
                                                                                                              ),
                                                                                                            ),
                                                                                                            child: Row(
                                                                                                              children: [
                                                                                                                Text(
                                                                                                                  context.l10n.nameCategory,
                                                                                                                  style: sfProText400(
                                                                                                                    13.sp,
                                                                                                                    Colors.white,
                                                                                                                  ),
                                                                                                                ),
                                                                                                                const Spacer(),
                                                                                                                Container(
                                                                                                                  width:
                                                                                                                      25.w,
                                                                                                                  height:
                                                                                                                      25.w,
                                                                                                                  decoration: BoxDecoration(
                                                                                                                    color:
                                                                                                                        Colors.grey.shade900,
                                                                                                                    borderRadius: BorderRadius.circular(
                                                                                                                      18.r,
                                                                                                                    ),
                                                                                                                  ),
                                                                                                                  child: Icon(
                                                                                                                    Icons.arrow_forward_ios,
                                                                                                                    color:
                                                                                                                        Colors.grey.shade500,
                                                                                                                    size:
                                                                                                                        10.sp,
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ],
                                                                                                            ),
                                                                                                          ),
                                                                                                        );
                                                                                                      },
                                                                                                    ),
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                              Positioned(
                                                                                                bottom:
                                                                                                    18.h,
                                                                                                left:
                                                                                                    74.w,
                                                                                                right:
                                                                                                    74.w,
                                                                                                child: Container(
                                                                                                  height:
                                                                                                      56.h,
                                                                                                  padding: EdgeInsets.symmetric(
                                                                                                    horizontal:
                                                                                                        16.w,
                                                                                                  ),
                                                                                                  decoration: BoxDecoration(
                                                                                                    color:
                                                                                                        Colors.black,
                                                                                                    borderRadius: BorderRadius.circular(
                                                                                                      28.r,
                                                                                                    ),
                                                                                                  ),
                                                                                                  child: Row(
                                                                                                    children: [
                                                                                                      Icon(
                                                                                                        Icons.search,
                                                                                                        color:
                                                                                                            Colors.white,
                                                                                                        size:
                                                                                                            22.sp,
                                                                                                      ),
                                                                                                      SizedBox(
                                                                                                        width:
                                                                                                            12.w,
                                                                                                      ),
                                                                                                        Expanded(
                                                                                                        child: Text(
                                                                                                          context.l10n.search,
                                                                                                          style: sfProText400(
                                                                                                            18.sp,
                                                                                                            Colors.white.withOpacity(
                                                                                                              0.6,
                                                                                                            ),
                                                                                                          ),
                                                                                                        ),
                                                                                                      ),
                                                                                                      SizedBox(
                                                                                                        width:
                                                                                                            8.w,
                                                                                                      ),
                                                                                                      Icon(
                                                                                                        Icons.mic,
                                                                                                        color:
                                                                                                            Colors.white,
                                                                                                        size:
                                                                                                            22.sp,
                                                                                                      ),
                                                                                                    ],
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              );
                                                                            },
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }

                                                          return SizedBox(
                                                            height:
                                                                upperSectionHeight,
                                                            child: Column(
                                                              children: [
                                                                Expanded(
                                                                  child: Stack(
                                                                    alignment:
                                                                        Alignment
                                                                            .center,
                                                                    children: [
                                                                      Container(
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
                                                                          children: [
                                                                            serviceRow(
                                                                              asset:
                                                                                  'assets/images/youtube1.png',
                                                                              title:
                                                                                  context.l10n.title,
                                                                              subtitle:
                                                                                  context.l10n.category,
                                                                              onTap: () {
                                                                                _selectedPlatform.value = 'youtube';
                                                                                _titleSelected.value = true;
                                                                                _showServiceCard.value = true;
                                                                              },
                                                                            ),
                                                                            SizedBox(
                                                                              height:
                                                                                  36.h,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      Positioned(
                                                                        bottom:
                                                                            6.h,
                                                                        child: Container(
                                                                          padding: EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                20.w,
                                                                            vertical:
                                                                                8.h,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color: const Color.fromRGBO(
                                                                              20,
                                                                              18,
                                                                              20,
                                                                              1,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              20.r,
                                                                            ),
                                                                            border: Border.all(
                                                                              color:
                                                                                  Colors.white10,
                                                                              width:
                                                                                  1.w,
                                                                            ),
                                                                          ),
                                                                          child: Text(
                                                                            context.l10n.updateAll,
                                                                            style: sfProText400(
                                                                              14.sp,
                                                                              const Color.fromRGBO(
                                                                                238,
                                                                                218,
                                                                                172,
                                                                                1,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    }

                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    );

                                    if (showActivity) {
                                      return Stack(
                                        children: [
                                          // Keep stream (WebView) alive under Activity to avoid platform-view recreation issues.
                                          Offstage(
                                            offstage: true,
                                            child: streamContent,
                                          ),
                                          _buildResizableActivityContainer(
                                            context,
                                            upperSectionHeight,
                                          ),
                                        ],
                                      );
                                    }

                                    return streamContent;
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

// ── Eager gesture recognizer ──────────────────────────────────────────
class _EagerVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
