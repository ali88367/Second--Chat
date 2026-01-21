import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/core/widgets/custom_switch.dart';

import '../../controllers/Main Section Controllers/streak_controller.dart';
import '../../core/widgets/custom_black_glass_widget.dart';
import 'Freeze_bottomsheet.dart';

class StreamStreakSetupBottomSheet extends StatefulWidget {
  const StreamStreakSetupBottomSheet({super.key});

  @override
  State<StreamStreakSetupBottomSheet> createState() => _StreamStreakSetupBottomSheetState();
}

class _StreamStreakSetupBottomSheetState extends State<StreamStreakSetupBottomSheet> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );

    _opacityAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StreamStreaksController(), permanent: true);

    return Container(
      height: Get.height * 0.9,
      decoration: BoxDecoration(
        color: bottomSheetGrey,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 12.h),
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
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.close, color: Colors.white, size: 44.h),
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
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  // Glow and Image Stack moved here to scroll together
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // ANIMATED FIRE GLOW
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 150.h,
                              height: 150.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0XFFFFE6A7).withOpacity(_opacityAnimation.value),
                                    blurRadius: 50,
                                    spreadRadius: 20,
                                  ),
                                  BoxShadow(
                                    color: const Color(0XFFF2B269).withOpacity(_opacityAnimation.value * 0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // FIRE IMAGE
                      Image.asset(
                        'assets/images/abc.png',
                        height: 177.h,
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    "Build a long-term habit",
                    style: sfProDisplay600(22.sp, Colors.white),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Setting a streak goals  helps you stay consistent",
                    style: sfProDisplay400(15.sp, const Color(0xFFB0B3B8)),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 14.h),
                  _buildDayToggles(controller),
                  SizedBox(height: 14.h),
                  _buildDivider(),
                  SizedBox(height: 10.h),
                  _buildThreeTimesOption(controller, context),
                  SizedBox(height: 100.h),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
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

  Widget _buildThreeTimesOption(StreamStreaksController controller, BuildContext context) {
    final indicatorKey = GlobalKey();

    return Obx(() {
      final selected = controller.threeTimesWeek.value;
      return GestureDetector(
        onTap: () {
          controller.toggleThreeTimesWeek(!selected);
          if (!selected) {
            controller.isSelectingThreeDays.value = true;
            Future.delayed(const Duration(milliseconds: 50), () {
              _showGlassmorphicPopupMenu(context, indicatorKey, controller);
            });
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
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    '3-times a week',
                    style: sfProText400(
                      17.sp,
                      selected ? Colors.white : const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
              CustomSwitch(
                value: selected,
                onChanged: (val) {
                  controller.toggleThreeTimesWeek(val);
                  if (val) {
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _showGlassmorphicPopupMenu(context, indicatorKey, controller);
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
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final RenderBox? button = indicatorKey.currentContext?.findRenderObject() as RenderBox?;

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
              top: buttonPosition.dy - 290.h - 8.h,
              right: overlay.size.width - buttonPosition.dx - 64.w,
              child: Material(
                color: Colors.transparent,
                child: CustomBlackGlassWidget(
                  isWeek: true,
                  items: List.generate(7, (i) => '${i + 1}'),
                  onItemSelected: (selected) {
                    final selectedNumber = int.parse(selected);
                    controller.toggleMenuNumber(selectedNumber);
                    if (controller.selectedMenuNumbers.length >= 3) {
                      Navigator.of(context).pop();
                      controller.isSelectingThreeDays.value = false;
                    }
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
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }
}