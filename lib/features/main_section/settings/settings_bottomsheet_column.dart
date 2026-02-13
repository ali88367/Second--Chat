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
import '../../../core/widgets/custom_black_glass_widget.dart';
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
        "customForwardIcon": "assets/images/changer.png",
      },
    ],
    "OTHER": [
      {
        "prefixImageAsset": screen_icon,
        "title": "Multi-Screen Preview",
        "isLocked": true,
      },
      {
        "prefixImageAsset": animation_icon,
        "title": "Animations",
        "isLocked": true,
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
      },
      {
        "prefixImageAsset": speaker_icon,
        "title": "TTS Advanced settings",
        "isLocked": true,
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();

    return SafeArea(
      top: false,
      child: Column(
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
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                top: 10.h,
                bottom: 10.h + MediaQuery.of(context).viewPadding.bottom,
              ),
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

                    Container(
                      decoration: BoxDecoration(
                        color: onBottomSheetGrey,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Column(
                        children:
                            tiles.asMap().entries.map((entry) {
                              int tileIndex = entry.key;
                              Map<String, dynamic> tile = entry.value;
                              return _buildTile(
                                tile,
                                controller,
                                tileIndex,
                                sectionTitle,
                                context,
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
      ),
    );
  }

  Widget _buildTile(
    Map<String, dynamic> tile,
    SettingsController controller,
    int index,
    String sectionTitle,
    BuildContext context,
  ) {
    final bool isSwitch = tile["isSwitch"] ?? false;
    final bool isForward = tile["isForward"] ?? false;
    final bool isLocked = tile["isLocked"] ?? false;
    final String? switchKey = tile["switchKey"];
    final String? openAsBottomSheet = tile["openAsBottomSheet"];
    final String? customForwardIcon = tile["customForwardIcon"];

    // Declare key here — each tile gets its own unique key
    final GlobalKey iconKey = GlobalKey();

    RxBool? switchValue;
    // For locked items with switchKey, show switch when unlocked
    if (switchKey != null) {
      switch (switchKey) {
        case "notifications":
          switchValue = controller.notifications;
          break;
        case "ledNotifications":
          switchValue = controller.ledNotifications;
          break;
        case "viewerCount":
          switchValue = controller.viewerCount;
          break;
        case "hideViewerNames":
          switchValue = controller.hideViewerNames;
          break;
        case "lowPowerMode":
          switchValue = controller.lowPowerMode;
          break;
        case "timeZoneDetection":
          switchValue = controller.timeZoneDetection;
          break;
        case "showSubscribersOnly":
          switchValue = controller.showSubscribersOnly;
          break;
        case "showVipsOnly":
          switchValue = controller.showVipsOnly;
          break;
        case "multiChatMergedMode":
          switchValue = controller.multiChatMergedMode;
          break;
      }
    }

    Color getBaseColor() {
      if (sectionTitle != "CHAT") return const Color.fromRGBO(255, 230, 167, 1);
      final platform = controller.selectedPlatform.value;
      if (platform == "All") return const Color.fromRGBO(255, 230, 167, 1);
      return controller.getPlatformColor(platform);
    }

    void showGlassSelector() {
      final RenderBox? overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      final RenderBox? iconBox =
          iconKey.currentContext?.findRenderObject() as RenderBox?;

      if (iconBox == null || overlay == null) return;

      final Offset iconPosition = iconBox.localToGlobal(Offset.zero);
      final Size iconSize = iconBox.size;

      List<String> options = [];
      switch (tile["title"]) {
        case "Font Size":
          options = ["S", "M", "L", "XL"];
          break;
        case "App Language":
          options = [
            "English",
            "Spanish",
            "Arabic",
            "Portuguese",
            "German",
            "French",
          ];
          break;
        case "Clock":
          options = ["12h", "24h"];
          break;
        default:
          return;
      }

      showGeneralDialog(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Stack(
            children: [
              Positioned(
                bottom: overlay.size.height - iconPosition.dy - 15.h,
                right:
                    overlay.size.width -
                    (iconPosition.dx + iconSize.width) -
                    20.w,
                child: Material(
                  color: Colors.transparent,
                  child: CustomBlackGlassWidget(
                    isWeek: false,
                    items: options,
                    onItemSelected: (selected) {
                      switch (tile["title"]) {
                        case "Font Size":
                          controller.fontSize.value = selected;
                          break;
                        case "App Language":
                          controller.appLanguage.value = selected;
                          break;
                        case "Clock":
                          controller.clockFormat.value = selected;
                          break;
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
      );
    }

    // Build the tile - use GetBuilder for unlock state to avoid GetX tracking issues
    return GetBuilder<SettingsController>(
      id: 'premium_unlock',
      builder: (controller) {
        final bool isActuallyLocked =
            isLocked && !controller.isPremiumUnlocked.value;
        final double opacity = isActuallyLocked ? 0.4 : 1.0;
        final bool shouldShowSwitch =
            (isSwitch || (isLocked && switchKey != null)) &&
            !isActuallyLocked &&
            switchValue != null;

        return Container(
          height: 56.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color:
                isActuallyLocked ? const Color.fromRGBO(20, 18, 18, 1) : null,
            border:
                index > 0
                    ? Border(
                      top: BorderSide(
                        width: 0.5.w,
                        color: const Color.fromRGBO(120, 120, 128, 0.36),
                      ),
                    )
                    : null,
          ),
          child: InkWell(
            onTap: () {
              if (isActuallyLocked) {
                Get.bottomSheet(
                  Padding(
                    padding: EdgeInsets.only(
                      left: 12.w,
                      right: 12.w,
                      bottom: 25.h,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        constraints: BoxConstraints(maxHeight: 600.h),
                        child: GestureDetector(
                          onTap: () {
                            // Unlock all premium features
                            controller.isPremiumUnlocked.value = true;
                            controller.update([
                              'premium_unlock',
                            ]); // Update GetBuilder
                            Get.back(); // Close the unlock bottom sheet
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(36.r),
                            child: Image.asset(
                              "assets/images/premium.png",
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  isDismissible: true,
                  enableDrag: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                );
                return;
              }

              if (customForwardIcon == "assets/images/changer.png") {
                showGlassSelector();
                return;
              }

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
                        height:
                            tile["title"] == "LED Notifications"
                                ? 386.h
                                : 730.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(36.r),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(36.r),
                          child:
                              tile["title"] == "LED Notifications"
                                  ?  LedSettingsBottomSheet()
                                  : openAsBottomSheet == "connect"
                                  ? ConnectPlatformSetting()
                                  : PlatformColorSettings(),
                        ),
                      ),
                    ),
                  ),
                  isDismissible: true,
                  isScrollControlled: true,
                  enableDrag: true,
                  backgroundColor: Colors.transparent,
                );
                return;
              }

              if (isForward && tile["nextPage"] != null) {
                Get.toNamed(tile["nextPage"]);
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
                        child: _buildSuffixText(tile, controller, opacity),
                      ),
                    if (shouldShowSwitch)
                      _buildSwitch(sectionTitle, switchValue!, getBaseColor),
                    if ((isForward || openAsBottomSheet != null) &&
                        !isActuallyLocked)
                      Padding(
                        padding: EdgeInsets.only(left: 4.w),
                        child: GestureDetector(
                          key: iconKey,
                          onTap:
                              customForwardIcon == "assets/images/changer.png"
                                  ? showGlassSelector
                                  : null,
                          child: Image.asset(
                            customForwardIcon ?? forward_arrow_icon,
                            height: customForwardIcon != null ? 12.h : 28.h,
                          ),
                        ),
                      ),
                    if (isActuallyLocked)
                      Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: Image.asset(key_icon_2, height: 28.h),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuffixText(
    Map<String, dynamic> tile,
    SettingsController controller,
    double opacity,
  ) {
    return Obx(() {
      String display = tile["suffixText"];
      if (tile["title"] == "Font Size") display = controller.fontSize.value;
      if (tile["title"] == "App Language")
        display = controller.appLanguage.value;
      if (tile["title"] == "Clock") display = controller.clockFormat.value;
      return Text(
        display,
        style: TextStyle(
          color: Color.fromRGBO(235, 235, 245, 0.6 * opacity),
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
        ),
      );
    });
  }

  Widget _buildSwitch(
    String sectionTitle,
    RxBool switchValue,
    Color Function() getBaseColor,
  ) {
    return Obx(() {
      final baseColor =
          sectionTitle == "CHAT"
              ? getBaseColor()
              : const Color.fromRGBO(255, 230, 167, 1);
      return CustomSwitch(
        value: switchValue.value,
        onChanged: (val) => switchValue.value = val,
        activeColor: baseColor,
      );
    });
  }
}

class FreePlanWidget extends StatefulWidget {
  const FreePlanWidget({super.key});

  @override
  State<FreePlanWidget> createState() => _FreePlanWidgetState();
}

class _FreePlanWidgetState extends State<FreePlanWidget> {
  bool _showSubscribe = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showSubscribe = !_showSubscribe;
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: onBottomSheetGrey,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "£4.99 per month",
                      style: sfProDisplay400(
                        13.sp,
                        Colors.white.withOpacity(0.5),
                      ),
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
                        Text(
                          "Free",
                          style: sfProDisplay600(20.sp, Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
                Image.asset(key_icon, height: 76.h),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child:
                  _showSubscribe
                      ? Column(
                        children: [
                          SizedBox(height: 12.h),
                          GestureDetector(
                            onTap: () {
                              // TODO: Navigate to subscription page
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF2E7D32),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Center(
                                child: Text(
                                  "Subscribe",
                                  style: sfProText600(15.sp, Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
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
                child: GestureDetector(
                  onTap: () => controller.selectedPlatform.value = tabs[i],
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          selected == tabs[i]
                              ? _getPlatformColor(controller, "All")
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      tabs[i],
                      style: TextStyle(
                        color:
                            tabs[i] == "All"
                                ? Colors.white
                                : _getPlatformColor(controller, tabs[i]),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (i != tabs.length - 1)
                Container(
                  width: 1.w,
                  height: 18.h,
                  color:
                      selected == tabs[i] || selected == tabs[i + 1]
                          ? Colors.transparent
                          : Colors.grey.withOpacity(0.3),
                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                ),
            ],
          ],
        );
      }),
    );
  }

  Color _getPlatformColor(SettingsController controller, String tab) {
    return controller.getPlatformColor(tab);
  }
}
