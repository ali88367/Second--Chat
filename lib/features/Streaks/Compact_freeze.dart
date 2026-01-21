import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/features/Streaks/Last_streak.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';

class StreakFreezeSingleRowPreviewBottomSheet extends StatelessWidget {
  const StreakFreezeSingleRowPreviewBottomSheet({super.key});

  static const int days = 7;
  static const double horizontalPadding = 12;
  static const double rowHeight = 32;

  // ---------------- ICONS ----------------

  Widget _tick({bool highlighted = false}) {
    return AnimatedScale(
      scale: highlighted ? 1.05 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: highlighted
            ? const BoxDecoration(color: Colors.white, shape: BoxShape.circle)
            : null,
        child: Icon(
          Icons.check,
          size: 18.sp,
          color: highlighted ? const Color(0xFFFDB747) : Colors.white,
        ),
      ),
    );
  }

  Widget _cross() =>
      Icon(Icons.close, color: const Color(0xFF8E8E93), size: 22.sp);
  Widget _freeze() =>
      Icon(Icons.ac_unit, color: Colors.cyanAccent, size: 26.sp);

  // ---------------- LAYOUT HELPERS ----------------

  Widget _highlight(int start, int end, double totalWidth) {
    final int count = end - start + 1;
    final double cellWidth = totalWidth / days;

    // Logic for perfect circle vs rounded bar
    Decoration decoration;
    if (count >= 3) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2B269), Color(0xFFFFE6A7)],
        ),
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
        margin: count == 1
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(horizontal: 2.w),
        decoration: decoration,
      ),
    );
  }

  Widget _row(StreamStreaksController c, double totalWidth) {
    return Obx(() {
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
                final tappable =
                    cell == CellType.tick || cell == CellType.cross;

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
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: tappable
                        ? () => c.toggleCalendarCell(0, i, isSingleRow: true)
                        : null,
                    child: Center(child: icon),
                  ),
                );
              }),
            ),
          ],
        ),
      );
    });
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
          bottomSheet: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            color: bottomSheetGrey,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 50.h,
                child: ElevatedButton(
                  onPressed: (){
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
                        onTap: Get.back,
                        child: Image.asset(
                          'assets/icons/x_icon.png',
                          height: 44.h,
                        ),
                      ),
                      SizedBox(width: 44.w),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Adjusted Glow Effect
                    Container(
                      width: 200
                          .w, // Narrower than height to match the flame's vertical profile
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
                            ).withOpacity(0.35), // Soft pale yellow
                            blurRadius: 200, // Spread the glow out
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFFFDEBB2,
                            ).withOpacity(0.2), // Inner warm glow
                            blurRadius: 40,
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                    ),

                    // 2. The Flame Image
                    Image.asset(
                      'assets/images/foire.png',
                      height: 255.h,
                      // Ensure fit is contain to keep original proportions
                      fit: BoxFit.contain,
                    ),

                    // 3. The Number Image
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
                ),
                Text("Day Streak", style: sfProDisplay600(34.sp, Colors.white)),
                Text(
                  "You’ve never been hotter, keep the streak burning!",
                  style: sfProDisplay400(15.sp, const Color(0xFFB0B3B8)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),

                // --- CALENDAR CARD ---
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
