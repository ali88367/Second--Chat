import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/themes/textstyles.dart';
import '../../../../core/widgets/custom_switch.dart';

// 1. Controller to manage the state
class LedSettingsController extends GetxController {
  final RxBool isMilestoneEnabled = true.obs;
  final RxBool isStepEnabled = false.obs; // Initially OFF
  final RxInt milestoneStep = 5.obs;
  final RxInt customAmount = 0.obs;
}

class LedSettingsBottomSheet extends StatelessWidget {
  LedSettingsBottomSheet({super.key});

  // Initialize the controller
  final controller = Get.put(LedSettingsController());

  @override
  Widget build(BuildContext context) {
    const Color darkCharcoal = Color(0xFF2C2C2E);

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
                  child: Text("LED settings", style: sfProDisplay600(17.sp, Colors.white)),
                ),
                SizedBox(height: 12.h),

                _buildSettingGroup([_buildSwitchTile("New Followers", true.obs)]),
                SizedBox(height: 12.h),

                _buildSettingGroup([_buildSwitchTile("All Subscribers", true.obs)]),
                SizedBox(height: 12.h),

                // Group 3: Milestones
                _buildSettingGroup([
                  _buildSwitchTile("Milestone Subscribers", controller.isMilestoneEnabled),

                  // TILE: The Preset Switch (5, 10, 20...)
                  Obx(() => _buildSwitchTile(
                    controller.milestoneStep.value.toString(),
                    controller.isStepEnabled,
                    isNested: true,
                    onTap: () => _showPresetStepPicker(context),
                    onChanged: (val) {
                      controller.isStepEnabled.value = val;
                      if (val) _showPresetStepPicker(context);
                    },
                  )),

                  // TILE: The "New" Custom Number Wheel
                  Obx(() {
                    String tileTitle = controller.customAmount.value == 0
                        ? "New"
                        : controller.customAmount.value.toString();

                    return _buildActionTile(
                      tileTitle,
                      Icons.add_circle_outline, // Restored previous icon
                      onTap: () => _showWheelNumberPicker(context),
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

  // --- Helper Pickers ---

  void _showPresetStepPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0XFF1E1D20), // Matches group color
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [5, 10, 20, 50, 100].map((step) {
              return ListTile(
                title: Text(step.toString(),
                    textAlign: TextAlign.center,
                    style: sfProText400(18.sp, Colors.white)),
                onTap: () {
                  controller.milestoneStep.value = step;
                  controller.isStepEnabled.value = true;
                  Get.back();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showWheelNumberPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0XFF1E1D20),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return Container(
          height: 250.h,
          child: Column(
            children: [
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: Text("Done", style: TextStyle(color: const Color(0xFFE6C571), fontWeight: FontWeight.bold, fontSize: 16.sp)),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40.h,
                  scrollController: FixedExtentScrollController(initialItem: controller.customAmount.value),
                  onSelectedItemChanged: (int index) => controller.customAmount.value = index,
                  children: List<Widget>.generate(1001, (index) => Center(
                    child: Text(index.toString(), style: TextStyle(color: Colors.white, fontSize: 20.sp)),
                  )),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- UI Components ---

  Widget _buildSettingGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: const Color(0XFF1E1D20), borderRadius: BorderRadius.circular(27.r)),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, RxBool val, {bool isNested = false, VoidCallback? onTap, Function(bool)? onChanged}) {
    return InkWell(
      onTap: onTap, // Allows tapping the text area
      child: Container(
        height: 56.h,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        decoration: BoxDecoration(
          border: isNested ? Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: sfProText400(17.sp, Colors.white)),
            Obx(() => CustomSwitch(
              activeColor: const Color(0xFFE6C571),
              inactiveColor: const Color(0x4D3C3C43),
              value: val.value,
              onChanged: onChanged ?? (newValue) => val.value = newValue,
            )),
          ],
        ),
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
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: sfProText400(17.sp, Colors.white)),
            Icon(icon, color: Colors.white.withOpacity(0.3), size: 28.sp),
          ],
        ),
      ),
    );
  }
}