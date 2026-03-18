import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/core/localization/l10n.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';
import 'Compact_freeze.dart';

class StreakFreezePreviewBottomSheet extends StatefulWidget {
  const StreakFreezePreviewBottomSheet({super.key});

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
  bool _isLoading = false;
  bool _isUpdating = false;
  _StreakSnapshot? _streak;
  late List<List<CellType>> _calendarRows;

  static const int days = 7;
  static const double horizontalPadding = 12;
  static const double rowHeight = 32;
  static const int totalFrames = 95; // Frames from 0001 to 0095

  @override
  void initState() {
    super.initState();
    _calendarRows = _buildEmptyCalendarRows();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Frame animation controller - loops continuously forward
    // Optimized duration for smoother playback
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 2500,
      ), // Slightly faster for smoother feel
    );
    // repeat() automatically handles looping and starts the animation
    _frameController.repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.1, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadStreak();
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
    _pulseController.dispose();
    _frameController.dispose();
    super.dispose();
  }

  List<List<CellType>> _buildEmptyCalendarRows() {
    return List.generate(
      4,
      (_) => List.generate(days, (_) => CellType.cross),
    );
  }

  List<List<CellType>> _buildCalendarRows(_StreakSnapshot snapshot) {
    final selected = snapshot.selectedDays
        .map((d) => d.toLowerCase().trim())
        .where((d) => d.isNotEmpty)
        .toSet();
    final ordered = const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    int completed = snapshot.completedThisWeek;

    final weekRow = <CellType>[];
    for (final day in ordered) {
      if (selected.contains(day)) {
        if (completed > 0) {
          weekRow.add(CellType.tick);
          completed--;
        } else {
          weekRow.add(CellType.dot);
        }
      } else {
        weekRow.add(CellType.cross);
      }
    }

    return [
      weekRow,
      ...List.generate(
        3,
        (_) => List.generate(days, (_) => CellType.cross),
      ),
    ];
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
      final auth = Get.find<AuthController>();
      final tokens = await auth.api.tokenStore.read();
      final accessToken = tokens?.accessToken?.trim();
      if (accessToken == null || accessToken.isEmpty) {
        final l10n = context.l10n;
        Get.snackbar(
          l10n.sessionMissing,
          l10n.sessionMissingMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF2C2C2E),
          colorText: Colors.white,
          margin: EdgeInsets.all(12.w),
          duration: const Duration(seconds: 2),
        );
        return false;
      }

      await auth.api.client.dio.patch<dynamic>(
        '/api/v1/streak',
        data: {'selectedDays': selectedDays},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      return true;
    } on DioException catch (e) {
      debugPrint('STREAK UPDATE ERROR: ${e.response?.data ?? e.message}');
    } catch (e) {
      debugPrint('STREAK UPDATE ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }

    final l10n = context.l10n;
    Get.snackbar(
      l10n.connectionIssue,
      l10n.pleaseTryAgain,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF2C2C2E),
      colorText: Colors.white,
      margin: EdgeInsets.all(12.w),
      duration: const Duration(seconds: 2),
    );
    return false;
  }

  Future<void> _toggleSelectedDay(int dayIndex, CellType cell) async {
    if (_isLoading || _isUpdating) return;
    final streak = _streak;
    if (streak == null) return;

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

    final removedCompleted = wasSelected && cell == CellType.tick;
    final nextCompleted = removedCompleted
        ? (streak.completedThisWeek - 1).clamp(0, streak.completedThisWeek)
        : streak.completedThisWeek;

    final prev = streak;
    final next = prev.copyWith(
      selectedDays: updatedDays.toList(),
      targetDaysPerWeek: updatedDays.length,
      completedThisWeek: nextCompleted,
      remainingThisWeek: (updatedDays.length - nextCompleted)
          .clamp(0, updatedDays.length),
    );

    _applySnapshot(next);

    final ok = await _updateStreak(updatedDays.toList());
    if (!ok) {
      _applySnapshot(prev);
    }
  }

  Future<void> _loadStreak() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final auth = Get.find<AuthController>();
      final tokens = await auth.api.tokenStore.read();
      final accessToken = tokens?.accessToken?.trim();
      if (accessToken == null || accessToken.isEmpty) {
        _applySnapshot(_StreakSnapshot.empty());
        return;
      }

      final res = await auth.api.client.dio.get<dynamic>(
        '/api/v1/streak',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      final snapshot = _StreakSnapshot.fromPayload(res.data);
      _applySnapshot(snapshot);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _applySnapshot(_StreakSnapshot.empty());
      } else {
        debugPrint('STREAK LOAD ERROR: ${e.response?.data ?? e.message}');
      }
    } catch (e) {
      debugPrint('STREAK LOAD ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applySnapshot(_StreakSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _streak = snapshot;
      _calendarRows = _buildCalendarRows(snapshot);
    });
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
              final canEdit = rowIndex == 0;
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
    final streak = _streak;
    final titleText = (streak?.isInDanger ?? false)
        ? context.l10n.streakInDangerHitFreezeButton
        : context.l10n.youVeNeverBeenHotterKeepStreakBurning;
    final freezeTokens = streak?.freezeTokens ?? 0;

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
                  bottom: 100.h + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: Column(
                  children: [
                    _buildDragHandle(), // ADDED: Drag handle (bottom sheet bar)
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
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _pulseController,
                          _frameController,
                        ]),
                        builder: (context, child) {
                          // Optimized frame calculation using round() for smoother transitions
                          double animValue = _frameController.value.clamp(
                            0.0,
                            1.0,
                          );
                          // Use round() instead of floor() for smoother frame transitions
                          int frame =
                              ((animValue * totalFrames).round() % totalFrames);
                          frame = (frame == 0 ? totalFrames : frame).clamp(
                            1,
                            totalFrames,
                          );
                          String frameNumber = frame.toString().padLeft(4, '0');

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
                                        ).withOpacity(_opacityAnimation.value),
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
                                // Optimized cache dimensions for exact size
                                cacheWidth:
                                    (177.w *
                                            MediaQuery.of(
                                              context,
                                            ).devicePixelRatio)
                                        .round(),
                                cacheHeight:
                                    (177.h *
                                            MediaQuery.of(
                                              context,
                                            ).devicePixelRatio)
                                        .round(),
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
                        },
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: sfProDisplay600(22.sp, Colors.white),
                    ),
                    if (streak != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        '${streak.currentStreak} ${context.l10n.dayStreak}',
                        textAlign: TextAlign.center,
                        style: sfProDisplay400(
                          15.sp,
                          const Color(0xFFB0B3B8),
                        ),
                      ),
                    ],
                    if (_isLoading) ...[
                      SizedBox(height: 6.h),
                      SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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
                                  text: '$freezeTokens ',
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
                                      DateFormat.E(locale).dateSymbols.SHORTWEEKDAYS;
                                  return [...weekdays.skip(1), weekdays.first];
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
                              for (int i = 0; i < _calendarRows.length; i++) ...[
                                _row(_calendarRows[i], totalWidth, i),
                                if (i != _calendarRows.length - 1)
                                  SizedBox(height: 12.h),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Action Button (above nav bar)
              Positioned(
                left: 16.w,
                right: 16.w,
                bottom: 16.h + MediaQuery.of(context).viewPadding.bottom,
                child: SizedBox(
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      Get.bottomSheet(
                        const StreakFreezeSingleRowPreviewBottomSheet(),
                        isScrollControlled: true,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36.r),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      context.l10n.letsGo,
                      style: sfProText600(17.sp, Colors.black),
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
}

class _StreakSnapshot {
  const _StreakSnapshot({
    required this.currentStreak,
    required this.longestStreak,
    required this.selectedDays,
    required this.targetDaysPerWeek,
    required this.completedThisWeek,
    required this.remainingThisWeek,
    required this.freezeTokens,
    required this.status,
    required this.isInDanger,
    required this.weekStartDate,
  });

  final int currentStreak;
  final int longestStreak;
  final List<String> selectedDays;
  final int targetDaysPerWeek;
  final int completedThisWeek;
  final int remainingThisWeek;
  final int freezeTokens;
  final String status;
  final bool isInDanger;
  final DateTime? weekStartDate;

  factory _StreakSnapshot.empty() => const _StreakSnapshot(
        currentStreak: 0,
        longestStreak: 0,
        selectedDays: <String>[],
        targetDaysPerWeek: 0,
        completedThisWeek: 0,
        remainingThisWeek: 0,
        freezeTokens: 0,
        status: '',
        isInDanger: false,
        weekStartDate: null,
      );

  factory _StreakSnapshot.fromPayload(dynamic payload) {
    dynamic data = payload;
    if (data is Map && data['data'] != null) {
      data = data['data'];
    }

    if (data is Map) {
      final selectedDays = _asStringList(data['selectedDays']);
      final status = _asString(data['status']);
      final isInDanger =
          _asBool(data['isInDanger']) || status.toLowerCase() == 'danger';
      final weekStartRaw = _asString(data['weekStartDate']);

      return _StreakSnapshot(
        currentStreak: _asInt(data['currentStreak']),
        longestStreak: _asInt(data['longestStreak']),
        selectedDays: selectedDays,
        targetDaysPerWeek: _asInt(
          data['targetDaysPerWeek'],
          fallback: selectedDays.length,
        ),
        completedThisWeek: _asInt(data['completedThisWeek']),
        remainingThisWeek: _asInt(data['remainingThisWeek']),
        freezeTokens: _asInt(data['freezeTokens']),
        status: status,
        isInDanger: isInDanger,
        weekStartDate:
            weekStartRaw.isEmpty ? null : DateTime.tryParse(weekStartRaw),
      );
    }

    return _StreakSnapshot.empty();
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return false;
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  _StreakSnapshot copyWith({
    int? currentStreak,
    int? longestStreak,
    List<String>? selectedDays,
    int? targetDaysPerWeek,
    int? completedThisWeek,
    int? remainingThisWeek,
    int? freezeTokens,
    String? status,
    bool? isInDanger,
    DateTime? weekStartDate,
  }) {
    return _StreakSnapshot(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      selectedDays: selectedDays ?? this.selectedDays,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      completedThisWeek: completedThisWeek ?? this.completedThisWeek,
      remainingThisWeek: remainingThisWeek ?? this.remainingThisWeek,
      freezeTokens: freezeTokens ?? this.freezeTokens,
      status: status ?? this.status,
      isInDanger: isInDanger ?? this.isInDanger,
      weekStartDate: weekStartDate ?? this.weekStartDate,
    );
  }
}
