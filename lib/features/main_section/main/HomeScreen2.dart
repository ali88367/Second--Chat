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
import 'package:second_chat/features/main_section/settings/settings_components/connect_platform_setting.dart';
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
                      Get.to(
                            () => Livestreaming(),
                        transition: Transition.cupertino,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.fastOutSlowIn,
                      );
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
                      InkWell(
                        onTap: () {
                          Get.bottomSheet(
                            Container(
                              height: Get.height * .8,
                              decoration: BoxDecoration(
                                color: bottomSheetGrey,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(18.r),
                                  topLeft: Radius.circular(18.r),
                                ),
                              ),
                              child: StreamStreakSetupBottomSheet(),
                            ),
                            isDismissible: true,
                            isScrollControlled: true,
                            enableDrag: true,
                            enterBottomSheetDuration: const Duration(milliseconds: 300),
                            exitBottomSheetDuration: const Duration(milliseconds: 250),
                          );
                        },
                        child: _buildImageButton(
                          'assets/images/streak_icon.png',
                          width: 72.w,
                          height: 36.w,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      InkWell(
                        onTap: () {
                          Get.bottomSheet(
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
                            isDismissible: true,
                            isScrollControlled: true,
                            enableDrag: true,
                            enterBottomSheetDuration: const Duration(milliseconds: 300),
                            exitBottomSheetDuration: const Duration(milliseconds: 250),
                          );
                        },
                        child: _buildImageButton(
                          'assets/images/gift.png',
                          width: 36.w,
                          height: 36.w,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      GestureDetector(
                        onTap: () {
                          Get.bottomSheet(
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
                            isDismissible: true,
                            isScrollControlled: true,
                            enableDrag: true,
                            enterBottomSheetDuration: const Duration(milliseconds: 300),
                            exitBottomSheetDuration: const Duration(milliseconds: 250),
                          );
                        },
                        child: _buildImageButton(
                          'assets/images/settings.png',
                          width: 36.w,
                          height: 36.w,
                        ),
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
                        Get.to(
                              () => HomeScreen(),
                          transition: Transition.cupertino,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.fastOutSlowIn,
                        );
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

          // 🔹 Getting Started Card
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
  bool _notificationsEnabled = false;
  bool _streamServiceAdded = false;
  bool _settingsOpened = false;
  bool _streaksCustomized = false;

  // Count completed steps
  int get _completedCount {
    int count = 0;
    if (_notificationsEnabled) count++;
    if (_streamServiceAdded) count++;
    if (_settingsOpened) count++;
    if (_streaksCustomized) count++;
    return count;
  }

  // Percentage (0–100)
  int get _progressPercentage => _completedCount * 25;

  // All done check
  bool get _isAllCompleted => _completedCount == 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 1.h),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(30, 29, 32, 1),
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Header with progress percentage + indicator
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Getting Started',
                  style: sfProText600(
                    17.sp,
                    _isAllCompleted
                        ? Colors.white
                        : Color.fromRGBO(235, 235, 245, 0.3),
                  ),
                ),
                SizedBox(width: 10.w),
                SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: _isAllCompleted
                      ? Image.asset(
                    'assets/images/check.png',
                    fit: BoxFit.contain,
                  )
                      : CircularProgressIndicator(
                    value: _completedCount / 4.0,
                    strokeWidth: 3.0,
                    color: const Color.fromRGBO(176, 218, 200, 1),
                    backgroundColor: const Color.fromRGBO(120, 120, 128, 0.36),
                  ),
                ),
              ],
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(47, 46, 51, 1),
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
                // 1. Enable notifications (checkbox style - no circle/arrow when unfinished)
                _buildMenuItem(
                  imagePath: 'assets/images/notification.png',
                  title: 'Enable notifications',
                  hasCheckbox: true,
                  isChecked: _notificationsEnabled,
                  onTap: () {
                    setState(() {
                      _notificationsEnabled = true;
                    });
                  },
                ),
                _buildDivider(),

                // 2. Add new stream service
                InkWell(
                  onTap: () {
                    Get.bottomSheet(
                      Padding(
                        padding: EdgeInsets.only(
                          left: 12.w,
                          right: 12.w,
                          bottom: 15.h,
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 361.w,
                            height: 730.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(36.r),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(36.r),
                              child: ConnectPlatformSetting(),
                            ),
                          ),
                        ),
                      ),
                      isDismissible: true,
                      isScrollControlled: true,
                      enableDrag: true,
                      backgroundColor: Colors.transparent,
                      enterBottomSheetDuration: const Duration(milliseconds: 300),
                      exitBottomSheetDuration: const Duration(milliseconds: 250),
                    ).then((_) {
                      setState(() {
                        _streamServiceAdded = true;
                      });
                    });
                  },
                  child: _buildMenuItem(
                    imagePath: 'assets/images/signals.png',
                    title: 'Add new stream service',
                    hasArrow: true,
                    isChecked: _streamServiceAdded,
                  ),
                ),
                _buildDivider(),

                // 3. Open settings
                InkWell(
                  onTap: () {
                    Get.bottomSheet(
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
                      isDismissible: true,
                      isScrollControlled: true,
                      enableDrag: true,
                      enterBottomSheetDuration: const Duration(milliseconds: 300),
                      exitBottomSheetDuration: const Duration(milliseconds: 250),
                    ).then((_) {
                      setState(() {
                        _settingsOpened = true;
                      });
                    });
                  },
                  child: _buildMenuItem(
                    imagePath: 'assets/images/settingHome.png',
                    title: 'Open settings',
                    hasArrow: true,
                    isChecked: _settingsOpened,
                  ),
                ),
                _buildDivider(),

                // 4. Customisable streaks
                InkWell(
                  onTap: () {
                    Get.bottomSheet(
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
                      isDismissible: true,
                      isScrollControlled: true,
                      enableDrag: true,
                      enterBottomSheetDuration: const Duration(milliseconds: 300),
                      exitBottomSheetDuration: const Duration(milliseconds: 250),
                    ).then((_) {
                      setState(() {
                        _streaksCustomized = true;
                      });
                    });
                  },
                  child: _buildMenuItem(
                    imagePath: 'assets/images/calendar.png',
                    title: 'Customisable streaks',
                    hasArrow: true,
                    isChecked: _streaksCustomized,
                  ),
                ),


              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String imagePath,
    required String title,
    bool hasCheckbox = false,
    bool isChecked = false,
    bool hasArrow = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Image.asset(
              imagePath,
              width: 42.w,
              height: 42.w,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: sfProText400(16.sp, Colors.white),
              ),
            ),

            // Right side: circle + arrow when unfinished (for hasArrow items), tick when done
            if (isChecked)
              Image.asset(
                'assets/images/check.png',
                width: 28.w,
                height: 28.w,
                fit: BoxFit.contain,
              )
            else if (hasArrow) ...[
              Image.asset(
                'assets/icons/loader_icon.png',
                width: 28.w,
                height: 28.w,
                fit: BoxFit.contain,
              ),],
              SizedBox(width: 8.w),
              Image.asset(
                'assets/images/arrowRight.png',
                width: 28.w,
                height: 28.w,
                fit: BoxFit.contain,
              ),
            // For notifications (hasCheckbox && !isChecked) → no icon on right (clean UI)
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
}