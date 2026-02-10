import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
// Ensure these imports exist in your project, or remove if copying standalone
import '../../../../core/constants/app_colors/app_colors.dart';
import '../../../../core/themes/textstyles.dart';
import '../../../../core/widgets/custom_switch.dart';
import '../../../../core/constants/app_images/app_images.dart';

class LedSettingsBottomSheet extends StatelessWidget {
  const LedSettingsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkCharcoal = Color(0xFF2C2C2E);

    // Reactive variable to store the selected time.
    // Null initially (shows "New").
    final Rx<DateTime?> selectedTime = Rx<DateTime?>(null);

    return Container(
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
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                bottom: MediaQuery.of(context).viewPadding.bottom,
              ),
              children: [
                SizedBox(height: 4.h),
                Center(
                  child: Text(
                    "LED settings",
                    style: sfProDisplay600(17.sp, Colors.white),
                  ),
                ),
                SizedBox(height: 12.h),

                // Group 1
                _buildSettingGroup([
                  _buildSwitchTile("New Followers", true.obs),
                ]),
                SizedBox(height: 12.h),

                // Group 2
                _buildSettingGroup([
                  _buildSwitchTile("All Subscribers", true.obs),
                ]),
                SizedBox(height: 12.h),

                // Group 3: Milestones
                _buildSettingGroup([
                  _buildSwitchTile("Milestone Subscribers", true.obs),
                  _buildSwitchTile("5", true.obs, isNested: true),

                  // UPDATED: Wrapped in Obx to update text dynamically
                  Obx(() {
                    // Determine what text to show
                    String tileTitle = "New";
                    if (selectedTime.value != null) {
                      // Format the time (e.g. "5:30 PM")
                      tileTitle = TimeOfDay.fromDateTime(selectedTime.value!)
                          .format(context);
                    }

                    return _buildActionTile(
                      tileTitle,
                      Icons.add_circle_outline,
                      onTap: () => _showWheelTimePicker(
                        context,
                        initialTime: selectedTime.value,
                        onTimeSelected: (pickedDate) {
                          selectedTime.value = pickedDate;
                        },
                      ),
                    );
                  }),
                ]),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UPDATED: Accepts initialTime and an onTimeSelected callback ---
  void _showWheelTimePicker(
      BuildContext context, {
        DateTime? initialTime,
        required Function(DateTime) onTimeSelected,
      }) {
    // Default to now if no time was previously selected
    DateTime tempPickedDate = initialTime ?? DateTime.now();

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300.h,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        child: Column(
          children: [
            // Toolbar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Text("Cancel", style: sfProText400(15.sp, Colors.white54)),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Pass the selected time back to the main widget
                      onTimeSelected(tempPickedDate);
                      Get.back();
                    },
                    child: Text(
                      "Done",
                      style: sfProText400(15.sp, const Color(0xFFE6C571)),
                    ),
                  ),
                ],
              ),
            ),
            // The Time Picker
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: tempPickedDate,
                  use24hFormat: false,
                  onDateTimeChanged: (val) {
                    tempPickedDate = val;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0XFF1E1D20),
        borderRadius: BorderRadius.circular(27.r),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, RxBool val, {bool isNested = false}) {
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        border: isNested
            ? Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
        )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: sfProText400(17.sp, Colors.white)),
          Obx(
                () => CustomSwitch(
              activeColor: const Color(0xFFE6C571),
              inactiveColor: const Color(0x4D3C3C43),
              value: val.value,
              onChanged: (newValue) => val.value = newValue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56.h,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // This title will now show the Time if selected
            Text(title, style: sfProText400(17.sp, Colors.white)),
            Icon(icon, color: Colors.white.withOpacity(0.3), size: 28.sp),
          ],
        ),
      ),
    );
  }
}