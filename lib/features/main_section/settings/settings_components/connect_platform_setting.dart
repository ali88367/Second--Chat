import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:second_chat/core/constants/app_images/app_images.dart';
import '../../../../core/constants/app_colors/app_colors.dart';
import '../../../../core/themes/textstyles.dart';

class ConnectPlatformSetting extends StatelessWidget {
  const ConnectPlatformSetting({super.key});

  // Reusable platform card widget
  Widget _buildPlatformCard({
    required String title,
    required String largeLogoAsset,   // Big logo on top
    required String smallLogoAsset,   // Small logo inside button
    required Color buttonColor,
    required VoidCallback onPressed,
    bool isConnected = false,         // Optional: dim if not connected
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: onBottomSheetGrey, // Dark grey background
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large logo on top
          Image.asset(
            largeLogoAsset,
            width: 76.w,
            height: 76.h,
          ),
          SizedBox(height: 24.h),

          // Connect button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30.r),
              onTap: onPressed,
              child: Container(
                height: 50.h,
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Small icon inside button
                    Image.asset(
                      smallLogoAsset,
                      width: 22.w,
                      height: 22.h,
                    ),
                    // Platform name
                    SizedBox(width: 6.w,),
                    Text(
                      title,
                      style: sfProText600(18.sp, Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          children: [
            SizedBox(height: 40.h),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(back_arrow_icon, height: 44.h),
                Text(
                  "Connect Platform",
                  style: sfProDisplay600(17.sp, onDark),
                ),
                SizedBox(width: 44.w),
              ],
            ),

            SizedBox(height: 40.h),



            // Twitch
            Row(
              children: [
                Expanded(
                  child: _buildPlatformCard(
                    title: 'Twitch',
                    largeLogoAsset: twitch_logo, // Your big purple Twitch logo
                    smallLogoAsset: twitch_icon, // Small white version for button
                    buttonColor: twitchPurple,
                    isConnected: true,
                    onPressed: () {
                      print('Connect to Twitch');
                    },
                  ),
                ),
                SizedBox(width: 12.w,),
                // Kick
                Expanded(
                  child: _buildPlatformCard(
                    title: 'Kick',
                    largeLogoAsset: kick,
                    smallLogoAsset: kick_icon,
                    buttonColor: kickGreen,
                    isConnected: false,
                    onPressed: () {
                      print('Connect to Kick');
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.w,),
            // YouTube (can span or just place normally)
            _buildPlatformCard(
              title: 'YouTube',
              largeLogoAsset: youtube_logo,
              smallLogoAsset: youtube_icon,
              buttonColor: youtubeRed,
              isConnected: true,
              onPressed: () {
                print('Connect to YouTube');
              },
            ),

            SizedBox(height: 20.h),
          ],
        ),
      );
  }
}