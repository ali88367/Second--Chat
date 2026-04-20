import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/controllers/Main Section Controllers/streak_controller.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/localization/l10n.dart';
import 'package:second_chat/core/themes/textstyles.dart';

class StreakHistoryBottomSheet extends StatefulWidget {
  const StreakHistoryBottomSheet({super.key});

  @override
  State<StreakHistoryBottomSheet> createState() => _StreakHistoryBottomSheetState();
}

class _StreakHistoryBottomSheetState extends State<StreakHistoryBottomSheet>
    with TickerProviderStateMixin {
  static const int _days = 7;
  static const double _rowHeight = 32;
  static const int _totalFrames = 119;

  late final StreamStreaksController _streakCtrl;
  late final AnimationController _glowController;
  late final AnimationController _frameController;
  late final Animation<double> _glowPulse;
  late final Animation<double> _fireJitter;
  bool _framesPreloaded = false;

  @override
  void initState() {
    super.initState();
    _streakCtrl = Get.find<StreamStreaksController>();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _glowPulse = Tween<double>(begin: 0.2, end: 0.45).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );
    _fireJitter = Tween<double>(
      begin: 0.0,
      end: -8,
    ).animate(CurvedAnimation(parent: _glowController, curve: Curves.bounceIn));
    _glowController.repeat(reverse: true);
    _frameController.repeat();
    // Use streak overview as the source of truth for history on this sheet.
    unawaited(_streakCtrl.fetchCurrentStreak(force: true, silent: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_framesPreloaded) return;
    _framesPreloaded = true;
    _preloadFireFrames();
  }

  void _preloadFireFrames() {
    for (var i = 1; i <= 30 && i <= _totalFrames; i++) {
      final frameNumber = i.toString().padLeft(4, '0');
      precacheImage(
        AssetImage('assets/FIreAnimation2/frame_lq_$frameNumber.png'),
        context,
      );
    }
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      for (var i = 31; i <= _totalFrames; i++) {
        final frameNumber = i.toString().padLeft(4, '0');
        precacheImage(
          AssetImage('assets/FIreAnimation2/frame_lq_$frameNumber.png'),
          context,
        );
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _frameController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedFireHero(int totalHistoryStreak) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowController, _frameController]),
      builder: (context, child) {
        final animValue = _frameController.value.clamp(0.0, 1.0);
        var frame = ((animValue * _totalFrames).round() % _totalFrames);
        frame = (frame == 0 ? _totalFrames : frame).clamp(1, _totalFrames);
        final frameNumber = frame.toString().padLeft(4, '0');

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180.w,
              height: 150.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(70.w, 90.h),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFF9C4).withValues(
                      alpha: 0.25 + (_glowPulse.value * 0.15),
                    ),
                    blurRadius: 110,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(0, _fireJitter.value),
              child: Image.asset(
                'assets/FIreAnimation2/frame_lq_$frameNumber.png',
                height: 180.h,
                width: 180.w,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                cacheWidth:
                    (180.w * MediaQuery.of(context).devicePixelRatio).round(),
                cacheHeight:
                    (180.h * MediaQuery.of(context).devicePixelRatio).round(),
              ),
            ),
            Positioned(
              bottom: 22.h,
              child: Text(
                '$totalHistoryStreak',
                style: sfProDisplay600(44.sp, Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tick() => Icon(Icons.check, size: 18.sp, color: Colors.white);

  Widget _cross() =>
      Icon(Icons.close, size: 20.sp, color: const Color(0xFF8E8E93));

  Widget _freeze() => Image.asset(
    'assets/images/Mask group.png',
    width: 18.w,
    height: 18.w,
    fit: BoxFit.contain,
  );

  Widget _dot() => Opacity(
    opacity: 0.35,
    child: Icon(Icons.circle, size: 9.sp, color: Colors.white),
  );

  Widget _buildCellIcon(CellType cell) {
    switch (cell) {
      case CellType.tick:
        return _tick();
      case CellType.cross:
        return _cross();
      case CellType.freeze:
        return _freeze();
      case CellType.dot:
        return _dot();
    }
  }

  List<List<int>> _getCompletedGroups(List<CellType> row) {
    final groups = <List<int>>[];
    var start = -1;
    for (var i = 0; i < row.length; i++) {
      final isCompleted = row[i] == CellType.tick || row[i] == CellType.freeze;
      if (isCompleted) {
        if (start == -1) start = i;
      } else if (start != -1) {
        groups.add([start, i - 1]);
        start = -1;
      }
    }
    if (start != -1) groups.add([start, row.length - 1]);
    return groups;
  }

  Widget _highlight(int start, int end, double totalWidth) {
    final count = end - start + 1;
    final cellWidth = totalWidth / _days;
    final isCircle = count == 1;

    return Positioned(
      left: start * cellWidth,
      width: count * cellWidth,
      top: 0,
      bottom: 0,
      child: Container(
        margin:
            isCircle ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: 2.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF2B269), Color(0xFFFFE6A7)],
          ),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(22.r),
        ),
      ),
    );
  }

  Widget _buildWeekRow(List<CellType> rowData, double totalWidth) {
    final groups = _getCompletedGroups(rowData);
    return SizedBox(
      height: _rowHeight.h,
      child: Stack(
        children: [
          for (final g in groups) _highlight(g[0], g[1], totalWidth),
          Row(
            children: List.generate(_days, (i) {
              return Expanded(child: Center(child: _buildCellIcon(rowData[i])));
            }),
          ),
        ],
      ),
    );
  }

  int _weekdayIndexFromLabel(String value) {
    final v = value.trim().toLowerCase();
    if (v.startsWith('mon')) return 0;
    if (v.startsWith('tue')) return 1;
    if (v.startsWith('wed')) return 2;
    if (v.startsWith('thu')) return 3;
    if (v.startsWith('fri')) return 4;
    if (v.startsWith('sat')) return 5;
    if (v.startsWith('sun')) return 6;
    return -1;
  }

  int _weekdayIndexFromDate(DateTime date) {
    final idx = date.weekday - 1;
    if (idx < 0) return 0;
    if (idx > 6) return 6;
    return idx;
  }

  DateTime _startOfWeek(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  CellType _cellFromEntry(Map<String, dynamic> item) {
    final frozen = item['frozen'] == true;
    final completed = item['completed'] == true;
    final isToday = item['isToday'] == true;
    if (frozen) return CellType.freeze;
    if (completed) return CellType.tick;
    if (isToday) return CellType.dot;
    return CellType.cross;
  }

  List<Map<String, dynamic>> _asEntryList(dynamic rawList) {
    if (rawList is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final item in rawList) {
      if (item is Map) out.add(Map<String, dynamic>.from(item));
    }
    return out;
  }

  List<CellType>? _buildWeeklyCheckRow(Map<String, dynamic>? overviewData) {
    if (overviewData == null) return null;
    final weeklyGoal = overviewData['weeklyGoal'];
    if (weeklyGoal is! Map) return null;

    final weekEntries = _asEntryList(weeklyGoal['week']);
    if (weekEntries.isEmpty) return null;

    final row = List<CellType>.filled(7, CellType.cross);
    for (final entry in weekEntries) {
      final dateRaw = entry['date']?.toString();
      final parsedDate = dateRaw == null ? null : DateTime.tryParse(dateRaw);
      final idx =
          parsedDate != null
              ? _weekdayIndexFromDate(parsedDate)
              : _weekdayIndexFromLabel(entry['label']?.toString() ?? '');
      if (idx < 0 || idx > 6) continue;
      row[idx] = _cellFromEntry(entry);
    }
    return row;
  }

  List<List<CellType>> _buildHistoryRowsFromOverview(Map<String, dynamic>? overviewData) {
    if (overviewData == null) return const <List<CellType>>[];
    final historyEntries = _asEntryList(overviewData['streakHistory']);
    if (historyEntries.isEmpty) return const <List<CellType>>[];

    final rowsByWeek = <DateTime, List<CellType>>{};
    for (final entry in historyEntries) {
      final dateRaw = entry['date']?.toString();
      final parsedDate = dateRaw == null ? null : DateTime.tryParse(dateRaw);
      if (parsedDate == null) continue;
      final weekStart = _startOfWeek(parsedDate);
      final row = rowsByWeek.putIfAbsent(
        weekStart,
        () => List<CellType>.filled(7, CellType.cross),
      );
      row[_weekdayIndexFromDate(parsedDate)] = _cellFromEntry(entry);
    }

    final currentWeekRow = _buildWeeklyCheckRow(overviewData);
    if (currentWeekRow != null) {
      DateTime? firstWeeklyDate;
      final weeklyGoal = overviewData['weeklyGoal'];
      if (weeklyGoal is Map) {
        final weekEntries = _asEntryList(weeklyGoal['week']);
        for (final entry in weekEntries) {
          final d = DateTime.tryParse(entry['date']?.toString() ?? '');
          if (d != null) {
            firstWeeklyDate = d;
            break;
          }
        }
      }
      final currentWeekStart = _startOfWeek(firstWeeklyDate ?? DateTime.now());
      rowsByWeek.remove(currentWeekStart);
    }

    final keys = rowsByWeek.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) => rowsByWeek[k]!).toList();
  }

  List<List<CellType>> _buildHistoryRowsFromStreakDates(StreakData? streak) {
    if (streak == null) return const <List<CellType>>[];
    final rowsByWeek = <DateTime, List<CellType>>{};
    for (final d in streak.completedDates) {
      final weekStart = _startOfWeek(d);
      final row = rowsByWeek.putIfAbsent(
        weekStart,
        () => List<CellType>.filled(7, CellType.cross),
      );
      row[_weekdayIndexFromDate(d)] = CellType.tick;
    }
    for (final d in streak.frozenDates) {
      final weekStart = _startOfWeek(d);
      final row = rowsByWeek.putIfAbsent(
        weekStart,
        () => List<CellType>.filled(7, CellType.cross),
      );
      row[_weekdayIndexFromDate(d)] = CellType.freeze;
    }
    final currentWeekStart = _startOfWeek(streak.weekStartDate ?? DateTime.now());
    rowsByWeek.remove(currentWeekStart);
    final keys = rowsByWeek.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) => rowsByWeek[k]!).toList();
  }

  int _historyTotal(Map<String, dynamic>? overviewData, StreakData? streak) {
    final historyEntries = _asEntryList(overviewData?['streakHistory']);
    if (historyEntries.isNotEmpty) {
      var total = 0;
      for (final entry in historyEntries) {
        final completed = entry['completed'] == true;
        final frozen = entry['frozen'] == true;
        if (completed || frozen) total++;
      }
      if (total > 0) return total;
    }
    return streak?.headerStreakTotal ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final streak = _streakCtrl.streak;
      final overviewData = streak?.raw;
      final weekCheckRow =
          _buildWeeklyCheckRow(overviewData) ?? _streakCtrl.buildCurrentWeekRow();
      final historyRows = _buildHistoryRowsFromOverview(overviewData);
      final fallbackRows = _buildHistoryRowsFromStreakDates(streak);
      final displayRows = historyRows.isNotEmpty ? historyRows : fallbackRows;
      final totalHistoryStreak = _historyTotal(overviewData, streak);

      return Container(
        height: Get.height * 0.9,
        decoration: BoxDecoration(
          color: bottomSheetGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(38.r)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(38.r)),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            bottomSheet: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                bottom: MediaQuery.of(context).viewPadding.bottom,
              ),
              color: bottomSheetGrey,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: () {
                      unawaited(
                        _streakCtrl.fetchHistory(force: true, silent: true),
                      );
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36.r),
                      ),
                    ),
                    child: Text(
                      context.l10n.done,
                      style: sfProText600(17.sp, Colors.black),
                    ),
                  ),
                ),
              ),
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                bottom: 86.h + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF48484A),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Image.asset('assets/icons/x_icon.png', height: 44.h),
                      ),
                      Text(
                        context.l10n.streakHistoryTitle,
                        style: sfProText600(17.sp, Colors.white),
                      ),
                      SizedBox(width: 44.w),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  _buildAnimatedFireHero(totalHistoryStreak),
                  Text(
                    '$totalHistoryStreak ${context.l10n.dayStreak}',
                    style: sfProDisplay600(28.sp, Colors.white),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1D20),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        return Column(
                          children: [
                            Row(
                              children:
                                  const ['Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat', 'Sun']
                                      .map(
                                        (d) => Expanded(
                                          child: Center(
                                            child: Text(
                                              d,
                                              maxLines: 1,
                                              style: TextStyle(
                                                color: const Color(0xFF8E8E93),
                                                fontSize: 13.sp,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                            SizedBox(height: 14.h),
                            _buildWeekRow(weekCheckRow, totalWidth),
                            SizedBox(height: 12.h),
                            if (displayRows.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                child: Text(
                                  context.l10n.noStreakHistoryYet,
                                  style: sfProText400(14.sp, const Color(0xFFB0B3B8)),
                                ),
                              ),
                            ...displayRows.map(
                              (row) => Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: _buildWeekRow(row, totalWidth),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
