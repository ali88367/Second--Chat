import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:second_chat/core/themes/textstyles.dart';

import 'intro_screen3.dart';

class NotficationScreens extends StatefulWidget {
  const NotficationScreens({super.key});

  @override
  State<NotficationScreens> createState() => _NotficationScreensState();
}

class _NotficationScreensState extends State<NotficationScreens> {
  bool _isRequesting = false;

  Future<void> _requestNotificationPermission() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    final status = await Permission.notification.request();

    if (!mounted) return;
    setState(() => _isRequesting = false);

    if (status.isGranted) {
      Get.to(
        () => const IntroScreen3(),
        transition: Transition.cupertino,
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
      );
      return;
    }

    if (status.isPermanentlyDenied) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable notifications'),
          content: const Text(
            'Notifications are disabled. You can enable them in system settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );

      if (openSettings == true) {
        await openAppSettings();
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification permission not granted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              // 🔹 Background Image
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Image.asset(
                  'assets/images/notscreen.jpeg',
                  fit: BoxFit.cover,
                ),
              ),

              // 🔹 Notification Card (TOP)
              Positioned(
                top: 320.h,
                left: 16.w,
                right: 16.w,
                child: const NotificationCard(),
              ),

              // 🔹 Notification Card (TOP)
              Positioned(
                top: 240.h,
                left: 16.w,
                right: 16.w,
                child: const NotificationCard(),
              ),

              // 🔹 Bell Image
              Positioned(
                bottom: 265.h,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    height: 130.h,
                    width: 130.w,
                    child: Image.asset('assets/images/bell1.jpeg'),
                  ),
                ),
              ),

              // 🔹 Title
              Positioned(
                bottom: 200.h,
                left: 0,
                right: 0,
                child: Text(
                  'Never Miss A Notification',
                  textAlign: TextAlign.center,
                  style: sfProDisplay600(15, Colors.white)
                ),
              ),

              // 🔹 Subtitle
              Positioned(
                bottom: 170.h,
                left: 0,
                right: 0,
                child: Text(
                  'Be the first to know what’s happening',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Colors.white70,
                  ),
                ),
              ),

              // 🔹 Button
              Positioned(
                bottom: 100.h,
                left: 60.w,
                right: 60.w,
                child: Opacity(
                  opacity: _isRequesting ? 0.6 : 1,
                  child: GestureDetector(
                    onTap: _isRequesting ? null : _requestNotificationPermission,
                    child: Container(
                      height: 52.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32.r),
                      ),
                      child: Center(
                        child: _isRequesting
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'Turn on notifications',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontFamily: "",
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              // 🔹 Bottom Text
              Positioned(
                bottom: 60.h,
                left: 0,
                right: 0,
                child: Text(
                  'Another time',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // ⬆️ stronger blur
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08), // ⬇️ more transparent
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: Colors.white.withOpacity(0.15), // softer border
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 App Icon
              Container(
                width: 38.w,
                height: 38.h,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),

              SizedBox(width: 12.w),

              // 🔹 Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Second Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Text(
                      'New features available!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14.sp,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // 🔹 Time
              Text(
                '9:41 AM',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
