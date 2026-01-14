import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/features/live_stream/live_stream_screen.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/features/Invite/Invite_screen.dart';
import 'package:second_chat/features/Streaks/Streaksbottomsheet.dart';
import 'package:second_chat/features/main_section/main/HomeScreen.dart';
import 'package:second_chat/features/main_section/stream/StreamStreak1.dart';
import 'package:second_chat/features/main_section/stream/stream_screen.dart';

import '../settings/settings_bottomsheet_column.dart';

class HomeScreen2 extends StatelessWidget {
  const HomeScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // 🔹 Top Background Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300.h,
            child: Image.asset(
              'assets/images/topbarshade.png',
              fit: BoxFit.cover,
            ),
          ),

          // 🔹 Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x661A1A1A), Color(0xFF0A0A0A)],
                ),
              ),
            ),
          ),

          // 🔹 Header (Image Buttons)
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 28.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Offline Button
                  GestureDetector(
                    onTap: () {
                      Get.to(Livestreaming());
                    },
                    child: _buildImageButton(
                      'assets/images/offline.png',
                      width: 119.w,
                      height: 36.h,
                    ),
                  ),

                  // Right Buttons
                  Row(
                    children: [
                      _buildImageButton(
                        'assets/images/streak_icon.png',
                        width: 72.w,
                        height: 36.w,
                      ),
                      SizedBox(width: 6.w),
                      _buildImageButton(
                        'assets/images/gift.png',
                        width: 36.w,
                        height: 36.w,
                      ),
                      SizedBox(width: 6.w),
                      _buildImageButton(
                        'assets/images/settings.png',
                        width: 36.w,
                        height: 36.w,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 🔹 Center Content
          Center(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // The main text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Get.to(HomeScreen());
                      },
                      child: Image.asset(
                        'assets/images/stream.png',
                        width: 47.w,
                        height: 56.w,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'You haven\'t started the\nstream yet, but in the\nmeantime you can',
                      textAlign: TextAlign.center,
                      style: sfProDisplay400(
                        28.sp,
                        Color.fromRGBO(255, 255, 255, 0.4),
                      ),
                    ),
                    SizedBox(height: 350.h),
                  ],
                ),

                // Arrow Positioned below the text
                Positioned(
                  right: -8.w,
                  top: 185.h,
                  child: Image.asset(
                    'assets/images/arrow.png',
                    width: 30.w,
                    height: 75.w,
                  ),
                ),
              ],
            ),
          ),

          // 🔹 Getting Started Card (New Widget)
          Positioned(
            bottom: 110.h,
            left: 16.w,
            right: 16.w,
            child: const GettingStartedCard(),
          ),
        ],
      ),
    );
  }

  /// 🔹 Reusable Image Button
  static Widget _buildImageButton(
    String assetPath, {
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

class GettingStartedCard extends StatefulWidget {
  const GettingStartedCard({super.key});

  @override
  State<GettingStartedCard> createState() => _GettingStartedCardState();
}

class _GettingStartedCardState extends State<GettingStartedCard> {
  bool isNotificationChecked = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 1.h),
      decoration: BoxDecoration(
        color: Color.fromRGBO(30, 29, 32, 1),

        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Header
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    'Getting Started',
                    style: sfProText600(
                      17.sp,
                      Color.fromRGBO(235, 235, 245, 0.3),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: Image.asset(
                    'assets/images/circle.png',

                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: Color.fromRGBO(47, 46, 51, 1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18.r),
                topRight: Radius.circular(18.r),
                bottomLeft: Radius.circular(22.r),
                bottomRight: Radius.circular(22.r),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuItem(
                  imagePath: 'assets/images/notification.png',
                  title: 'Enable notifications',
                  hasCheckbox: true,
                ),
                _buildDivider(),
                InkWell(
                  onTap: () {
                    Get.bottomSheet(
                      isDismissible: true,
                      isScrollControlled: true,
                      enableDrag: true,
                      Container(
                        height: Get.height * .9,
                        decoration: BoxDecoration(
                          color: bottomSheetGrey,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(18.r),
                            topLeft: Radius.circular(18.r),
                          ),
                        ),
                        child: InviteBottomSheet(),
                      ),
                    );
                  },
                  child: _buildMenuItem(
                    imagePath: 'assets/images/signals.png',
                    title: 'Add new stream service',
                    hasArrow: true,
                  ),
                ),
                _buildDivider(),
                InkWell(
                  onTap: () {
                    Get.bottomSheet(
                      isDismissible: true,
                      isScrollControlled: true,
                      enableDrag: true,
                      Container(
                        height: Get.height * .9,
                        decoration: BoxDecoration(
                          color: bottomSheetGrey,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(18.r),
                            topLeft: Radius.circular(18.r),
                          ),
                        ),
                        child: SettingsBottomsheetColumn(),
                      ),
                    );
                  },
                  child: _buildMenuItem(
                    imagePath: 'assets/images/settingHome.png',
                    title: 'Open settings',
                    hasArrow: true,
                  ),
                ),
                _buildDivider(),
                InkWell(
                  onTap: () {
                    Get.bottomSheet(
                      isDismissible: true,
                      isScrollControlled: true,
                      enableDrag: true,
                      Container(
                        height: Get.height * .9,
                        decoration: BoxDecoration(
                          color: bottomSheetGrey,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(18.r),
                            topLeft: Radius.circular(18.r),
                          ),
                        ),
                        child: StreamStreakSetupBottomSheet(),
                      ),
                    );
                  },
                  child: _buildMenuItem(
                    imagePath: 'assets/images/calendar.png',
                    title: 'Customizable Streaks',
                    hasArrow: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildMenuItem({
  required String imagePath,
  required String title,
  bool hasCheckbox = false,
  bool isChecked = false,
  VoidCallback? onTap,
  bool hasArrow = false,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          // Image with its own background
          Image.asset(
            imagePath,
            width: 42.w,
            height: 42.w,
            fit: BoxFit.contain,
          ),

          SizedBox(width: 12.w),

          // Title
          Expanded(
            child: Text(title, style: sfProText400(16.sp, Colors.white)),
          ),

          // Dotted Circle Checkbox or Arrow
          if (hasCheckbox)
            SizedBox(
              height: 28.h,
              width: 28.w,
              child: Image.asset('assets/images/check.png'),
            ),

          if (hasArrow) ...[
            Image.asset(
              'assets/icons/loader_icon.png',
              width: 28.w,
              height: 28.w,
              fit: BoxFit.contain,
            ),

            SizedBox(width: 12.w),
            Image.asset(
              'assets/images/arrowRight.png',
              width: 28.w,
              height: 28.w,
              fit: BoxFit.contain,
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildDivider() {
  return Padding(
    padding: EdgeInsets.only(left: 18.w, right: 18.w),
    child: Container(height: 0.5.h, color: const Color(0xFF38383A)),
  );
}
