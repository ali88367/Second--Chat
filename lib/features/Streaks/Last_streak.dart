import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';

class StreakFreezeUseBottomSheet extends StatelessWidget {
  const StreakFreezeUseBottomSheet({super.key});

  static const int days = 7;
  static const double horizontalPadding = 12;
  static const double rowHeight = 32;

  // ---------------- ICONS ----------------

  Widget _tick({bool highlighted = false}) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: highlighted ? const BoxDecoration(color: Colors.white, shape: BoxShape.circle) : null,
      child: Icon(
        Icons.check,
        size: 18.sp,
        color: highlighted ? const Color(0xFFFDB747) : Colors.white,
      ),
    );
  }

  Widget _cross() => Icon(Icons.close, color: const Color(0xFF8E8E93), size: 22.sp);

  // ---------------- LAYOUT HELPERS ----------------

  Widget _highlight(int start, int end, double totalWidth) {
    final int count = end - start + 1;
    final double cellWidth = totalWidth / days;

    Decoration decoration;
    if (count >= 3) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7EDDE4), Color(0xFFC5F3F1)]),
        borderRadius: BorderRadius.circular(22.r),
      );
    } else if (count == 1) {
      // Perfect circle for single selection
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
        // Remove horizontal margin for circles to keep them centered
        margin: count == 1 ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: 2.w),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: Column(
                    children: [
                      SizedBox(height: 12.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(onTap: Get.back, child: Image.asset('assets/icons/x_icon.png', height: 44.h)),

                          ],
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Adjusted Glow Effect
                          Container(
                            width: 300.w,  // Narrower than height to match the flame's vertical profile
                            height: 240.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.all(Radius.elliptical(70.w, 110.h)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7EDDE4).withOpacity(0.35), // Soft pale yellow
                                  blurRadius: 200, // Spread the glow out
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFC5F3F1).withOpacity(0.2), // Inner warm glow
                                  blurRadius: 40,
                                  spreadRadius: -10,
                                ),
                              ],
                            ),
                          ),

                          // 2. The Flame Image
                          Image.asset(
                            'assets/images/hello.png',
                            // Ensure fit is contain to keep original proportions
                          ),

                          // 3. The Number Image
                          Positioned(
                            bottom: 10.h,
                            child: Image.asset(
                              'assets/images/Streak number.png',width: 155.w,height: 120.h
                            ),
                          ),
                        ],
                      ),                      Text("Go ahead, freeze it. Commitment is overrated anyway.",
                        style: sfProDisplay600(18.sp, Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
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
                            Image.asset("assets/images/checkmark.circle.fill.png",width: 19.w,height: 24.h),
                            SizedBox(width: 8.w),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                      text: '3 ',
                                      style: sfProDisplay400(15.sp, Colors.white)
                                  ),
                                  TextSpan(
                                      text: 'available',
                                      style: sfProDisplay400(15.sp, const Color(0xFFB0B3B8))
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // --- CALENDAR CARD ---
                      Container(
                        width: 361.w,
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding.w, vertical: 16.h),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1E1D20),
                            borderRadius: BorderRadius.circular(24.r)
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: ['Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat', 'Sun'].map((day) {
                                return Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
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
                                      final rowData = controller.singleRowCells;
                                      final groups = controller.getTickGroups(rowData);
                                      return Stack(
                                        children: [
                                          for (final g in groups) _highlight(g[0], g[1], totalWidth),
                                          Row(
                                            children: List.generate(days, (i) {
                                              final cell = rowData[i];
                                              final isLatest = controller.lastTappedCol.value == i;
                                              return Expanded(
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () => controller.toggleCalendarCell(0, i, isSingleRow: true),
                                                  child: Center(
                                                    child: cell == CellType.tick ? _tick(highlighted: isLatest) : _cross(),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ],
                                      );
                                    }),
                                  );
                                }
                            ),
                            SizedBox(height: 12.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- BOTTOM ACTION AREA ---
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
                            backgroundColor: const Color(0xFF2C2C2E),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
                          ),
                          child: Text("Ignore", style: sfProText600(17.sp, Colors.white.withOpacity(0.8))),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        height: 50.h,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: Get.back,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7EDDE4),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Use 1 ", style: sfProText600(17.sp, Colors.white)),
                              Image.asset('assets/images/Mask group.png'),
                            ],
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
  }
}