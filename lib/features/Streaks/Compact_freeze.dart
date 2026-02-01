import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/features/Streaks/Last_streak.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';

class StreakFreezeSingleRowPreviewBottomSheet extends StatefulWidget {
  const StreakFreezeSingleRowPreviewBottomSheet({super.key});

  @override
  State<StreakFreezeSingleRowPreviewBottomSheet> createState() => _StreakFreezeSingleRowPreviewBottomSheetState();
}

class _StreakFreezeSingleRowPreviewBottomSheetState extends State<StreakFreezeSingleRowPreviewBottomSheet> with TickerProviderStateMixin {
  late AnimationController _fireController;
  late AnimationController _frameController;
  late Animation<double> _glowPulse;
  late Animation<double> _fireJitter;
  bool _framesPreloaded = false;

  static const int days = 7;
  static const double horizontalPadding = 12;
  static const double rowHeight = 32;
  static const int totalFrames = 119; // Frames from 0001 to 0119

  @override
  void initState() {
    super.initState();
    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Frame animation controller - loops continuously forward
    // Optimized duration for smoother playback
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), // Slightly faster for smoother feel
    );
    // repeat() automatically handles looping and starts the animation
    _frameController.repeat();

    _glowPulse = Tween<double>(begin: 0.2, end: 0.45).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.easeInOutSine),
    );

    _fireJitter = Tween<double>(begin: 0.0, end: -8.h).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.bounceIn),
    );
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

  Widget _cross() => Icon(Icons.close, color: const Color(0xFF8E8E93), size: 22.sp);
  Widget _freeze() => Image.asset('assets/images/Mask group.png');

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

  Widget _row(StreamStreaksController c, double totalWidth) {
    // Obx removed to keep it static
    final rowData = c.singleRowCells;
    final groups = c.getTickGroups(rowData);

    return SizedBox(
      height: rowHeight.h,
      child: Stack(
        children: [
          for (final g in groups) _highlight(g[0], g[1], totalWidth),
          Row(
            children: List.generate(days, (i) {
              final cell = rowData[i];
              final isLast = c.lastTappedCol.value == i;

              Widget icon;
              switch (cell) {
                case CellType.tick:
                  icon = _tick(highlighted: isLast);
                  break;
                case CellType.cross:
                  icon = _cross();
                  break;
                case CellType.freeze:
                  icon = _freeze();
                  break;
                case CellType.dot:
                  icon = const SizedBox();
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
    final controller = Get.put(StreamStreaksController(), permanent: true);
    return Container(
      height: Get.height * 0.9,
      decoration: BoxDecoration(
        color: bottomSheetGrey,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          bottomSheet: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            color: bottomSheetGrey,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 50.h,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    Get.bottomSheet(
                      const StreakFreezeUseBottomSheet(),
                      isScrollControlled: true,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36.r),
                    ),
                  ),
                  child: Text("Done", style: sfProText600(17.sp, Colors.black)),
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 80.h),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => Get.back(),
                        child: Image.asset('assets/icons/x_icon.png', height: 44.h),
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
                      int frame = ((animValue * totalFrames).round() % totalFrames);
                      frame = (frame == 0 ? totalFrames : frame).clamp(1, totalFrames);
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
                                  color: const Color(0xFFFFF9C4).withOpacity(_glowPulse.value),
                                  blurRadius: 180,
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFFDEBB2).withOpacity(_glowPulse.value * 0.6),
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
                              cacheWidth: (255.w * MediaQuery.of(context).devicePixelRatio).round(),
                              cacheHeight: (255.h * MediaQuery.of(context).devicePixelRatio).round(),
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
                            child: Image.asset(
                              'assets/images/Streak number.png',
                              width: 155.w,
                              height: 100.h,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(height: 10.h),

                Text("Day Streak", style: sfProDisplay600(34.sp, Colors.white)),
                Text(
                  "You’ve never been hotter, keep the streak burning!",
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
                            ['Mon','Tue','Wed','Thur','Fri','Sat','Sun'].map((d) {
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
                          _row(controller, totalWidth),
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