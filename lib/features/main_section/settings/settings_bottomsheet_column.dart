import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/settings_controller.dart';
import 'package:second_chat/core/constants/app_images/app_images.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/features/main_section/settings/Led_settings.dart';
import 'package:second_chat/features/main_section/settings/settings_components/connect_platform_setting.dart';
import 'package:second_chat/features/main_section/settings/settings_components/platform_color_settings.dart';
import '../../../core/constants/app_colors/app_colors.dart';
import '../../../core/widgets/custom_switch.dart';

class SettingsBottomsheetColumn extends StatelessWidget {
  SettingsBottomsheetColumn({super.key});

  final Map<String, List<Map<String, dynamic>>> settingsData = {
    "Notifications": [
      {
        "prefixImageAsset": bell_icon,
        "title": "Notifications",
        "isSwitch": true,
        "switchKey": "notifications",
      },
      {
        "prefixImageAsset": light_bulb_icon,
        "title": "LED Notifications",
        "isSwitch": true,
        "isForward": true,
        "switchKey": "ledNotifications",
      },
    ],
    "": [
      {
        "prefixImageAsset": linking_icon,
        "title": "Connect Other Platforms",
        "isForward": true,
        "openAsBottomSheet": "connect",
      },
    ],
    "CHAT": [
      {
        "prefixImageAsset": font_size_icon,
        "title": "Font Size",
        "suffixText": "M",
        "isForward": true,
        "nextPage": "/font-size",
        "customForwardIcon": "assets/images/changer.png",
      },
      {
        "prefixImageAsset": subscribers_icon,
        "title": "Show Subscribers Only",
        "switchKey": "showSubscribersOnly",
        "isLocked": true,
      },
      {
        "prefixImageAsset": verified_icon,
        "title": "Show VIP/Mods Only",
        "switchKey": "showVipsOnly",
        "isLocked": true,
      },
      {
        "prefixImageAsset": view_count_icon,
        "title": "Viewer Count",
        "isSwitch": true,
        "switchKey": "viewerCount",
      },
      {
        "prefixImageAsset": privacy_icon,
        "title": "Hide Viewer Names",
        "isSwitch": true,
        "switchKey": "hideViewerNames",
      },
      {
        "prefixImageAsset": multi_chat_icon,
        "title": "Multi-Chat Merged Mode",
        "switchKey": "multiChatMergedMode",
        "isLocked": true,
      },
      {
        "prefixImageAsset": color_brush_icon,
        "title": "Platform Colour",
        "isForward": true,
        "openAsBottomSheet": "color",
      },
    ],
    "LANGUAGE": [
      {
        "prefixImageAsset": language_icon,
        "title": "App Language",
        "suffixText": "English",
        "isForward": true,
        "customForwardIcon": "assets/images/changer.png",
        "nextPage": "/language",
      },
      {
        "prefixImageAsset": time_zone_icon,
        "title": "Time Zone Detection",
        "isSwitch": true,
        "switchKey": "timeZoneDetection",
      },
      {
        "prefixImageAsset": "assets/icons/clock_icon.png",
        "title": "Clock",
        "suffixText": "12h",
        "isForward": true,
        "nextPage": "/clock",
        "customForwardIcon": "assets/images/changer.png",
      },
    ],
    "OTHER": [
      {
        "prefixImageAsset": screen_icon,
        "title": "Multi-Screen Preview",
        "isLocked": true,
        "nextPage": "/multi-screen",
      },
      {
        "prefixImageAsset": animation_icon,
        "title": "Animations",
        "isLocked": true,
        "nextPage": "/animations",
      },
      {
        "prefixImageAsset": low_battery_icon,
        "title": "Low Power Mode",
        "isSwitch": true,
        "switchKey": "lowPowerMode",
      },
      {
        "prefixImageAsset": filter_icon,
        "title": "Full Activity Filters",
        "isLocked": true,
        "nextPage": "/activity-filters",
      },
      {
        "prefixImageAsset": speaker_icon,
        "title": "TTS Advanced settings",
        "isLocked": true,
        "nextPage": "/tts-settings",
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();

    return Column(
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => Get.back(),
                child: Image.asset(x_icon, height: 44.h),
              ),
              Text("Settings", style: sfProText600(17.sp, Colors.white)),
              SizedBox(width: 44.w),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            itemCount: settingsData.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return const FreePlanWidget();

              int sectionIndex = index - 1;
              String sectionTitle = settingsData.keys.elementAt(sectionIndex);
              List<Map<String, dynamic>> tiles = settingsData[sectionTitle]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sectionTitle.isNotEmpty &&
                      sectionTitle != "Notifications")
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                      child: Text(
                        sectionTitle.toUpperCase(),
                        style: sfProDisplay400(
                          13.sp,
                          const Color.fromRGBO(235, 235, 245, 0.6),
                        ),
                      ),
                    )
                  else if (sectionTitle.isEmpty)
                    SizedBox(height: 6.h)
                  else
                    SizedBox(height: 2.h),

                  if (sectionTitle == "CHAT")
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: const ChatPlatformTabs(),
                    ),

