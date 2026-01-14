import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/core/widgets/custom_switch.dart';

import '../../controllers/Main Section Controllers/streak_controller.dart';
import 'Freeze_bottomsheet.dart';

class StreamStreakSetupBottomSheet extends StatelessWidget {
  const StreamStreakSetupBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StreamStreaksController());

    return Container(
      height: Get.height * 0.9,
      decoration: BoxDecoration(
        color: bottomSheetGrey,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Stack(
        children: [
          Column(
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
                      style: sfProText600(17.sp, Colors.white),
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
                      SizedBox(height: 20.h),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0XFFFFE6A7).withOpacity(0.2),
                              blurRadius: 60,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/abc.png',
                        ),
                      ),
                      SizedBox(height: 12.h,),
                      Text("Build a long-term habit",
                      style: sfProDisplay600(22.sp, Colors.white),),
                      SizedBox(height: 4.h,),
                      Text("Settings a streak goals  helps you stay consistent",
                      style: sfProDisplay400(15.sp, Color(0xFFB0B3B8)),
                      textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      _buildDayToggles(controller),
                      SizedBox(height: 24.h),
                      _buildDivider(),
                      SizedBox(height: 24.h),
                      _buildThreeTimesOption(controller),
                      SizedBox(height: 100.h), // Extra space for scrolling
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

          /// INTERACTIVE MENU OVERLAY (NOW POPS UPWARDS FROM THE BOTTOM BAR)
          Obx(() {
            if (!controller.isSelectingThreeDays.value) {
              return const SizedBox.shrink();
            }

            return Positioned.fill(
              child: GestureDetector(
                onTap: () => controller.isSelectingThreeDays.value = false,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.transparent, // Capture taps to close
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 145.h, // Positioned right above the "3-times" bar
                        left: 40.w,   // Aligned with the indicator icon
                        child: Container(
                          width: 96.w,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(22.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ],
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...controller.selectedMenuNumbers.map(
                                    (n) => GestureDetector(
                                  onTap: () => controller.toggleMenuNumber(n),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6.h),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check,
                                            size: 18.sp, color: Colors.white),
                                        SizedBox(width: 6.w),
                                        Text(
                                          "$n",
                                          style: TextStyle(
                                            fontSize: 20.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (controller.selectedMenuNumbers.isNotEmpty) ...[
                                SizedBox(height: 12.h),
                                Container(
                                  height: 1,
                                  width: 40.w,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                SizedBox(height: 12.h),
                              ],
                              ...controller.availableMenuNumbers.map(
                                    (n) => GestureDetector(
                                  onTap: () => controller.toggleMenuNumber(n),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6.h),
                                    child: Text(
                                      "$n",
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        color: const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ),
                                ),
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
          }),
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

  Widget _buildThreeTimesOption(StreamStreaksController controller) {
    return Obx(() {
      final selected = controller.threeTimesWeek.value;
      return GestureDetector(
        onTap: () {
          controller.toggleThreeTimesWeek(!selected);
          // Toggle menu visibility when clicking the row
          if (!selected) {
            controller.isSelectingThreeDays.value = true;
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
                  Image.asset('assets/images/Pop-up Menu Indicator.png'),
                  SizedBox(width: 12.w),
                  Text(
                    '3-times a week',
                    style: sfProText400(
                        17.sp,
                        selected ? Colors.white : const Color(0xFF8E8E93)),
                  ),
                ],
              ),
              CustomSwitch(
                value: selected,
                onChanged: (val) {
                  controller.toggleThreeTimesWeek(val);
                  if(val) controller.isSelectingThreeDays.value = true;
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}