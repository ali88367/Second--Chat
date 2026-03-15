import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/api/auth/oauth_provider.dart';
import 'package:second_chat/controllers/platform_connect_controller.dart';
import 'package:second_chat/core/constants/app_images/app_images.dart';
import '../../../../core/constants/app_colors/app_colors.dart';
import '../../../../core/themes/textstyles.dart';

class ConnectPlatformSetting extends StatelessWidget {
  const ConnectPlatformSetting({super.key});

  // Reusable platform card widget
  Widget _buildPlatformCard({
    required String title,
    required String largeLogoAsset, // Big logo on top
    required String smallLogoAsset, // Small logo inside button
    required Color buttonColor,
    required VoidCallback onPressed,
    bool isConnected = false, // Optional: dim if not connected
    bool isConnecting = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: Color.fromRGBO(30, 29, 32, 1), // Dark grey background
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
          Image.asset(largeLogoAsset, width: 76.w, height: 76.h),
          SizedBox(height: 24.h),
          // Connect button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30.r),
              onTap: (isConnected || isConnecting) ? null : onPressed,
              child: Container(
                height: 50.h,
                decoration: BoxDecoration(
                  color: (isConnected || isConnecting)
                      ? buttonColor.withOpacity(0.75)
                      : buttonColor,
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(smallLogoAsset, width: 22.w, height: 22.h),
                        SizedBox(width: 6.w),
                        Text(
                          isConnected ? 'Connected' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sfProText600(18.sp, Colors.white),
                        ),
                        if (isConnecting) ...[
                          SizedBox(width: 8.w),
                          SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ] else if (isConnected) ...[
                          SizedBox(width: 6.w),
                          Icon(
                            Icons.check_circle,
                            size: 18.sp,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
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
    final ctrl = Get.find<PlatformConnectController>();
    return Container(
      color: const Color.fromRGBO(20, 18, 18, 1),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Obx(
          () {
            final twitchConnected =
                ctrl.isConnected[OAuthProvider.twitch] ?? false;
            final kickConnected = ctrl.isConnected[OAuthProvider.kick] ?? false;
            final youtubeConnected =
                ctrl.isConnected[OAuthProvider.youtube] ?? false;
            final connecting = ctrl.connectingProvider.value;

            return Column(
              children: [
                SizedBox(height: 10.h),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                        onTap: () {
                          Get.back();
                        },
                        child: Image.asset(back_arrow_icon, height: 44.h)),
                    Text(
                      "Connect Platform",
                      style: sfProDisplay600(17.sp, onDark),
                    ),
                    SizedBox(width: 44.w),
                  ],
                ),

                SizedBox(height: 40.h),

                Row(
                  children: [
                    Expanded(
                      child: _buildPlatformCard(
                        title: 'Twitch',
                        largeLogoAsset: twitch_logo,
                        smallLogoAsset: twitch_icon,
                        buttonColor: twitchPurple,
                        isConnected: twitchConnected,
                        isConnecting: connecting == OAuthProvider.twitch,
                        onPressed: () => ctrl.connect(OAuthProvider.twitch),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildPlatformCard(
                        title: 'Kick',
                        largeLogoAsset: kick,
                        smallLogoAsset: kick_icon,
                        buttonColor: kickGreen,
                        isConnected: kickConnected,
                        isConnecting: connecting == OAuthProvider.kick,
                        onPressed: () => ctrl.connect(OAuthProvider.kick),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.w),
                _buildPlatformCard(
                  title: 'YouTube',
                  largeLogoAsset: youtube_logo,
                  smallLogoAsset: youtube_icon,
                  buttonColor: youtubeRed,
                  isConnected: youtubeConnected,
                  isConnecting: connecting == OAuthProvider.youtube,
                  onPressed: () => ctrl.connect(OAuthProvider.youtube),
                ),

                SizedBox(height: 20.h),
              ],
            );
          },
        ),
      ),
    );
  }
}
