import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/core/widgets/custom_switch.dart';

import '../../3timewidget.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';
import 'Freeze_bottomsheet.dart';

class StreamStreakSetupBottomSheet extends StatefulWidget {
  const StreamStreakSetupBottomSheet({super.key});

  @override
  State<StreamStreakSetupBottomSheet> createState() =>
      _StreamStreakSetupBottomSheetState();
}

class _StreamStreakSetupBottomSheetState
    extends State<StreamStreakSetupBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _frameController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _framesPreloaded = false;

  static const int totalFrames = 119; // Frames from 0001 to 0119

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Frame animation controller - loops continuously forward
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 3000,
      ), // Adjust duration for animation speed
    );

    // Start animation and ensure it loops continuously from start
    // repeat() automatically handles looping, no need to call forward() separately
    _frameController.repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );

    _opacityAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload first few frames when context is available
    if (!_framesPreloaded) {
      _preloadInitialFrames();
      _framesPreloaded = true;
    }
  }

  void _preloadInitialFrames() {
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
    _glowController.dispose();
    _frameController.dispose();
    super.dispose();
  }

  // Widget for the drag handle (bottom sheet bar) - ALREADY PRESENT
  Widget _buildDragHandle() {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
      child: Center(
        child: Container(
          width: 50.w, // Common width for a grabber
          height: 4.h, // Common height for a grabber
          decoration: BoxDecoration(
            color: const Color(0xFF48484A), // Medium dark grey for visibility
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StreamStreaksController());

    return Container(
      height: Get.height * 0.9,
      decoration: BoxDecoration(
        color: bottomSheetGrey,
        // Visible border radius
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(38.r),
          topRight: Radius.circular(38.r),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(38.r)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Scrollable Content
              SingleChildScrollView(
                // This physics is key for allowing drag down when scrolled to top
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(bottom: 100.h),
                child: Column(
                  children: [
                    _buildDragHandle(), // Placement at the top enables swipe-down dismissal
                    // Top App Bar Area
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              controller.isSelectingThreeDays.value = false;
                              controller.threeTimesWeek.value = false;
                              controller.selectedMenuNumbers.clear();
                              Get.back();
                            },
                            child: Image.asset(
                              'assets/icons/x_icon.png',
                              height: 44.h,
                              errorBuilder:
                                  (_, __, ___) => Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 44.h,
                                  ),
                            ),
                          ),
                          Text(
                            "Stream Streaks",
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 44.w),
                        ],
                      ),
                    ),

                    // Main Graphic and Text Section
                    SizedBox(height: 10.h),
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _glowController,
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
                            clipBehavior: Clip.none,
                            children: [
                              Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  width: 150.h,
                                  height: 150.h,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0XFFFFE6A7,
                                        ).withOpacity(_opacityAnimation.value),
                                        blurRadius: 50,
                                        spreadRadius: 20,
                                      ),
                                      BoxShadow(
                                        color: const Color(
                                          0XFFF2B269,
                                        ).withOpacity(
                                          _opacityAnimation.value * 0.5,
                                        ),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Image.asset(
                                'assets/FIreAnimation2/frame_lq_$frameNumber.png',
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
                      "Build a long-term habit",
                      style: sfProDisplay600(22.sp, Colors.white),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Setting streak goals  helps you stay consistent",
                      style: sfProDisplay400(15.sp, const Color(0xFFB0B3B8)),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h), // Adjusted spacing
                    // Toggles Section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        children: [
                          _buildDayToggles(controller),
                          SizedBox(height: 14.h),
                          _buildDivider(),
                          SizedBox(height: 10.h),
                          _buildThreeTimesOption(controller, context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Fixed Bottom Button
              Positioned(
                left: 16.w,
                right: 16.w,
                bottom: 16.h,
                child: SizedBox(
                  height: 50.h,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      Get.bottomSheet(
                        const StreakFreezePreviewBottomSheet(),
                        isScrollControlled: true,
                        ignoreSafeArea: false,
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
                      "Next",
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

  Widget _buildDayToggles(StreamStreaksController controller) {
    final days = controller.selectedDays.keys.toList();
    return Column(
      children: [
        _row(controller, days[0], days[1]),
        SizedBox(height: 16.h),
        _row(controller, days[2], days[3]),
        SizedBox(height: 16.h),
        _row(controller, days[4], days[5]),
        SizedBox(height: 16.h),
        _toggle(controller, days[6]),
      ],
    );
  }

  Widget _row(StreamStreaksController c, String d1, String d2) {
    return Row(
      children: [
        Expanded(child: _toggle(c, d1)),
        SizedBox(width: 16.w),
        Expanded(child: _toggle(c, d2)),
      ],
    );
  }

  Widget _toggle(StreamStreaksController c, String day) {
    return Obx(() {
      final selected = c.selectedDays[day]!;
      final disabled = c.areDaysDisabled;

      return AnimatedOpacity(
        opacity: disabled ? 0.4 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 52.h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: sfProText400(
                  17.sp,
                  selected ? Colors.white : const Color(0xFF8E8E93),
                ),
              ),
              CustomSwitch(
                value: selected,
                onChanged: disabled ? null : (_) => c.toggleDay(day),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFF2C2C2E))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'OR',
            style: sfProText400(13.sp, const Color(0xFF8E8E93)),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFF2C2C2E))),
      ],
    );
  }

  Widget _buildThreeTimesOption(
    StreamStreaksController controller,
    BuildContext context,
  ) {
    final indicatorKey = GlobalKey();

    return Obx(() {
      final selected = controller.threeTimesWeek.value;
      return GestureDetector(
        onTap: () {
          if (!selected) {
            controller.toggleThreeTimesWeek(true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                _showGlassmorphicPopupMenu(context, indicatorKey, controller);
            });
          } else {
            controller.toggleThreeTimesWeek(false);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/Pop-up Menu Indicator.png',
                    key: indicatorKey,
                    color: selected ? Colors.white : Colors.grey,
                  ),
                  SizedBox(width: 12.w),
                  Obx(() {
                    final count = controller.selectedMenuNumbers.length;
                    final displayCount = count >= 3 ? count : 3;
                    return Text(
                      '$displayCount-times a week',
                      style: sfProText400(
                        17.sp,
                        selected ? Colors.white : const Color(0xFF8E8E93),
                      ),
                    );
                  }),
                ],
              ),
              CustomSwitch(
                value: selected,
                onChanged: (val) {
                  controller.toggleThreeTimesWeek(val);
                  if (val) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted)
                        _showGlassmorphicPopupMenu(
                          context,
                          indicatorKey,
                          controller,
                        );
                    });
                  }
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showGlassmorphicPopupMenu(
    BuildContext context,
    GlobalKey indicatorKey,
    StreamStreaksController controller,
  ) {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final RenderBox? button =
        indicatorKey.currentContext?.findRenderObject() as RenderBox?;

    if (button == null || overlay == null) return;

    final Offset buttonPosition = button.localToGlobal(Offset.zero);

    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: buttonPosition.dy - 340.h,
              left: buttonPosition.dx - 20.w,
              child: Material(
                color: Colors.transparent,
                child: CCustomBlackGlassWidget(
                  isWeek: true,
                  items: List.generate(7, (i) => '${i + 1}'),
                  onItemSelected: (selected) {
                    // Real-time sync is now handled in controller
                    // Popup stays open for user to select 3-7 days
                  },
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    ).then((_) {
      // When popup closes, clear selections if less than 3 were selected
      controller.clearSelectionsIfBelow3();
    });
  }
}
