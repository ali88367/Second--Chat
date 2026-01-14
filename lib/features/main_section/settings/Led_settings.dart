import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/constants/app_colors/app_colors.dart';
import '../../../../core/themes/textstyles.dart';
import '../../../../core/widgets/custom_switch.dart';
import '../../../../core/constants/app_images/app_images.dart';

class LedSettingsBottomSheet extends StatelessWidget {
  const LedSettingsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // The hex color code derived from your image
    const Color darkCharcoal = Color(0xFF212121);

    return Container(
      // Applying the background color to the entire sheet container
      decoration: BoxDecoration(
        color: darkCharcoal,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(18.r),
          topLeft: Radius.circular(18.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Handle Bar
          Align(
            alignment: Alignment.center,
            child: Container(
              margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Header & Content
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                SizedBox(height: 4.h),
                Center(
                  child: Text(
                    "LED settings",
                    style: sfProDisplay600(17.sp, Colors.white),
                  ),
                ),
                SizedBox(height: 12.h),

                // Group 1: Followers
                _buildSettingGroup([
                  _buildSwitchTile("New Followers", true.obs),
                ]),
                SizedBox(height: 16.h),

                // Group 2: All Subs
                _buildSettingGroup([
                  _buildSwitchTile("All Subscribers", true.obs),
                ]),
                SizedBox(height: 16.h),

                // Group 3: Milestones
                _buildSettingGroup([
                  _buildSwitchTile("Milestone Subscribers", true.obs),
                  _buildSwitchTile("5", true.obs, isNested: true),
                  _buildActionTile("New", Icons.add_circle_outline),
                ]),
                SizedBox(height: 40.h), // Bottom padding
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0XFF1E1D20), // Inner tile groups stay their original color
        borderRadius: BorderRadius.circular(27.r),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, RxBool val, {bool isNested = false}) {
    return Container(
      height: 64.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        border: isNested
            ? Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.1), width: 0.5))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: sfProText400(17.sp, Colors.white),
          ),
          Obx(() => CustomSwitch(
            // Applying requested active color #E6C571
            activeColor: const Color(0xFFE6C571),
            // Applying requested inactive color #3C3C434D (4D is 30% opacity)
            inactiveColor: const Color(0x4D3C3C43),
            value: val.value,
            onChanged: (newValue) => val.value = newValue,
          )),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon) {
    return Container(
      height: 64.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: sfProText400(17.sp, Colors.white),
          ),
          Icon(icon, color: Colors.white.withOpacity(0.3), size: 28.sp),
        ],
      ),
    );
  }
}