                  // Container background is STATIC here (Grey)
                  Container(
                    decoration: BoxDecoration(
                      color: onBottomSheetGrey,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      children: tiles.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> tile = entry.value;
                        // Passing sectionTitle to handle CHAT logic
                        return _buildTile(
                          tile,
                          controller,
                          index,
                          sectionTitle,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTile(
    Map<String, dynamic> tile,
    SettingsController controller,
    int index,
    String sectionTitle,
  ) {
    final bool isSwitch = tile["isSwitch"] ?? false;
    final bool isForward = tile["isForward"] ?? false;
    final bool isLocked = tile["isLocked"] ?? false;
    final String? switchKey = tile["switchKey"];
    final String? openAsBottomSheet = tile["openAsBottomSheet"];
    final String? customForwardIcon = tile["customForwardIcon"];

    RxBool? switchObs;
    if (isSwitch && switchKey != null) {
      switch (switchKey) {
        case "notifications":
          switchObs = controller.notifications;
          break;
        case "ledNotifications":
          switchObs = controller.ledNotifications;
          break;
        case "viewerCount":
          switchObs = controller.viewerCount;
          break;
        case "hideViewerNames":
          switchObs = controller.hideViewerNames;
          break;
        case "lowPowerMode":
          switchObs = controller.lowPowerMode;
          break;
        case "timeZoneDetection":
          switchObs = true.obs;
          break;
      }
    }

    final double opacity = isLocked ? 0.4 : 1.0;

    Color getBaseColor() {
      if (sectionTitle != "CHAT") {
        return const Color.fromRGBO(255, 230, 167, 1);
      }
      switch (controller.selectedPlatform.value) {
        case "Twitch":
          return twitchPurple;
        case "Kick":
          return kickGreen;
        case "YouTube":
          return youtubeRed;
        default:
          return const Color.fromRGBO(255, 230, 167, 1);
      }
    }

    return Stack(
      children: [
        Container(
          height: 56.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: isLocked ? const Color.fromRGBO(20, 18, 18, 1) : null,
            border: index > 0
                ? Border(
                    top: BorderSide(
                      width: 0.5.w,
                      color: const Color.fromRGBO(120, 120, 128, 0.36),
                    ),
                  )
                : null,
          ),
          child: InkWell(
            // Logic updated here
            onTap: () {
              // 1. Handle Locked Tiles (Premium Popup)
              if (isLocked) {
                Get.bottomSheet(
                  // The Widget to display
                  Padding(
                    padding: EdgeInsets.only(
                      left: 12.w,
                      right: 12.w,
                      bottom: 25.h,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        // Adjust constraints if necessary
                        constraints: BoxConstraints(maxHeight: 600.h),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(36.r),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Handle bar

                            // The Premium Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(36.r),
                              child: Image.asset(
                                "assets/images/premium.png", // Ensure this path is correct
                                fit: BoxFit.contain,
                                width: double.infinity,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Configuration arguments
                  isDismissible: true,
                  enableDrag: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  enterBottomSheetDuration: const Duration(milliseconds: 300),
                  exitBottomSheetDuration: const Duration(milliseconds: 250),
                );
                return; // Stop here if locked
              }

              // 2. Standard Logic (Existing code)
              if (tile["title"] == "LED Notifications" ||
                  openAsBottomSheet != null) {
                if (openAsBottomSheet != null) Get.back();

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
                        height: tile["title"] == "LED Notifications"
                            ? 386.h
                            : 730.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(36.r),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(36.r),
                          child: tile["title"] == "LED Notifications"
                              ? const LedSettingsBottomSheet()
                              : (openAsBottomSheet == "connect"
                                    ? ConnectPlatformSetting()
                                    : PlatformColorSettings()),
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
                );
                return;
              }

              if (isForward && tile["nextPage"] != null) {
                Get.toNamed(tile["nextPage"]!);
              } else if (isSwitch && switchObs != null) {
                switchObs.toggle();
              }
            },
            child: Row(
              children: [
                if (sectionTitle == "CHAT")
                  Obx(
                    () => Image.asset(
                      tile["prefixImageAsset"],
                      width: 24.w,
                      height: 24.h,
                      color: getBaseColor().withOpacity(opacity),
                    ),
                  )
                else
                  Image.asset(
                    tile["prefixImageAsset"],
                    width: 24.w,
                    height: 24.h,
                    color: const Color.fromRGBO(
                      255,
                      230,
                      167,
                      1,
                    ).withOpacity(opacity),
                  ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    tile["title"],
                    style: sfProText400(
                      16.sp,
                      Colors.white.withOpacity(opacity),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tile["suffixText"] != null)
                      Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: Text(
                          tile["suffixText"],
                          style: TextStyle(
                            color: Color.fromRGBO(235, 235, 245, 0.6 * opacity),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (isSwitch && switchObs != null)
                      if (sectionTitle == "CHAT")
                        Obx(
                          () => CustomSwitch(
                            value: switchObs!.value,
                            onChanged: (val) => switchObs!.value = val,
                            activeColor: getBaseColor(),
                          ),
                        )
                      else
                        Obx(
                          () => CustomSwitch(
                            value: switchObs!.value,
                            onChanged: (val) => switchObs!.value = val,
                            activeColor: const Color.fromRGBO(255, 230, 167, 1),
                          ),
                        ),
                    if (isForward || openAsBottomSheet != null)
                      Padding(
                        padding: EdgeInsets.only(left: 4.w),
                        child: Image.asset(
                          customForwardIcon ?? forward_arrow_icon,
                          height: customForwardIcon != null ? 12.h : 28.h,
                        ),
                      ),

                    if (isLocked)
                      Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: Image.asset(key_icon_2, height: 28.h),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FreePlanWidget extends StatelessWidget {
  const FreePlanWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: onBottomSheetGrey,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "£4.99 per month",
                style: sfProDisplay400(13.sp, Colors.white.withOpacity(0.5)),
              ),
              SizedBox(height: 4.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "Your Plan",
                    style: sfProDisplay600(
                      17.sp,
                      Colors.white.withOpacity(0.6),
                    ),
                  ),

                  Text("Free", style: sfProDisplay600(20.sp, Colors.white)),
                ],
              ),
            ],
          ),
          Image.asset(key_icon, height: 76.h),
        ],
      ),
    );
  }
}

class ChatPlatformTabs extends StatelessWidget {
  const ChatPlatformTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();
    final List<String> tabs = ["All", "Twitch", "Kick", "YouTube"];

    return Container(
      height: 36.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: onBottomSheetGrey,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(3.w),
      child: Obx(() {
        final selected = controller.selectedPlatform.value;

        return Row(
          children: [
            for (int i = 0; i < tabs.length; i++) ...[
              Expanded(
                child: Builder(
                  builder: (context) {
                    final String tab = tabs[i];
                    final bool isSelected = selected == tab;

                    Color getTextColor() {
                      if (isSelected) return Colors.white;
                      switch (tab) {
                        case "Twitch":
                          return twitchPurple;
                        case "Kick":
                          return kickGreen;
                        case "YouTube":
                          return youtubeRed;
                        default:
                          return Colors.grey;
                      }
                    }

                    Color getBackgroundColor() {
                      if (!isSelected) return Colors.transparent;
                      switch (tab) {
                        case "Twitch":
                          return twitchPurple;
                        case "Kick":
                          return kickGreen;
                        case "YouTube":
                          return youtubeRed;
                        default:
                          return Colors.black;
                      }
                    }

                    return GestureDetector(
                      onTap: () => controller.selectedPlatform.value = tab,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: getBackgroundColor(),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          tab,
                          style: TextStyle(
                            color: getTextColor(),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (i != tabs.length - 1)
                Builder(
                  builder: (context) {
                    final bool leftIsSelected = selected == tabs[i];
                    final bool rightIsSelected = selected == tabs[i + 1];
                    final bool hideDivider = leftIsSelected || rightIsSelected;

                    return Container(
                      width: 1.w,
                      height: 18.h,
                      color: hideDivider
                          ? Colors.transparent
                          : Colors.grey.withOpacity(0.3),
                      margin: EdgeInsets.symmetric(horizontal: 2.w),
                    );
                  },
                ),
            ],
          ],
        );
      }),
    );
  }
}
