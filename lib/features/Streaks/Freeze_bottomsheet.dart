import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';
// Ensure this path is correct for your project
import 'Compact_freeze.dart';

class StreakFreezePreviewBottomSheet extends StatefulWidget {
  const StreakFreezePreviewBottomSheet({super.key});

  @override
  State<StreakFreezePreviewBottomSheet> createState() => _StreakFreezePreviewBottomSheetState();
}

class _StreakFreezePreviewBottomSheetState extends State<StreakFreezePreviewBottomSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  static const int days = 7;
  static const double horizontalPadding = 12;
  static const double rowHeight = 32;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.1, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _tick({bool highlighted = false}) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: highlighted ? const BoxDecoration(color: Colors.white, shape: BoxShape.circle) : null,
      child: Icon(Icons.check, size: 18.sp, color: highlighted ? const Color(0xFFFDB747) : Colors.white),
    );
  }

  Widget _cross() => Icon(Icons.close, color: const Color(0xFF8E8E93), size: 22.sp);
  Widget _freeze() => Image.asset('assets/images/Privacy & Security - SVG.png', width: 22.sp);
  Widget _dot() => Opacity(opacity: 0.3, child: Icon(Icons.circle, size: 10.sp, color: Colors.white));

  Widget _highlight(int start, int end, double totalWidth) {
    final int count = end - start + 1;
    final double cellWidth = totalWidth / days;
    final bool isCircle = count == 1; // Check if it's a single day

    return Positioned(
      left: start * cellWidth,
      width: count * cellWidth,
      top: 0,
      bottom: 0,
      child: Container(
        margin: isCircle ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: 2.w),
        decoration: BoxDecoration(
          color: count >= 3 ? null : const Color(0xFF3C3C43).withOpacity(0.6),
          gradient: count >= 3 ? const LinearGradient(colors: [Color(0xFFF2B269), Color(0xFFFFE6A7)]) : null,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          // FIX: BorderRadius MUST be null if shape is BoxShape.circle
          borderRadius: isCircle ? null : BorderRadius.circular(22.r),
        ),
      ),
    );
  }

  Widget _row(int rowIndex, StreamStreaksController c, double totalWidth) {
    final rowData = c.calendarRows[rowIndex];
    final groups = c.getTickGroups(rowData);
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
                case CellType.tick: icon = _tick(); break;
                case CellType.cross: icon = _cross(); break;
                case CellType.freeze: icon = _freeze(); break;
                case CellType.dot: icon = _dot(); break;
              }
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => c.toggleCalendarCell(rowIndex, i),
                  child: Center(child: icon),
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
    final controller = Get.put(StreamStreaksController());

    return Container(
      height: Get.height * 0.9,
      decoration: BoxDecoration(color: bottomSheetGrey, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(bottom: 100.h),
                child: Column(
                  children: [
                    SizedBox(height: 12.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(onTap: Get.back, child: Image.asset('assets/icons/x_icon.png', height: 44.h)),
                          Text("Stream Streaks", style: sfProText600(17.sp, Colors.white)),
                          SizedBox(width: 44.w),
                        ],
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: 140.h, height: 140.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: const Color(0XFF84DEE4).withOpacity(_opacityAnimation.value), blurRadius: 55, spreadRadius: 15),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Image.asset('assets/images/a1.png', height: 177.h),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text("Streak in danger?\nHit the Freeze button!", textAlign: TextAlign.center, style: sfProDisplay600(22.sp, Colors.white)),
                    SizedBox(height: 6.h),

                    // Static Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF32393D),
                        borderRadius: BorderRadius.circular(40.r),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset("assets/images/checkmark.circle.fill.png", width: 19.w, height: 24.h),
                          SizedBox(width: 8.w),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: '3 ', style: sfProDisplay400(15.sp, Colors.white)),
                                TextSpan(text: 'freezes per month', style: sfProDisplay400(15.sp, const Color(0xFFB0B3B8))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),
                    // Wrapped the whole calendar area in Obx
                    Obx(() {
                      // Accessing this variable prevents the "Improper Use" red screen
                      controller.refreshTrigger.value;

                      return Container(
                        width: 361.w,
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding.w, vertical: 16.h),
                        decoration: BoxDecoration(color: const Color(0xFF1E1D20), borderRadius: BorderRadius.circular(24.r)),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final totalWidth = constraints.maxWidth;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: ['Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat', 'Sun'].map((d) {
                                    return Expanded(child: Center(child: Text(d, style: TextStyle(color: const Color(0xFF8E8E93), fontSize: 13.sp))));
                                  }).toList(),
                                ),
                                SizedBox(height: 16.h),
                                for (int i = 0; i < controller.calendarRows.length; i++) ...[
                                  _row(i, controller, totalWidth),
                                  if (i != controller.calendarRows.length - 1) SizedBox(height: 12.h),
                                ],
                              ],
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Positioned(
                left: 16.w, right: 16.w, bottom: 16.h,
                child: SizedBox(
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      Get.bottomSheet(const StreakFreezeSingleRowPreviewBottomSheet(), isScrollControlled: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36.r)),
                    ),
                    child: Text("Let's go", style: sfProText600(17.sp, Colors.black)),
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