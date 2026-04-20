import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/localization/l10n.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/controllers/Main Section Controllers/streak_controller.dart';

class StreakHistoryBottomSheet extends StatefulWidget {
  const StreakHistoryBottomSheet({super.key});

  @override
  State<StreakHistoryBottomSheet> createState() => _StreakHistoryBottomSheetState();
}

class _StreakHistoryBottomSheetState extends State<StreakHistoryBottomSheet> {
  late final StreamStreaksController _streakCtrl;

  @override
  void initState() {
    super.initState();
    _streakCtrl = Get.find<StreamStreaksController>();
    // Keep opening instant; refresh history in background.
    unawaited(_streakCtrl.fetchHistory(force: true, silent: true));
  }

  Widget _buildIcon(CellType cell) {
    switch (cell) {
      case CellType.tick:
        return Icon(Icons.check, size: 16.sp, color: Colors.white);
      case CellType.cross:
        return Icon(Icons.close, size: 18.sp, color: const Color(0xFF8E8E93));
      case CellType.freeze:
        return Image.asset(
          'assets/images/Mask group.png',
          width: 16.w,
          height: 16.w,
          fit: BoxFit.contain,
        );
      case CellType.dot:
        return Opacity(
          opacity: 0.35,
          child: Icon(Icons.circle, size: 8.sp, color: Colors.white),
        );
    }
  }

  Widget _buildWeekRow(List<CellType> row) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D20),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: List.generate(7, (i) {
          return Expanded(
            child: Center(child: _buildIcon(row[i])),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final historyRows = _streakCtrl.historyRows.toList(growable: false);
      final loading = _streakCtrl.isHistoryLoading.value;

      return Container(
        height: Get.height * 0.9,
        decoration: BoxDecoration(
          color: bottomSheetGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(38.r)),
        ),
        child: ClipRRect(
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
                left: 16.w,
                right: 16.w,
                bottom: 86.h + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF48484A),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Image.asset('assets/icons/x_icon.png', height: 44.h),
                      ),
                      Text(
                        'Streak History',
                        style: sfProText600(17.sp, Colors.white),
                      ),
                      SizedBox(width: 44.w),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  if (loading) ...[
                    SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 14.h),
                  ],
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1D20),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ]
                              .map(
                                (d) => Expanded(
                                  child: Center(
                                    child: Text(
                                      d,
                                      style: TextStyle(color: Color(0xFF8E8E93)),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        SizedBox(height: 12.h),
                        if (historyRows.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 18.h),
                            child: Text(
                              'No streak history yet',
                              style: sfProText400(
                                14.sp,
                                const Color(0xFFB0B3B8),
                              ),
                            ),
                          ),
                        ...historyRows.map(
                          (row) => Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: _buildWeekRow(row),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
