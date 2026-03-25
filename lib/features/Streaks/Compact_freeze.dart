import 'package:dio/dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/core/localization/l10n.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';
import '../../controllers/auth_controller.dart';

class StreakFreezeSingleRowPreviewBottomSheet extends StatefulWidget {
  const StreakFreezeSingleRowPreviewBottomSheet({super.key});

  @override
  State<StreakFreezeSingleRowPreviewBottomSheet> createState() =>
      _StreakFreezeSingleRowPreviewBottomSheetState();
}

class _StreakFreezeSingleRowPreviewBottomSheetState
    extends State<StreakFreezeSingleRowPreviewBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _fireController;
  late AnimationController _frameController;
  late Animation<double> _glowPulse;
  late Animation<double> _fireJitter;
  bool _framesPreloaded = false;
  bool _isLoading = false;
  _StreakSnapshot? _streak;
  late List<CellType> _rowData;

  static const int days = 7;
  static const double horizontalPadding = 12;
  static const double rowHeight = 32;
  static const int totalFrames = 119; // Frames from 0001 to 0119

  @override
  void initState() {
    super.initState();
    _rowData = List.generate(days, (_) => CellType.cross);
    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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

    _glowPulse = Tween<double>(begin: 0.2, end: 0.45).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.easeInOutSine),
    );

    _fireJitter = Tween<double>(
      begin: 0.0,
      end: -8.h,
    ).animate(CurvedAnimation(parent: _fireController, curve: Curves.bounceIn));

    _loadStreak();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload frames when context is available
    if (!_framesPreloaded) {
      _preloadFireAnimation2Frames();
      _framesPreloaded = true;
    }
  }

  void _preloadFireAnimation2Frames() {
    // Preload first 30 frames immediately for instant display
    for (int i = 1; i <= 30 && i <= totalFrames; i++) {
      final frameNumber = i.toString().padLeft(4, '0');
      precacheImage(
        AssetImage('assets/FIreAnimation2/frame_lq_$frameNumber.png'),
        context,
      );
    }

    // Preload remaining frames in background
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        for (int i = 31; i <= totalFrames; i++) {
          final frameNumber = i.toString().padLeft(4, '0');
          precacheImage(
            AssetImage('assets/FIreAnimation2/frame_lq_$frameNumber.png'),
            context,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _fireController.dispose();
    _frameController.dispose();
    super.dispose();
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

  // ---------------- ICONS (Static) ----------------

  Widget _tick({bool highlighted = false}) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: highlighted
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
  Widget _freeze() => Image.asset('assets/images/Mask group.png');
  Widget _dot() => Opacity(
    opacity: 0.3,
    child: Icon(Icons.circle, size: 10.sp, color: Colors.white),
  );

  // ---------------- LAYOUT HELPERS ----------------

  Widget _highlight(int start, int end, double totalWidth) {
    final int count = end - start + 1;
    final double cellWidth = totalWidth / days;

    Decoration decoration;
    if (count >= 3) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2B269), Color(0xFFFFE6A7)],
        ),
        borderRadius: BorderRadius.circular(22.r),
      );
    } else if (count == 1) {
      decoration = BoxDecoration(
        color: const Color(0xFF3C3C43).withOpacity(0.6),
        shape: BoxShape.circle,
      );
    } else {
      decoration = BoxDecoration(
        color: const Color(0xFF3C3C43).withOpacity(0.6),
        borderRadius: BorderRadius.circular(22.r),
      );
    }

    return Positioned(
      left: start * cellWidth,
      width: count * cellWidth,
      top: 0,
      bottom: 0,
      child: Container(
        margin: count == 1
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(horizontal: 2.w),
        decoration: decoration,
      ),
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

  Future<void> _loadStreak() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
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
      final snapshot = _StreakSnapshot.fromPayload(res.data);
      _applySnapshot(snapshot);
    } on DioException catch (e) {
      debugPrint('STREAK LOAD ERROR: ${e.response?.data ?? e.message}');
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
      _rowData = _buildRow(snapshot);
    });
  }

  List<CellType> _buildRow(_StreakSnapshot snapshot) {
    const ordered = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final selected = snapshot.selectedDays
        .map((d) => d.toLowerCase().trim())
        .where((d) => d.isNotEmpty)
        .toSet();
    int completed = snapshot.completedThisWeek;

    return ordered.map((day) {
      if (selected.contains(day)) {
        if (completed > 0) {
          completed--;
          return CellType.tick;
        }
        return CellType.dot;
      }
      return CellType.cross;
    }).toList();
  }

  Widget _row(List<CellType> rowData, double totalWidth) {
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

              return Expanded(
                child: Center(child: icon), // GestureDetector logic removed
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final longestStreak = _streak?.longestStreak ?? 0;
    return Container(
      height: Get.height * 0.91,
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
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36.r),
                    ),
                    padding: EdgeInsets.zero,
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
              bottom: 80.h + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Column(
              children: [
                _buildDragHandle(), // ADDED: Drag handle (bottom sheet bar)
                // SizedBox(height: 12.h), // Removed/Adjusted for drag handle
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => Get.back(),
                        child: Image.asset(
                          'assets/icons/x_icon.png',
                          height: 44.h,
                        ),
                      ),
                      SizedBox(width: 44.w),
                    ],
                  ),
                ),

                // --- ANIMATED FIRE SECTION ---
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _fireController,
                      _frameController,
                    ]),
                    builder: (context, child) {
                      // Optimized frame calculation using round() for smoother transitions
                      double animValue = _frameController.value.clamp(0.0, 1.0);
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
                          Container(
                            width: 200.w,
                            height: 240.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.all(
                                Radius.elliptical(70.w, 110.h),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFFF9C4,
                                  ).withOpacity(_glowPulse.value),
                                  blurRadius: 180,
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFFFDEBB2,
                                  ).withOpacity(_glowPulse.value * 0.6),
                                  blurRadius: 40,
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(0, _fireJitter.value),
                            child: Image.asset(
                              'assets/FIreAnimation2/frame_lq_$frameNumber.png',
                              height: 255.h,
                              width: 255.w,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              // Optimized cache dimensions for exact size
                              cacheWidth:
                                  (255.w *
                                          MediaQuery.of(
                                            context,
                                          ).devicePixelRatio)
                                      .round(),
                              cacheHeight:
                                  (255.h *
                                          MediaQuery.of(
                                            context,
                                          ).devicePixelRatio)
                                      .round(),
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 255.h,
                                  width: 255.w,
                                  color: Colors.transparent,
                                );
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 0.h,
                            child: SizedBox(
                              width: 155.w,
                              height: 100.h,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/Streak number.png',
                                    width: 155.w,
                                    height: 100.h,
                                    fit: BoxFit.contain,
                                  ),
                                  Text(
                                    '$longestStreak',
                                    style: sfProDisplay600(
                                      40.sp,
                                      const Color(0xFF1E1D20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(height: 10.h),

                Text(
                  context.l10n.dayStreak,
                  style: sfProDisplay600(34.sp, Colors.white),
                ),
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
                Text(
                  context.l10n.youVeNeverBeenHotterKeepStreakBurning,
                  style: sfProDisplay400(15.sp, const Color(0xFFB0B3B8)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),

                // --- CALENDAR CARD (Static) ---
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
                            children:
                                [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thur',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ].map((d) {
                                  return Expanded(
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
                                  );
                                }).toList(),
                          ),
                          SizedBox(height: 16.h),
                          _row(_rowData, totalWidth),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(height: 40.h),
              ],
            ),
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
    required this.completedThisWeek,
  });

  final int currentStreak;
  final int longestStreak;
  final List<String> selectedDays;
  final int completedThisWeek;

  factory _StreakSnapshot.empty() => const _StreakSnapshot(
        currentStreak: 0,
        longestStreak: 0,
        selectedDays: <String>[],
        completedThisWeek: 0,
      );

  factory _StreakSnapshot.fromPayload(dynamic payload) {
    dynamic data = payload;
    if (data is Map && data['data'] != null) {
      data = data['data'];
    }
    if (data is Map) {
      return _StreakSnapshot(
        currentStreak: _asInt(data['currentStreak']),
        longestStreak: _asInt(data['longestStreak']),
        selectedDays: _asStringList(data['selectedDays']),
        completedThisWeek: _asInt(data['completedThisWeek']),
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

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim().toLowerCase())
          .map((e) => e == 'thur' ? 'thu' : e)
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
