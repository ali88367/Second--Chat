import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ios_color_picker/show_ios_color_picker.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/constants/app_images/app_images.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:toggle_switch/toggle_switch.dart';

import '../../../../core/widgets/custom_button.dart';


class PlatformColorSettings extends StatefulWidget {
  const PlatformColorSettings({super.key});

  @override
  State<PlatformColorSettings> createState() => _PlatformColorSettingsState();
}

class _PlatformColorSettingsState extends State<PlatformColorSettings> {
  // Current selected color (with opacity)
  Color selectedColor = const Color(0xFF9146FF); // Twitch purple default
  double opacity = 1.0;

  // Controller required by the package
  final IOSColorPickerController _colorPickerController = IOSColorPickerController();

  @override
  void dispose() {
    _colorPickerController.dispose();
    super.dispose();
  }

  // Function to open the full iOS color picker
  void _openColorPicker() {
    _colorPickerController.showIOSCustomColorPicker(
      context: context,
      startingColor: selectedColor.withOpacity(opacity),
      onColorChanged: (color) {
        setState(() {
          selectedColor = color.withAlpha(255); // Base color without opacity
          opacity = color.opacity;              // Extract opacity separately
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color displayColor = selectedColor.withOpacity(opacity);

    return Column(
          children: [
            SizedBox(height: 20.h,),
            Padding(
              padding:  EdgeInsets.symmetric(horizontal: 8.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(back_arrow_icon, height: 44.h),
                  Text(
                    "Platform Color",
                    style: sfProDisplay600(17.sp, onDark),
                  ),
                  SizedBox(width: 44.w),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                children: [
                  CustomButton(
                    text: 'Twitch',
                    prefixWidget: Image.asset(
                      twitch_icon, // Your small white Twitch logo
                      width: 20.w,
                      height: 20.h,
                    ),
                    backgroundColor: const Color(0xFF9146FF),
                    foregroundColor: Colors.white,
                    borderRadius: 30.r,
                    height: 44.h,
                    horizontalPadding: 20.w,
                    onPressed: () {
                      // Handle platform change if needed
                    },
                  ),
                  SizedBox(height: 10.h,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 4.r,
                        backgroundColor: Colors.white,
                      ),
                      SizedBox(width: 6.w,),
                      CircleAvatar(
                        radius: 4.r,
                        backgroundColor: Colors.grey,
                      ),
                      SizedBox(width: 6.w,),
                      CircleAvatar(
                        radius: 4.r,
                        backgroundColor: Colors.grey,
                      ),
                    ],
                  )
                ],
              ),
            ),

            SizedBox(height: 8.h),

            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Colors',
                  style: TextStyle(
                    fontFamily: 'SFProDisplay',
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            SizedBox(height: 40.h),

            // Color Preview + Tap to Open Picker
            GestureDetector(
              onTap: _openColorPicker,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 24.w),
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: onBottomSheetGrey,
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Column(
                  children: [
                    // Large color swatch with white ring
                    Container(
                      width: 100.r,
                      height: 100.r,
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4.w),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Tap to select color',
                      style: TextStyle(
                        fontFamily: 'SFProText',
                        fontSize: 16.sp,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            Container(
              height: 57.h,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(35),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {

                    },
                    child: Container(
                      width: 61.w,
                      height: 51.h,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(33),
                      ),
                      child: Center(
                        child: Image.asset(
                          wifi_icon,
                          height: 26.h,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Handle second option tap
                    },
                    child: Container(
                      width: 61.w,
                      height: 51.h,
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(33),
                      ),
                      child: Center(
                        child: Image.asset(
                          setting_icon,
                          height: 26.h,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30.h,),
          ],
        );
  }
}

// Checkerboard pattern for transparency preview
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final squareSize = size.width / 8;

    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        paint.color = (i + j) % 2 == 0 ? Colors.grey[700]! : Colors.grey[600]!;
        canvas.drawRect(
          Rect.fromLTWH(i * squareSize, j * squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}