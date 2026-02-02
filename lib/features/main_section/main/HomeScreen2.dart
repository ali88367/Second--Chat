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

import '../settings/settings_bottomsheet_column.dart';

class HomeScreen2 extends StatefulWidget {
  const HomeScreen2({super.key});

  @override
  State<HomeScreen2> createState() => _HomeScreen2State();
}

class _HomeScreen2State extends State<HomeScreen2> {
  bool _framesPreloaded = false;
  bool _iconsPreloaded = false;
  static const int frozenFireFrames = 95; // FrozenFire frames from 0001 to 0095
  static const int fireAnimation2Frames =
      119; // FIreAnimation2 frames from 0001 to 0119

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload all animation frames when context is available
    if (!_framesPreloaded) {
      _preloadAllAnimationFrames();
      _framesPreloaded = true;
    }
    // Preload all icons immediately for instant display
    if (!_iconsPreloaded) {
      _preloadAllIcons();
      _iconsPreloaded = true;
    }
  }

  void _preloadAllIcons() {
    // Preload all icons used in the header and UI
    final iconsToPreload = [
      'assets/images/offline.png',
      'assets/images/streak_icon.png',
      'assets/images/gift.png',
      'assets/images/settings.png',
      'assets/images/stream.png',
      'assets/images/arrow.png',
      'assets/images/topbarshade.png',
      'assets/images/notification.png',
      'assets/images/signals.png',
      'assets/images/settingHome.png',
      'assets/images/calendar.png',
      'assets/images/check.png',
      'assets/icons/loader_icon.png',
      'assets/images/arrowRight.png',
      'assets/icons/x_icon.png',
    ];

    // Preload all icons immediately
    for (final iconPath in iconsToPreload) {
      precacheImage(AssetImage(iconPath), context);
    }
  }

  void _preloadAllAnimationFrames() {
    // Preload first 30 frames of both animations immediately for instant display
    for (int i = 1; i <= 30; i++) {
      final frameNumber = i.toString().padLeft(4, '0');

      // Preload FrozenFire frames
      if (i <= frozenFireFrames) {
        precacheImage(
          AssetImage('assets/FrozenFire/frame_$frameNumber.png'),
          context,
        );
      }

      // Preload FIreAnimation2 frames
      if (i <= fireAnimation2Frames) {
        final fireFrameNumber = i.toString().padLeft(4, '0');
        precacheImage(
          AssetImage('assets/FIreAnimation2/frame_lq_$fireFrameNumber.png'),
          context,
        );
      }
    }

    // Preload remaining frames in the background after a short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        // Preload remaining FrozenFire frames
        for (int i = 31; i <= frozenFireFrames; i++) {
          final frameNumber = i.toString().padLeft(4, '0');
          precacheImage(
            AssetImage('assets/FrozenFire/frame_$frameNumber.png'),
            context,
          );
        }

        // Preload remaining FIreAnimation2 frames
        for (int i = 31; i <= fireAnimation2Frames; i++) {
          final fireFrameNumber = i.toString().padLeft(4, '0');
          precacheImage(
            AssetImage('assets/FIreAnimation2/frame_lq_$fireFrameNumber.png'),
            context,
          );
        }
      }
    });
  }

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

          // 🔹 Center Content (MOVED UP)
          // Moving this block BEFORE the Header ensures the Header sits ON TOP of it.
          // This fixes the issue where the Header buttons were unclickable.
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

          // 🔹 Header (Image Buttons) (MOVED DOWN)
          // Now this comes AFTER the Center content in the Stack, making it clickable.
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
                            enterBottomSheetDuration: const Duration(
                              milliseconds: 300,
                            ),
                            exitBottomSheetDuration: const Duration(
                              milliseconds: 250,
                            ),
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
                            enterBottomSheetDuration: const Duration(
                              milliseconds: 300,
                            ),
                            exitBottomSheetDuration: const Duration(
                              milliseconds: 250,
                            ),
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
                            enterBottomSheetDuration: const Duration(
                              milliseconds: 300,
                            ),
                            exitBottomSheetDuration: const Duration(
                              milliseconds: 250,
                            ),
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

          // 🔹 Getting Started Card
          Positioned(
            // FIX: Changed from 110.h to 42.h.
            // Why? The Card now includes internal padding for the button (68.h).
            // 110 - 68 = 42. This ensures the Card stays at the exact same visual height.
            bottom: 42.h,
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
    return Container(
      // Added transparent color to ensure taps work on transparent image areas
      color: Colors.transparent,
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

  // All done check
  bool get _isAllCompleted => _completedCount == 4;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. The Main Card Container
        // FIX: Wrapped in Padding to reserve space for the hanging button.
        // This ensures the button is inside the widget bounds for clicking.
        Padding(
          padding: EdgeInsets.only(bottom: 68.h),
          child: Container(
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
                                backgroundColor: const Color.fromRGBO(
                                  120,
                                  120,
                                  128,
                                  0.36,
                                ),
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
                      // 1. Enable notifications
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
                            enterBottomSheetDuration: const Duration(
                              milliseconds: 300,
                            ),
                            exitBottomSheetDuration: const Duration(
                              milliseconds: 250,
                            ),
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
                            enterBottomSheetDuration: const Duration(
                              milliseconds: 300,
                            ),
                            exitBottomSheetDuration: const Duration(
                              milliseconds: 250,
                            ),
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
                            enterBottomSheetDuration: const Duration(
                              milliseconds: 300,
                            ),
                            exitBottomSheetDuration: const Duration(
                              milliseconds: 250,
                            ),
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
          ),
        ),

        // 2. The Next Button
        // FIX: Positioned at bottom: 0.
        // Since we added 68.h padding to the container above, bottom: 0 here
        // is visually equivalent to bottom: -68.h in the old code,
        // but now it is valid for clicks.
        if (_isAllCompleted)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                Get.to(Livestreaming());
              },
              child: Container(
                height: 52.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30.r),
                ),
                alignment: Alignment.center,
                child: Text("Next", style: sfProText600(17.sp, Colors.black)),
              ),
            ),
          ),
      ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              // Left Icon
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

              // --- STATUS ICON LOGIC (Swap Loader <-> Check) ---
              if (isChecked) ...[
                // Completed: Show Check Icon
                Image.asset(
                  'assets/images/check.png',
                  width: 28.w,
                  height: 28.w,
                  fit: BoxFit.contain,
                ),
                SizedBox(width: 8.w),
              ] else if (hasArrow) ...[
                // Not Completed: Show Loader (only if hasArrow/loader flag is true)
                Image.asset(
                  'assets/icons/loader_icon.png',
                  width: 28.w,
                  height: 28.w,
                  fit: BoxFit.contain,
                ),
                SizedBox(width: 8.w),
              ],

              // --- NAVIGATION ARROW (Always Visible) ---
              Image.asset(
                'assets/images/arrowRight.png',
                width: 28.w,
                height: 28.w,
                fit: BoxFit.contain,
              ),
            ],
          ),
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
