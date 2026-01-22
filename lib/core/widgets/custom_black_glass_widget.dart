import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gradient_borders/gradient_borders.dart';
import '../../controllers/Main Section Controllers/streak_controller.dart';
import '../themes/textstyles.dart';

class CustomBlackGlassWidget extends StatelessWidget {
  final List<String> items;
  final bool isWeek;
  final Function(String)? onItemSelected;

  CustomBlackGlassWidget({
    super.key,
    required this.items,
    required this.isWeek,
    this.onItemSelected,
  });

  final controller = Get.find<StreamStreaksController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final radiusValue = _calculateResponsiveRadius();

      return ClipRRect(
        borderRadius: BorderRadius.circular(radiusValue),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 85.w,
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
            decoration: _decoration(radiusValue),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // TOP SECTION: Selected numbers
                ...controller.selectedMenuNumbers.map((num) => _buildSelectedItem(num)),

                // THE DIVIDER
                if (controller.selectedMenuNumbers.isNotEmpty) _divider(),

                // BOTTOM SECTION: Available numbers
                ...controller.availableNumbers.map((num) => _buildAvailableItem(num)),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSelectedItem(int num) {
    return GestureDetector(
      onTap: () {
        controller.toggleMenuNumber(num);
        onItemSelected?.call("$num");
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 14),
            SizedBox(width: 6.w),
            Text("$num", style: sfProText600(17.sp, Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableItem(int num) {
    return GestureDetector(
      onTap: () {
        controller.toggleMenuNumber(num);
        onItemSelected?.call("$num");
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text(
          "$num",
          textAlign: TextAlign.center,
          style: sfProText600(17.sp, Colors.white.withOpacity(0.6)),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 16.h),
      child: Container(
        height: 1,
        width: 40.w,
        color: Colors.white.withOpacity(0.15),
      ),
    );
  }

  double _calculateResponsiveRadius() {
    final totalItems = controller.selectedMenuNumbers.length + controller.availableNumbers.length;
    final double estimatedHeight = (31.h * totalItems) + 40.h;
    return (estimatedHeight * 0.2).clamp(22.0, 35.0);
  }

  BoxDecoration _decoration(double radiusValue) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusValue),
      border: GradientBoxBorder(
        width: 1.2,
        gradient: SweepGradient(
          colors: [
            Colors.white.withOpacity(.12),
            Colors.black,
            Colors.white.withOpacity(.12),
            Colors.white.withOpacity(.12),
            Colors.black,
            Colors.white.withOpacity(.12),
          ],
          stops: const [0, .35, .36, .82, .83, 1],
        ),
      ),
      color: Colors.black.withOpacity(.2),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, .33, .43, .7, 1],
        colors: const [
          Color(0xFF000000),
          Color(0xFF171717),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0xFF262626),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.25),
          blurRadius: 4,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}