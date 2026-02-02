import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';

class StreakFreezeUseBottomSheet extends StatefulWidget {
  const StreakFreezeUseBottomSheet({super.key});

  @override
  State<StreakFreezeUseBottomSheet> createState() =>
      _StreakFreezeUseBottomSheetState();
}

class _StreakFreezeUseBottomSheetState extends State<StreakFreezeUseBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _freezeController;
  late AnimationController _frameController;
  late Animation<double> _glowAnimation;
  late Animation<double> _floatAnimation;
  bool _framesPreloaded = false;

  static const int days = 7;
  static const double horizontalPadding = 12;
  static const double rowHeight = 32;
  static const int totalFrames = 95; // Frames from 0001 to 0095

  @override
  void initState() {
    super.initState();
    _freezeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // Frame animation controller - loops continuously forward
    // Optimized duration for smoother playback (32ms per frame for 95 frames ≈ 3000ms)
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 2500,
      ), // Slightly faster for smoother feel
    );
    // repeat() automatically handles looping and starts the animation
    _frameController.repeat();

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.4).animate(
      CurvedAnimation(parent: _freezeController, curve: Curves.easeInOutSine),
    );

    _floatAnimation = Tween<double>(begin: 0, end: -10.h).animate(
      CurvedAnimation(parent: _freezeController, curve: Curves.easeInOutQuad),
    );
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
    _freezeController.dispose();
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
  Widget _freeze() =>
      Image.asset('assets/images/Privacy & Security - SVG.png', width: 22.sp);
  Widget _dot() => Opacity(
    opacity: 0.3,
    child: Icon(Icons.circle, size: 10.sp, color: Colors.white),
  );

  Widget _highlight(int start, int end, double totalWidth) {
    final int count = end - start + 1;
    final double cellWidth = totalWidth / days;

    Decoration decoration;
    if (count >= 3) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7EDDE4), Color(0xFFC5F3F1)],
        ),
        borderRadius: BorderRadius.circular(22.r),
      );
    } else {
      decoration = BoxDecoration(
        color: const Color(0xFF3C3C43).withOpacity(0.6),
        borderRadius: BorderRadius.circular(22.r),
        shape: count == 1 ? BoxShape.circle : BoxShape.rectangle,
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

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StreamStreaksController>();

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
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  // Key to fixing the swipe-down issue: Use BouncingScrollPhysics
                  // and ensure the drag handle is the first element.
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: Column(
                    children: [
                      _buildDragHandle(), // ADDED: Drag handle (bottom sheet bar)
                      // SizedBox(height: 12.h), // Removed/Adjusted
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: Get.back,
                              child: Image.asset(
                                'assets/icons/x_icon.png',
                                height: 44.h,
                              ),
                            ),
                          ],
                        ),
                      ),
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _freezeController,
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
                                  width: 300.w,
                                  height: 240.h,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.all(
                                      Radius.elliptical(70.w, 110.h),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF7EDDE4,
                                        ).withOpacity(_glowAnimation.value),
                                        blurRadius: 180,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(0, _floatAnimation.value),
                                  child: Image.asset(
                                    'assets/FrozenFire/frame_$frameNumber.png',
                                    height: 250.h,
                                    width: 250.w,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                    // Optimized cache dimensions for exact size
                                    cacheWidth: (250.w * MediaQuery.of(context).devicePixelRatio).round(),
                                    cacheHeight: (250.h * MediaQuery.of(context).devicePixelRatio).round(),
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 250.h,
                                        width: 250.w,
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
                                    height: 90.h,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Text(
                        "Go ahead, freeze it. Commitment is \noverrated anyway.",
                        style: sfProDisplay600(22.sp, Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      Obx(() {
                        final available =
                            3 - controller.manualFreezeCount.value;
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF32393D),
                            borderRadius: BorderRadius.circular(40.r),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
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
                                      text: '$available ',
                                      style: sfProDisplay400(
                                        15.sp,
                                        Colors.white,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'available',
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
                        );
                      }),
                      SizedBox(height: 20.h),
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
                        child: Column(
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
                              ].map((day) {
                                return Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
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
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final totalWidth = constraints.maxWidth;
                                return SizedBox(
                                  height: rowHeight.h,
                                  child: Obx(() {
                                    // Watching singleRowCells for changes
                                    final rowData = controller.singleRowCells;
                                    final groups = controller.getTickGroups(
                                      rowData,
                                    );
                                    return Stack(
                                      children: [
                                        for (final g in groups)
                                          _highlight(g[0], g[1], totalWidth),
                                        Row(
                                          children: List.generate(days, (i) {
                                            final cell = rowData[i];
                                            final isLatest =
                                                controller
                                                    .lastTappedCol
                                                    .value ==
                                                    i;
                                            Widget icon;
                                            switch (cell) {
                                              case CellType.tick:
                                                icon = _tick(
                                                  highlighted: isLatest,
                                                );
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
                                              child: Center(child: icon),
                                            );
                                          }),
                                        ),
                                      ],
                                    );
                                  }),
                                );
                              },
                            ),
                            SizedBox(height: 12.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                color: bottomSheetGrey,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 50.h,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: Get.back,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(116, 116, 128, 0.18),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          child: Text(
                            "Ignore",
                            style: sfProText600(
                              17.sp,
                              Color.fromRGBO(235, 235, 245, 0.3),

                            ),
                            textHeightBehavior: TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        height: 50.h,
                        width: double.infinity,
                        child: Obx(() {
                          final canFreeze =
                              (3 - controller.manualFreezeCount.value) > 0;
                          return ElevatedButton(
                            onPressed: canFreeze
                                ? () {
                              controller.addFreezeAfterStreak();
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canFreeze
                                  ? const Color(0xFF7EDDE4)
                                  : Colors.grey.withOpacity(0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Use 1 ",
                                  style: sfProText600(17.sp, Colors.white),
                                ),
                                Image.asset('assets/images/Mask group.png'),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
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