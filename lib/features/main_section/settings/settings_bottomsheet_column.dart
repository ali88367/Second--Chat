import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/controllers/chat_controller.dart';
import 'package:second_chat/controllers/platform_connect_controller.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/settings_controller.dart';
import 'package:second_chat/core/constants/app_images/app_images.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/core/localization/l10n.dart';
import 'package:second_chat/features/intro/intro_screen2.dart';
import 'package:second_chat/features/main_section/settings/Led_settings.dart';
import 'package:second_chat/features/main_section/settings/profile_settings_bottomsheet.dart';
import 'package:second_chat/features/main_section/settings/settings_components/connect_platform_setting.dart';
import 'package:second_chat/features/main_section/settings/settings_components/platform_color_settings.dart';

import '../../../core/constants/app_colors/app_colors.dart';
import '../../../core/widgets/custom_black_glass_widget.dart';
import '../../../core/widgets/custom_switch.dart';

class SettingsBottomsheetColumn extends StatelessWidget {
  SettingsBottomsheetColumn({super.key});

  String _sectionTitle(BuildContext context, String raw) {
    switch (raw) {
      case 'Notifications':
        return context.l10n.settingsSectionNotifications;
      case 'CHAT':
        return context.l10n.settingsSectionChat;
      case 'LANGUAGE':
        return context.l10n.settingsSectionLanguage;
      case 'OTHER':
        return context.l10n.settingsSectionOther;
      default:
        return raw;
    }
  }

