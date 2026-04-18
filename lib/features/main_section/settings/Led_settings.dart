import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/settings_controller.dart';
import '../../../../core/themes/textstyles.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/custom_switch.dart';

class LedSettingsBottomSheet extends StatelessWidget {
  LedSettingsBottomSheet({super.key});

  final SettingsController controller = Get.find<SettingsController>();

  static const Color _inactiveSwitch = Color(0x4D3C3C43);

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
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                bottom: MediaQuery.of(context).viewPadding.bottom,
              ),
              children: [
                SizedBox(height: 4.h),
                Center(
                  child: Text(
                    context.l10n.ledSettings,
                    style: sfProDisplay600(17.sp, Colors.white),
                  ),
                ),
                SizedBox(height: 12.h),

                _buildSettingGroup([
                  _buildSwitchTile(
                    context.l10n.newFollowers,
                    controller.ledNewFollowers,
                    onChanged:
                        (val) => controller.updateLedSetting('newFollowers', val),
                  ),
                ]),
                SizedBox(height: 12.h),

                _buildSettingGroup([
                  _buildSwitchTile(
                    context.l10n.allSubscribers,
                    controller.ledAllSubscribers,
                    onChanged: (val) =>
                        controller.updateLedSetting('allSubscribers', val),
                  ),
                ]),
                SizedBox(height: 12.h),

                _buildSettingGroup([
                  _buildSwitchTile(
                    context.l10n.milestoneSubscribers,
                    controller.ledMilestoneSubscribers,
                    onChanged: (val) => controller.updateLedSetting(
                      'milestoneSubscribers',
                      val,
                    ),
                  ),
                  _buildMilestoneIntervalSwitchTile(context),
                  Obx(
                    () => _buildActionTile(
                      context.l10n.ledMilestoneCustom,
                      Icons.add_circle_outline,
                      subtitle: context.l10n.ledMilestoneIntervalValue(
                        controller.ledMilestoneValue.value.toString(),
                      ),
                      onTap: () => _showWheelNumberPicker(context),
                    ),
                  ),
                ]),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPresetStepPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0XFF1E1D20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [5, 10, 20, 50, 100].map((step) {
              return ListTile(
                title: Text(
                  step.toString(),
                  textAlign: TextAlign.center,
                  style: sfProText400(18.sp, Colors.white),
                ),
                onTap: () {
                  controller.updateLedMilestoneValue(step);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showWheelNumberPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0XFF1E1D20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        int tempValue = controller.ledMilestoneValue.value.clamp(0, 1000);
        return SafeArea(
          child: SizedBox(
            height: 320.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sheetContext.l10n.ledCustomMilestoneTitle,
                        style: sfProDisplay600(18.sp, Colors.white),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        sheetContext.l10n.ledCustomMilestoneSubtitle,
                        style: sfProText400(14.sp, Colors.white70),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      controller.updateLedMilestoneValue(tempValue);
                      Navigator.of(sheetContext).pop();
                    },
                    child: Text(
                      sheetContext.l10n.done,
                      style: TextStyle(
                        color: const Color(0xFFE6C571),
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40.h,
                    scrollController: FixedExtentScrollController(
                      initialItem: tempValue.clamp(0, 1000),
                    ),
                    onSelectedItemChanged: (int index) => tempValue = index,
                    children: List<Widget>.generate(
                      1001,
                      (index) => Center(
                        child: Text(
                          index.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  /// Same pattern as other LED rows: title + [CustomSwitch]. Tap the label/subtitle to
  /// pick a preset step when preset mode is on.
  Widget _buildMilestoneIntervalSwitchTile(BuildContext context) {
    return Container(
      height: 58.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (!controller.ledMilestonePresetInterval.value) return;
                  _showPresetStepPicker(context);
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Obx(
                    () => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.ledMilestoneInterval,
                          style: sfProText400(17.sp, Colors.white),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          context.l10n.ledMilestoneIntervalValue(
                            controller.ledMilestoneValue.value.toString(),
                          ),
                          style: sfProText400(13.sp, Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Obx(
            () => CustomSwitch(
              activeColor: controller.ledSwitchAccentColor,
              inactiveColor: _inactiveSwitch,
              value: controller.ledMilestonePresetInterval.value,
              onChanged: (v) => controller.updateLedSetting(
                'milestonePresetInterval',
                v,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    RxBool val, {
    bool isNested = false,
    VoidCallback? onTap,
    ValueChanged<bool>? onChanged,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56.h,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        decoration: BoxDecoration(
          border: isNested
              ? Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: sfProText400(17.sp, Colors.white),
              ),
            ),
            Obx(
              () => CustomSwitch(
                activeColor: controller.ledSwitchAccentColor,
                inactiveColor: _inactiveSwitch,
                value: val.value,
                onChanged: onChanged ?? (newValue) => val.value = newValue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    IconData icon, {
    VoidCallback? onTap,
    String? subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: subtitle != null ? 64.h : 56.h,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: sfProText400(17.sp, Colors.white)),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: sfProText400(13.sp, Colors.white54),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(icon, color: Colors.white.withOpacity(0.3), size: 28.sp),
            ],
          ),
        ),
      ),
    );
  }
}
