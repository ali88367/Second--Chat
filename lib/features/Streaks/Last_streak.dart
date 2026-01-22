import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';

class StreakFreezeUseBottomSheet extends StatefulWidget {
  const StreakFreezeUseBottomSheet({super.key});

  @override
  State<StreakFreezeUseBottomSheet> createState() => _StreakFreezeUseBottomSheetState();
}

class _StreakFreezeUseBottomSheetState extends State<StreakFreezeUseBottomSheet> with SingleTickerProviderStateMixin {
  late AnimationController _freezeController;
  late Animation<double> _glowAnimation;
  late Animation<double> _floatAnimation;

  static const int days = 7;
  static const double horizontalPadding = 12;
  static const double rowHeight = 32;

  @override
  void initState() {
    super.initState();
    _freezeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.4).animate(
      CurvedAnimation(parent: _freezeController, curve: Curves.easeInOutSine),
    );

    _floatAnimation = Tween<double>(begin: 0, end: -10.h).animate(
      CurvedAnimation(parent: _freezeController, curve: Curves.easeInOutQuad),
    );
  }

  @override
  void dispose() {
    _freezeController.dispose();
    super.dispose();
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

  Widget _cross() => Icon(Icons.close, color: const Color(0xFF8E8E93), size: 22.sp);
  Widget _freeze() => Image.asset('assets/images/Privacy & Security - SVG.png', width: 22.sp);
  Widget _dot() => Opacity(opacity: 0.3, child: Icon(Icons.circle, size: 10.sp, color: Colors.white));

  Widget _highlight(int start, int end, double totalWidth) {
    final int count = end - start + 1;
    final double cellWidth = totalWidth / days;

    Decoration decoration;
    if (count >= 3) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7EDDE4), Color(0xFFC5F3F1)]),
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
      decoration: BoxDecoration(color: bottomSheetGrey, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
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
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            InkWell(onTap: Get.back, child: Image.asset('assets/icons/x_icon.png', height: 44.h)),
                          ],
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _freezeController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 300.w, height: 240.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.all(Radius.elliptical(70.w, 110.h)),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF7EDDE4).withOpacity(_glowAnimation.value), blurRadius: 180, spreadRadius: 10),
                                  ],
                                ),
                              ),
                              Transform.translate(offset: Offset(0, _floatAnimation.value), child: Image.asset('assets/images/hello.png', height: 250.h)),
                              Positioned(bottom: 0.h, child: Image.asset('assets/images/Streak number.png', width: 155.w, height: 90.h)),
                            ],
                          );
                        },
                      ),
                      Text("Go ahead, freeze it. Commitment is \noverrated anyway.", style: sfProDisplay600(22.sp, Colors.white), textAlign: TextAlign.center),
                      SizedBox(height: 12.h),
                      Obx(() {
                        final available = 3 - controller.manualFreezeCount.value;
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF32393D),
                            borderRadius: BorderRadius.circular(40.r),
                            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset("assets/images/checkmark.circle.fill.png", width: 19.w, height: 24.h),
                              SizedBox(width: 8.w),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(text: '$available ', style: sfProDisplay400(15.sp, Colors.white)),
                                    TextSpan(text: 'available', style: sfProDisplay400(15.sp, const Color(0xFFB0B3B8))),
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
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding.w, vertical: 16.h),
                        decoration: BoxDecoration(color: const Color(0xFF1E1D20), borderRadius: BorderRadius.circular(24.r)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: ['Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat', 'Sun'].map((day) {
                                return Expanded(child: Center(child: Text(day, style: TextStyle(color: const Color(0xFF8E8E93), fontSize: 13.sp))));
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
                                    final groups = controller.getTickGroups(rowData);
                                    return Stack(
                                      children: [
                                        for (final g in groups) _highlight(g[0], g[1], totalWidth),
                                        Row(
                                          children: List.generate(days, (i) {
                                            final cell = rowData[i];
                                            final isLatest = controller.lastTappedCol.value == i;
                                            Widget icon;
                                            switch (cell) {
                                              case CellType.tick: icon = _tick(highlighted: isLatest); break;
                                              case CellType.cross: icon = _cross(); break;
                                              case CellType.freeze: icon = _freeze(); break;
                                              case CellType.dot: icon = _dot(); break;
                                            }
                                            return Expanded(child: Center(child: icon));
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
                        height: 50.h, width: double.infinity,
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
                        height: 50.h, width: double.infinity,
                        child: Obx(() {
                          final canFreeze = (3 - controller.manualFreezeCount.value) > 0;
                          return ElevatedButton(
                            onPressed: canFreeze ? () {
                              controller.addFreezeAfterStreak();
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canFreeze ? const Color(0xFF7EDDE4) : Colors.grey.withOpacity(0.5),
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