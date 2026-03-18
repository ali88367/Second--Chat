import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:second_chat/core/localization/l10n.dart';
import 'package:second_chat/core/themes/textstyles.dart';

import 'intro_screen3.dart';

class NotficationScreens extends StatefulWidget {
  const NotficationScreens({super.key});

  @override
  State<NotficationScreens> createState() => _NotficationScreensState();
}

class _NotficationScreensState extends State<NotficationScreens> {
  bool _isRequesting = false;

  void _goToIntroScreen3() {
    Get.to(
      () => const IntroScreen3(),
      transition: Transition.cupertino,
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    final status = await Permission.notification.request();

    if (!mounted) return;
    setState(() => _isRequesting = false);

    if (status.isGranted) {
      _goToIntroScreen3();
      return;
    }

    if (status.isPermanentlyDenied) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.enableNotifications),
          content: Text(context.l10n.notificationPermissionDisabledBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.notNow),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.openSettings),
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
      SnackBar(content: Text(context.l10n.notificationPermissionDenied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            alignment: Alignment.center,
            children: [
              // 🔹 Background Image
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Image.asset(
                  'assets/images/notback.jpeg',
                  fit: BoxFit.cover,
                ),
              ),




              // 🔹 Button
              Positioned(
                bottom: 100.h,

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
                      child: Padding(
                        padding:  EdgeInsets.symmetric(horizontal: 15.w),
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
                                  context.l10n.turnOnNotifications,
                                  style: sfProDisplay600(16.sp, Colors.black),
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
                child: GestureDetector(
                  onTap: _isRequesting ? null : _goToIntroScreen3,
                  child: Text(
                    context.l10n.notificationScreenAnotherTime,
                    textAlign: TextAlign.center,
                    style: sfProDisplay400(16.sp, Colors.white70),
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
                      context.l10n.appName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Text(
                      context.l10n.notificationCardMessage,
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
                context.l10n.notificationCardTime,
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
