import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/core/localization/l10n.dart';

import '../../controllers/Main Section Controllers/settings_controller.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';
import 'Last_streak.dart';
import 'streak_history_bottomsheet.dart';

class StreakFreezePreviewBottomSheet extends StatefulWidget {
  const StreakFreezePreviewBottomSheet({
    super.key,
    this.fetchOnInit = true,
  });

  final bool fetchOnInit;

  @override
  State<StreakFreezePreviewBottomSheet> createState() =>
      _StreakFreezePreviewBottomSheetState();
}

class _StreakFreezePreviewBottomSheetState
    extends State<StreakFreezePreviewBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _frameController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _framesPreloaded = false;
  bool _isUpdating = false;
  late final StreamStreaksController _streakCtrl;
  late final SettingsController _settings;
  Worker? _lowPowerWorker;

  static const int days = 7;
  static const double horizontalPadding = 12;
  static const double rowHeight = 32;
  static const int totalFrames = 95; // Frames from 0001 to 0095

  @override
  void initState() {
    super.initState();
    _streakCtrl = Get.find<StreamStreaksController>();
    _settings = Get.find<SettingsController>();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.1, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_settings.lowPowerMode.value) {
      _pulseController.value = 0.5;
      _frameController.value = 0;
    } else {
      _pulseController.repeat(reverse: true);
      _frameController.repeat();
    }

    _lowPowerWorker = ever(_settings.lowPowerMode, (bool low) {
      if (low) {
        _pulseController.stop();
        _frameController.stop();
      } else {
        _pulseController.repeat(reverse: true);
        _frameController.repeat();
      }
      if (mounted) setState(() {});
    });

    if (widget.fetchOnInit) {
      _streakCtrl.fetchCurrentStreak(silent: true);
      _streakCtrl.fetchHistory(silent: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload frames when context is available
    if (!_framesPreloaded) {
      _preloadFrozenFireFrames();
      _framesPreloaded = true;
    }
  }

  void _preloadFrozenFireFrames() {
    // Preload first 30 frames immediately for instant display
    for (int i = 1; i <= 30 && i <= totalFrames; i++) {
      final frameNumber = i.toString().padLeft(4, '0');
      precacheImage(
        AssetImage('assets/FrozenFire/frame_$frameNumber.png'),
        context,
      );
    }

    // Preload remaining frames in background
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        for (int i = 31; i <= totalFrames; i++) {
          final frameNumber = i.toString().padLeft(4, '0');
          precacheImage(
            AssetImage('assets/FrozenFire/frame_$frameNumber.png'),
            context,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _lowPowerWorker?.dispose();
    _pulseController.dispose();
    _frameController.dispose();
    super.dispose();
  }

  Widget _lowPowerFreezeGraphic(BuildContext context) {
    const scale = 1.125;
    const opacity = 0.2;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: scale,
          child: Container(
            width: 140.h,
            height: 140.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0XFF84DEE4).withOpacity(opacity),
                  blurRadius: 55,
                  spreadRadius: 15,
                ),
              ],
            ),
          ),
        ),
        Image.asset(
          'assets/FrozenFire/frame_0001.png',
          height: 177.h,
          width: 177.w,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          cacheWidth:
              (177.w * MediaQuery.of(context).devicePixelRatio).round(),
          cacheHeight:
              (177.h * MediaQuery.of(context).devicePixelRatio).round(),
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 177.h,
              width: 177.w,
              color: Colors.transparent,
            );
          },
        ),
      ],
    );
  }

  List<List<int>> _getTickGroups(List<CellType> row) {
    final groups = <List<int>>[];
    int start = -1;
    for (int i = 0; i < row.length; i++) {
      if (row[i] == CellType.tick) {
        if (start == -1) start = i;
      } else {
        if (start != -1) {
          groups.add([start, i - 1]);
          start = -1;
        }
      }
    }
    if (start != -1) groups.add([start, row.length - 1]);
    return groups;
  }

  Future<bool> _updateStreak(List<String> selectedDays) async {
    if (_isUpdating) return false;
    setState(() => _isUpdating = true);
    try {
      return await _streakCtrl.updateStreak(
        selectedDays: selectedDays,
        showErrors: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _toggleSelectedDay(int dayIndex, CellType cell) async {
    if (_isUpdating) return;
    final streak = _streakCtrl.streak;
    if (streak == null || !streak.hasCreatedStreak) return;

    const ordered = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    if (dayIndex < 0 || dayIndex >= ordered.length) return;

    final dayKey = ordered[dayIndex];
    final updatedDays = streak.selectedDays.toSet();
    final wasSelected = updatedDays.contains(dayKey);
    if (wasSelected) {
      updatedDays.remove(dayKey);
    } else {
      updatedDays.add(dayKey);
    }

    await _updateStreak(updatedDays.toList());
  }

  // NEW: Widget for the drag handle (bottom sheet bar)
  Widget _buildDragHandle() {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
      child: Center(
        child: Container(
          width: 40.w, // Common width for a grabber
          height: 4.h, // Common height for a grabber
          decoration: BoxDecoration(
            color: const Color(0xFF48484A), // Medium dark grey for visibility
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      ),
    );
  }

  // --- Static UI Components ---

  Widget _tick({bool highlighted = false}) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration:
          highlighted
              ? const BoxDecoration(color: Colors.white, shape: BoxShape.circle)
              : null,
      child: Icon(
        Icons.check,
        size: 18.sp,
        color: highlighted ? const Color(0xFFFDB747) : Colors.white,
      ),
    );
  }

  Widget _cross() =>
      Icon(Icons.close, color: const Color(0xFF8E8E93), size: 22.sp);
  Widget _freeze() =>
      Image.asset('assets/images/Privacy & Security - SVG.png', width: 22.sp);
  Widget _dot() => Opacity(
    opacity: 0.3,
    child: Icon(Icons.circle, size: 10.sp, color: Colors.white),
  );

  Widget _highlight(int start, int end, double totalWidth) {
    final int count = end - start + 1;
    final double cellWidth = totalWidth / days;
    final bool isCircle = count == 1;

    return Positioned(
      left: start * cellWidth,
      width: count * cellWidth,
      top: 0,
      bottom: 0,
      child: Container(
        margin:
            isCircle ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: 2.w),
        decoration: BoxDecoration(
          // Always use golden gradient for all tick highlights
          gradient: const LinearGradient(
            colors: [Color(0xFFF2B269), Color(0xFFFFE6A7)],
          ),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(22.r),
        ),
      ),
    );
  }

  Widget _row(List<CellType> rowData, double totalWidth, int rowIndex) {
    final groups = _getTickGroups(rowData);

    return SizedBox(
      height: rowHeight.h,
      child: Stack(
        children: [
          for (final g in groups) _highlight(g[0], g[1], totalWidth),
          Row(
            children: List.generate(days, (i) {
              final cell = rowData[i];
              Widget icon;
              switch (cell) {
                case CellType.tick:
                  icon = _tick();
                  break;
                case CellType.cross:
                  icon = _cross();
                  break;
                case CellType.freeze:
                  icon = _freeze();
                  break;
                case CellType.dot:
                  icon = _dot();
                  break;
              }
              final canEdit =
                  rowIndex == 0 && _streakCtrl.supportsDayEditing;
              return Expanded(
                child: Center(
                  child: canEdit
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _toggleSelectedDay(i, cell),
                          child: icon,
                        )
                      : icon,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final streak = _streakCtrl.streak;
      final hasCreatedStreak = streak?.hasCreatedStreak ?? false;
      final isInDanger = streak?.isInDanger ?? false;
      final canProceedToFreeze = hasCreatedStreak && isInDanger;
      final currentStreakCount = streak?.currentStreak ?? 0;
      final titleText = (streak?.isInDanger ?? false)
          ? context.l10n.streakInDangerHitFreezeButton
          : context.l10n.youVeNeverBeenHotterKeepStreakBurning;
      final freezeAllowance = streak?.freezeAllowancePerMonth ?? 0;
      final calendarRows = _streakCtrl.buildCalendarRows(maxRows: 4);

      return Container(
        height: Get.height * 0.9,
        decoration: BoxDecoration(
          color: bottomSheetGrey,
          // UPDATED: Increased border radius for better visibility
          borderRadius: BorderRadius.vertical(top: Radius.circular(38.r)),
        ),
        child: ClipRRect(
          // UPDATED: Increased border radius for better visibility
          borderRadius: BorderRadius.vertical(top: Radius.circular(38.r)),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: 100.h + MediaQuery
                        .of(context)
                        .viewPadding
                        .bottom,
                  ),
                  child: Column(
                    children: [
                      _buildDragHandle(),
                      // ADDED: Drag handle (bottom sheet bar)
                      // SizedBox(height: 12.h), // Replaced by drag handle's padding
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Get.back(),
                              child: Image.asset(
                                'assets/icons/x_icon.png',
                                height: 44.h,
                              ),
                            ),
                            Text(
                              context.l10n.streamStreaks,
                              style: sfProText600(17.sp, Colors.white),
                            ),
                            SizedBox(width: 44.w),
                          ],
                        ),
                      ),
                      SizedBox(height: 10.h),
                      RepaintBoundary(
                        child: _settings.lowPowerMode.value
                            ? _lowPowerFreezeGraphic(context)
                            : AnimatedBuilder(
                                animation: Listenable.merge([
                                  _pulseController,
                                  _frameController,
                                ]),
                                builder: (context, child) {
                                  double animValue =
                                      _frameController.value.clamp(0.0, 1.0);
                                  int frame =
                                      ((animValue * totalFrames).round() %
                                          totalFrames);
                                  frame =
                                      (frame == 0 ? totalFrames : frame).clamp(
                                    1,
                                    totalFrames,
                                  );
                                  String frameNumber =
                                      frame.toString().padLeft(4, '0');

                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.scale(
                                        scale: _scaleAnimation.value,
                                        child: Container(
                                          width: 140.h,
                                          height: 140.h,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0XFF84DEE4,
                                                ).withOpacity(
                                                    _opacityAnimation.value),
                                                blurRadius: 55,
                                                spreadRadius: 15,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Image.asset(
                                        'assets/FrozenFire/frame_$frameNumber.png',
                                        height: 177.h,
                                        width: 177.w,
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                        cacheWidth: (177.w *
                                                MediaQuery.of(context)
                                                    .devicePixelRatio)
                                            .round(),
                                        cacheHeight: (177.h *
                                                MediaQuery.of(context)
                                                    .devicePixelRatio)
                                            .round(),
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            height: 177.h,
                                            width: 177.w,
                                            color: Colors.transparent,
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        titleText,
                        textAlign: TextAlign.center,
                        style: sfProDisplay600(22.sp, Colors.white),
                      ),
                      if (hasCreatedStreak) ...[
                        SizedBox(height: 4.h),
                        Text(
                          '$currentStreakCount ${context.l10n.dayStreak}',
                          textAlign: TextAlign.center,
                          style: sfProDisplay400(
                            15.sp,
                            const Color(0xFFB0B3B8),
                          ),
                        ),
                      ],
                      SizedBox(height: 6.h),

                      // Static Pill
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF32393D),
                          borderRadius: BorderRadius.circular(40.r),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              "assets/images/checkmark.circle.fill.png",
                              width: 19.w,
                              height: 24.h,
                            ),
                            SizedBox(width: 8.w),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                  text: '$freezeAllowance ',
                                    style: sfProDisplay400(15.sp, Colors.white),
                                  ),
                                  TextSpan(
                                    text: context.l10n.freezesPerMonthLabel,
                                    style: sfProDisplay400(
                                      15.sp,
                                      const Color(0xFFB0B3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // Static Calendar Container (Obx removed)
                      Container(
                        width: 361.w,
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1D20),
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final totalWidth = constraints.maxWidth;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: (() {
                                    final locale =
                                    Localizations.localeOf(context)
                                        .toLanguageTag();
                                    final weekdays =
                                        DateFormat
                                            .E(locale)
                                            .dateSymbols
                                            .SHORTWEEKDAYS;
                                    return [
                                      ...weekdays.skip(1),
                                      weekdays.first
                                    ];
                                  })().map((d) {
                                    return Expanded(
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: TextStyle(
                                            color: const Color(0xFF8E8E93),
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                SizedBox(height: 16.h),
                                for (int i = 0; i <
                                    calendarRows.length; i++) ...[
                                  _row(calendarRows[i], totalWidth, i),
                                  if (i != calendarRows.length - 1)
                                    SizedBox(height: 12.h),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: 361.w,
                        height: 46.h,
                        child: OutlinedButton(
                          onPressed: () {
                            Get.bottomSheet(
                              const StreakHistoryBottomSheet(),
                              isDismissible: true,
                              isScrollControlled: true,
                              enableDrag: true,
                              backgroundColor: Colors.transparent,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF6B6B6F)),
                            backgroundColor: const Color(0xFF1E1D20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18.r),
                            ),
                          ),
                          child: Text(
                            'Streak History',
                            style: sfProText600(15.sp, Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Action Button (above nav bar)
                Positioned(
                  left: 16.w,
                  right: 16.w,
                  bottom: 16.h + MediaQuery
                      .of(context)
                      .viewPadding
                      .bottom,
                    child: SizedBox(
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: canProceedToFreeze
                            ? () {
                                Get.back();
                                Get.bottomSheet(
                                  const StreakFreezeUseBottomSheet(),
                                  isScrollControlled: true,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canProceedToFreeze
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          disabledBackgroundColor: Colors.white.withOpacity(
                            0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(36.r),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          context.l10n.letsGo,
                          style: sfProText600(
                            17.sp,
                            canProceedToFreeze
                                ? Colors.black
                                : Colors.black.withOpacity(0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    );
    }
}