  String _tileTitle(BuildContext context, String raw) {
    switch (raw) {
      case 'Notifications':
        return context.l10n.settingsTitleNotifications;
      case 'LED Notifications':
        return context.l10n.settingsTitleLedNotifications;
      case 'Viewer Count':
        return context.l10n.settingsTitleViewerCount;
      case 'Hide Viewer Names':
        return context.l10n.settingsTitleHideViewerNames;
      case 'Show Subscribers Only':
        return context.l10n.settingsTitleShowSubscribersOnly;
      case 'Show VIP/Mods Only':
        return context.l10n.settingsTitleShowVipModsOnly;
      case 'Multi-Chat Merged Mode':
        return context.l10n.settingsTitleMultiChatMergedMode;
      case 'Font Size':
        return context.l10n.settingsTitleFontSize;
      case 'Platform Colour':
        return context.l10n.settingsTitlePlatformColour;
      case 'Connect Other Platforms':
        return context.l10n.settingsTitleConnectOtherPlatforms;
      case 'App Language':
        return context.l10n.settingsTitleAppLanguage;
      case 'Clock':
        return context.l10n.settingsTitleClock;
      case 'Time Zone Detection':
        return context.l10n.settingsTitleTimeZoneDetection;
      case 'Low Power Mode':
        return context.l10n.settingsTitleLowPowerMode;
      case 'Multi-Screen Preview':
        return context.l10n.settingsTitleMultiScreenPreview;
      case 'Animations':
        return context.l10n.settingsTitleAnimations;
      case 'Full Activity Filters':
        return context.l10n.settingsTitleFullActivityFilters;
      case 'TTS Advanced settings':
        return context.l10n.settingsTitleTtsAdvancedSettings;
      case 'Disconnect Platform':
        return context.l10n.disconnectPlatform;
      case 'Logout':
        return context.l10n.logout;
      case 'Profile':
        return context.l10n.settingsTitleProfile;
      default:
        return raw;
    }
  }

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
        "prefixFlutterIcon": Icons.person_outline,
        "title": "Profile",
        "isForward": true,
      },
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
        "isSwitch": true,
        "switchKey": "multiScreenPreview",
      },
      {
        "prefixImageAsset": animation_icon,
        "title": "Animations",
        "isLocked": true,
        "isSwitch": true,
        "switchKey": "animations",
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
        "isSwitch": true,
        "switchKey": "fullActivityFilters",
      },
      {
        "prefixImageAsset": speaker_icon,
        "title": "TTS Advanced settings",
        "isLocked": true,
        "isSwitch": true,
        "switchKey": "ttsAdvancedSettings",
      },
    ],
    "LOGOUT": [
      {
        "prefixFlutterIcon": Icons.logout,
        "title": "Logout",
        "isLogoutAction": true,
      },
    ],
  };

  Future<void> _runLogoutFlow(BuildContext context) async {
    final confirmed =
        await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: const Color(0xFF1E1D20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Text(
              context.l10n.logout,
              style: sfProText600(18.sp, Colors.white),
            ),
            content: Text(
              'Are you sure you want to log out?',
              style: sfProText400(14.sp, Colors.white70),
            ),
            actionsPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text(
                  context.l10n.cancel,
                  style: sfProText500(14.sp, Colors.white70),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                onPressed: () => Get.back(result: true),
                child: Text(
                  context.l10n.logout,
                  style: sfProText600(14.sp, Colors.black),
                ),
              ),
            ],
          ),
          barrierDismissible: true,
        ) ??
        false;

    if (!confirmed) return;

    Get.dialog(
      const _LogoutLoadingDialog(),
      barrierDismissible: false,
      useSafeArea: false,
    );

    final auth = Get.find<AuthController>();
    try {
      await auth.logoutAndClearAllStoredData();
      try {
        await Get.find<ChatController>().resetForLogout();
      } catch (_) {}
      try {
        Get.find<SettingsController>().resetAfterLogout();
      } catch (_) {}
      try {
        await Get.find<PlatformConnectController>().refreshConnections();
      } catch (_) {}
    } finally {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    }

    Get.offAll(() => const IntroScreen2());
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();
    controller.loadSettingsIfNeeded();

    return Obx(() {
      final hasData = controller.settingsPayload.value != null;
      final error = controller.settingsError.value;

      if (!hasData) {
        return _buildLoading(context, controller, error);
      }

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
                  Text(
                    context.l10n.settings,
                    style: sfProText600(17.sp, Colors.white),
                  ),
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
                  if (index == 0) {
                    return FreePlanWidget(controller: controller);
                  }
                  int sectionIndex = index - 1;
                  String sectionTitle = settingsData.keys.elementAt(
                    sectionIndex,
                  );
                  List<Map<String, dynamic>> tiles =
                      settingsData[sectionTitle]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sectionTitle.isNotEmpty &&
                          sectionTitle != "Notifications" &&
                          sectionTitle != "LOGOUT")
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                          child: Text(
                            _sectionTitle(context, sectionTitle).toUpperCase(),
                            style: sfProDisplay400(
                              13.sp,
                              const Color.fromRGBO(235, 235, 245, 0.6),
                            ),
                          ),
                        )
                      else if (sectionTitle.isEmpty)
                        SizedBox(height: 6.h)
                      else if (sectionTitle == "LOGOUT")
                        SizedBox(height: 16.h)
                      else
                        SizedBox(height: 2.h),

                      if (sectionTitle == "CHAT")
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: const ChatPlatformTabs(),
                        ),

                      Container(
                        decoration: BoxDecoration(
                          color: sectionTitle == "LOGOUT"
                              ? Colors.transparent
                              : onBottomSheetGrey,
                          borderRadius: BorderRadius.circular(
                            sectionTitle == "LOGOUT" ? 0.r : 16.r,
                          ),
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
    });
  }

  Widget _buildLoading(
    BuildContext context,
    SettingsController controller,
    String? error,
  ) {
    final errorMessage = switch (error) {
      'missingAccessToken' => context.l10n.missingAccessToken,
      'unexpectedResponseFormat' => context.l10n.unexpectedResponseFormat,
      'failedToLoadSettings' => context.l10n.failedToLoadSettings,
      _ => context.l10n.failedToLoadSettings,
    };
    final Widget content =
        error != null
            ? GestureDetector(
              onTap: () => controller.loadSettings(force: true),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 24.w),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: onBottomSheetGrey,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      errorMessage,
                      style: sfProDisplay600(16.sp, Colors.white),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      context.l10n.tapToRetry,
                      style: sfProText400(13.sp, Colors.white60),
                    ),
                  ],
                ),
              ),
            )
            : Container(
              margin: EdgeInsets.symmetric(horizontal: 24.w),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: onBottomSheetGrey,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    context.l10n.loadingSettings,
                    style: sfProText500(14.sp, Colors.white70),
                  ),
                ],
              ),
            );

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
                Text(
                  context.l10n.settings,
                  style: sfProText600(17.sp, Colors.white),
                ),
                SizedBox(width: 44.w),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Expanded(child: Center(child: content)),
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
    final bool isLogoutAction = tile["isLogoutAction"] == true;
    final String? switchKey = tile["switchKey"];
    final String? openAsBottomSheet = tile["openAsBottomSheet"];
    final String? customForwardIcon = tile["customForwardIcon"];

    // Declare key here â€” each tile gets its own unique key
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
        case "multiScreenPreview":
          switchValue = controller.multiScreenPreview;
          break;
        case "animations":
          switchValue = controller.animations;
          break;
        case "fullActivityFilters":
          switchValue = controller.fullActivityFilters;
          break;
        case "ttsAdvancedSettings":
          switchValue = controller.ttsAdvancedSettings;
          break;
      }
    }

    Color getBaseColor() {
      final platform = controller.selectedPlatform.value;
      if (platform.toLowerCase() == "all") {
        // Keep a neutral readable accent in feed when "All" is selected.
        return const Color.fromRGBO(255, 230, 167, 1);
      }
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
                          controller.updateFontSize(selected);
                          break;
                        case "App Language":
                          controller.updateAppLanguage(selected);
                          break;
                        case "Clock":
                          controller.updateClockFormat(selected);
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
          padding: EdgeInsets.symmetric(horizontal: isLogoutAction ? 0.w : 16.w),
          decoration: BoxDecoration(
            color: isLogoutAction
                ? const Color(0xFF5C0606)
                : isActuallyLocked
                    ? const Color.fromRGBO(20, 18, 18, 1)
                    : null,
            borderRadius: isLogoutAction ? BorderRadius.circular(999.r) : null,
            border: (!isLogoutAction && index > 0)
                ? Border(
                    top: BorderSide(
                      width: 0.5.w,
                      color: const Color.fromRGBO(120, 120, 128, 0.36),
                    ),
                  )
                : null,
          ),
          child: InkWell(
            borderRadius:
                isLogoutAction ? BorderRadius.circular(999.r) : null,
            onTap: () {
              if (tile["isLogoutAction"] == true) {
                _runLogoutFlow(context);
                return;
              }
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

              if (tile["title"] == "Profile") {
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
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(36.r),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(36.r),
                          child: const ProfileSettingsBottomSheet(),
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
                                  ? LedSettingsBottomSheet()
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
            child: isLogoutAction
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w),
                    child: Row(
                      children: [
                        Image.asset("assets/images/logouticon.png", width: 24.w, height: 24.h),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Log Out',
                            style: sfProText400(17.sp, Colors.white),
                          ),
                        ),
                        Container(
                          width: 23.w,
                          height: 23.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16.sp,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Obx(() {
                        final iconColor = getBaseColor().withOpacity(opacity);
                        if ((tile["prefixFlutterIcon"] as IconData?) != null) {
                          return Icon(
                            (tile["prefixFlutterIcon"] as IconData?)!,
                            size: 24.sp,
                            color: iconColor,
                          );
                        }
                        return Image.asset(
                          tile["prefixImageAsset"],
                          width: 24.w,
                          height: 24.h,
                          color: iconColor,
                        );
                      }),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          _tileTitle(context, tile["title"]),
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
                            _buildSwitch(
                              switchValue!,
                              getBaseColor,
                              controller,
                              switchKey,
                            ),
                          if ((isForward || openAsBottomSheet != null) &&
                              !isActuallyLocked)
                            Padding(
                              padding: EdgeInsets.only(left: 4.w),
                              child: GestureDetector(
                                key: iconKey,
                                onTap:
                                    customForwardIcon ==
                                            "assets/images/changer.png"
                                        ? showGlassSelector
                                        : null,
                                child: Image.asset(
                                  customForwardIcon ?? forward_arrow_icon,
                                  height:
                                      customForwardIcon != null ? 12.h : 28.h,
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
    RxBool switchValue,
    Color Function() getBaseColor,
    SettingsController controller,
    String? switchKey,
  ) {
    return Obx(() {
      final baseColor = getBaseColor();
      return CustomSwitch(
        value: switchValue.value,
        onChanged: (val) {
          if (switchKey != null) {
            controller.updateToggle(switchKey, val);
          } else {
            switchValue.value = val;
          }
        },
        activeColor: baseColor,
      );
    });
  }
}

class _LogoutLoadingDialog extends StatelessWidget {
  const _LogoutLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final accent = beige;
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color.fromRGBO(0, 0, 0, 0.62),
        child: Center(
          child: Container(
            width: 286.w,
            constraints: BoxConstraints(minHeight: 220.h),
            padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 18.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
              ),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.08),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.35),
                  blurRadius: 24,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78.w,
                  height: 78.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.35),
                        const Color.fromRGBO(255, 255, 255, 0.0),
                      ],
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 48.w,
                      height: 48.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2.8,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                            backgroundColor: const Color.fromRGBO(
                              255,
                              255,
                              255,
                              0.15,
                            ),
                          ),
                          Icon(
                            Icons.logout_rounded,
                            size: 19.sp,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Logging out...',
                  style: sfProDisplay600(20.sp, Colors.white),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Please wait while we secure your session.',
                  textAlign: TextAlign.center,
                  style: sfProText400(
                    13.sp,
                    const Color.fromRGBO(235, 235, 245, 0.68),
                  ),
                ),
                SizedBox(height: 14.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99.r),
                  child: LinearProgressIndicator(
                    minHeight: 4.h,
                    color: accent,
                    backgroundColor: const Color.fromRGBO(255, 255, 255, 0.14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FreePlanWidget extends StatefulWidget {
  const FreePlanWidget({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<FreePlanWidget> createState() => _FreePlanWidgetState();
}

class _FreePlanWidgetState extends State<FreePlanWidget> {
  bool _showSubscribe = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final account =
          widget.controller.settingsPayload.value?['account'] as Map?;
      final plan = (account?['yourPlan'] ?? 'Free').toString();
      final price =
          (account?['premiumPerMonth'] ?? '£4.99 per month').toString();
      final isPremium = account?['isPremium'] == true;
      final planLabel = isPremium ? 'Premium' : plan;

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
                        price,
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
                            context.l10n.yourPlan,
                            style: sfProDisplay600(
                              17.sp,
                              Colors.white.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            planLabel,
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
                                  gradient: LinearGradient(
                                    colors: [beige, beige],
                                  ),
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                child: Center(
                                  child: Text(
                                    context.l10n.subscribe,
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
    });
  }
}

class ChatPlatformTabs extends StatelessWidget {
  const ChatPlatformTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();
    final List<String> tabs = ["All", "Twitch", "Kick", "YouTube"];

    return Container(
      height: 40.h,
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
            for (int i = 0; i < tabs.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w),
                  child: GestureDetector(
                    onTap: () => controller.selectedPlatform.value = tabs[i],
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tabBackgroundColor(
                          controller,
                          tabs[i],
                          isSelected: selected == tabs[i],
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color:
                              selected == tabs[i]
                                  ? Colors.white.withOpacity(0.24)
                                  : Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          color: _tabTextColor(
                            controller,
                            tabs[i],
                            isSelected: selected == tabs[i],
                          ),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Color _tabBackgroundColor(
    SettingsController controller,
    String tab, {
    required bool isSelected,
  }) {
    const neutralBlack = Color.fromRGBO(22, 22, 22, 1);
    if (!isSelected) return neutralBlack;
    if (tab.toLowerCase() == 'all') return neutralBlack;
    return controller.getPlatformColor(tab);
  }

  Color _tabTextColor(
    SettingsController controller,
    String tab, {
    required bool isSelected,
  }) {
    if (!isSelected) {
      return Colors.white.withOpacity(0.82);
    }
    final background = _tabBackgroundColor(
      controller,
      tab,
      isSelected: isSelected,
    );
    return _readableTextColor(background);
  }

  Color _readableTextColor(Color background) {
    // Guarantee text never blends with selected tab background.
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
