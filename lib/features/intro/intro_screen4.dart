import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/features/intro/intro_screen5.dart';

import '../../core/localization/l10n.dart';
import '../../core/themes/textstyles.dart';

// GetX Controller
class IntroScreen4Controller extends GetxController {
  var isLoading = false.obs;

  void startTrial() async {
    isLoading.value = true;

    isLoading.value = false;

    // Navigate to IntroScreen5 using GetX
    Get.to(
      () => const IntroScreen5(),
      transition: Transition.cupertino,
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
    );
  }
}

class BadgeIcon {
  final String imagePath;
  final double? width;
  final double? height;

  const BadgeIcon(this.imagePath, {this.width, this.height});
}

class FeatureRowData {
  final String label;
  final bool isFree;
  final BadgeIcon badge;

  const FeatureRowData(this.label, this.isFree, this.badge);
}

class IntroScreen4 extends StatefulWidget {
  const IntroScreen4({Key? key}) : super(key: key);

  @override
  State<IntroScreen4> createState() => _IntroScreen4State();
}

class _IntroScreen4State extends State<IntroScreen4> {
  final ScrollController _freeScrollController = ScrollController();
  final ScrollController _premiumScrollController = ScrollController();
  bool _isSyncing = false;

  List<FeatureRowData> _features(BuildContext context) => [
        FeatureRowData(
          context.l10n.featureMultiPlatformChat,
          true,
          const BadgeIcon('assets/images/checkInfo.png', width: 49, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureMultiStreamMonitor,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureActivityFeed,
          true,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureTitleCategoryManage,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureEdgeLedNotification,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureAdvancedChatFilters,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureCustomNotification,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureAnalytics,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureAnimatedElements,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.streamStreak,
          true,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureAdvancedChatFilters,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureAllTitleCategory,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureAdFree,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureEarlyAccessUpdates,
          false,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureReferAFriendRewards,
          true,
          const BadgeIcon('assets/images/checkInfo.png', width: 59, height: 28),
        ),
        FeatureRowData(
          context.l10n.featureSupportLevel,
          true,
          const BadgeIcon('assets/images/24-7.png', width: 69, height: 33),
        ),
      ];

  @override
  void initState() {
    super.initState();
    // Sync Free column scroll to Premium column
    _freeScrollController.addListener(_syncFreeToPremiun);
    // Sync Premium column scroll to Free column
    _premiumScrollController.addListener(_syncPremiumToFree);
  }

  void _syncFreeToPremiun() {
    if (_isSyncing) return;
    _isSyncing = true;
    if (_premiumScrollController.hasClients) {
      _premiumScrollController.jumpTo(_freeScrollController.offset);
    }
    _isSyncing = false;
  }

  void _syncPremiumToFree() {
    if (_isSyncing) return;
    _isSyncing = true;
    if (_freeScrollController.hasClients) {
      _freeScrollController.jumpTo(_premiumScrollController.offset);
    }
    _isSyncing = false;
  }

  @override
  void dispose() {
    _freeScrollController.removeListener(_syncFreeToPremiun);
    _premiumScrollController.removeListener(_syncPremiumToFree);
    _freeScrollController.dispose();
    _premiumScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IntroScreen4Controller controller = Get.put(IntroScreen4Controller());
    final mq = MediaQuery.of(context);
    final rowHeight = 72.h;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),

      body: Stack(
        children: [
          // Background Image
          // Positioned.fill(
          //   child: Image.asset(
          //     'assets/images/Background.png',
          //     fit: BoxFit.cover,
          //   ),
          // ),
          Image.asset('assets/images/topbarshade.png', fit: BoxFit.cover),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Close Button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 10.h,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: blackbox.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ),
                ),

                // Title
                Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final premium = context.l10n.premium;
                        final full =
                            context.l10n.unlockTheFullExperienceWith(premium);

                        final normalStyle =
                            sfProDisplay600(34.sp, Colors.white);
                        final premiumStyle = normalStyle.copyWith(
                          foreground: Paint()
                            ..shader = LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: const [
                                Color(0xFFF2B269),
                                Color(0xFFF17A7A),
                                Color(0xFFFFE6A7),
                              ],
                              stops: [0.2, 0.5, 0.8],
                              transform: GradientRotation(
                                135.5 * 3.1415927 / 180,
                              ),
                            ).createShader(
                              const Rect.fromLTWH(0, 0, 240, 60),
                            ),
                        );

                        final idx = full.indexOf(premium);
                        if (idx < 0) {
                          return Text(
                            full,
                            textAlign: TextAlign.center,
                            style: normalStyle,
                          );
                        }

                        return RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: full.substring(0, idx),
                                style: normalStyle,
                              ),
                              TextSpan(text: premium, style: premiumStyle),
                              TextSpan(
                                text: full.substring(idx + premium.length),
                                style: normalStyle,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                SizedBox(height: 20.h),

                // Main Content
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 70% - Features List with Sticky Header
                      Expanded(
                        flex: 8,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Stack(
                            children: [
                              // 1. The Scrollable Content
                              Positioned.fill(
                                child: SingleChildScrollView(
                                  controller: _freeScrollController,
                                  padding: EdgeInsets.only(
                                    top: 82.h,
                                    bottom: mq.viewPadding.bottom,
                                  ),
                                  child: Column(
                                    children:
                                        _features(context)
                                            .map(
                                              (item) => _buildFeatureRow(
                                                item.label,
                                                item.isFree,
                                                rowHeight,
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ),
                              ),
                              // 2. The Sticky Glass Header (Pinned on top)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: _buildGlassButton(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 30% - Premium Badge
                      Expanded(
                        flex: 2,
                        child: Container(
                          width: 40.w,
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color.fromRGBO(255, 230, 167, 1),
                                Color.fromRGBO(242, 178, 105, 1),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(40.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE8B87E).withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Scrollable Badge Content
                              Positioned.fill(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 65.h,
                                      child: Center(
                                        child: SizedBox(
                                          height: 31.h,
                                          width: 31.w,
                                          child: Image.asset(
                                            'assets/images/crown.png',
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        controller: _premiumScrollController,
                                        padding: EdgeInsets.only(
                                          top: 5.h,
                                          bottom: mq.viewPadding.bottom,
                                        ),
                                        child: Column(
                                          children:
                                              _features(context)
                                                  .map(
                                                    (item) => _buildBadgeRow(
                                                      item.badge,
                                                      rowHeight,
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 20.w),
                    ],
                  ),
                ),
                SizedBox(height: 30.h),

                // Start Trial Button
                Obx(
                  () => GestureDetector(
                    onTap:
                        controller.isLoading.value
                            ? null
                            : controller.startTrial,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 16.w),
                      width: double.infinity,
                      height: 56.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8B87E), Color(0xFFD4A574)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28.r),
                        border: Border.all(width: 0.7, color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFC107).withOpacity(0.35),
                            blurRadius: 16,
                            spreadRadius: 9,
                          ),
                        ],
                      ),
                      child: Center(
                        child:
                            controller.isLoading.value
                                ? SizedBox(
                                  width: 24.w,
                                  height: 24.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : Text(
                                  context.l10n.startMy14DayFreeTrial,
                                  style: sfProText600(17.sp, Colors.white),
                                ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 22.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(37),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 58.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(48, 48, 48, 0.5),
            borderRadius: BorderRadius.circular(37),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.features, style: sfProText600(17.sp, Colors.white)),
              Text(context.l10n.free, style: sfProText600(17.sp, Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String feature, bool isFree, double rowHeight) {
    return SizedBox(
      height: rowHeight,
      child: Column(
        children: [
          Expanded(
            child: Container(
              margin: EdgeInsets.only(left: 17.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      feature,
                      style: sfProText400(17.sp, Colors.white),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: AssetImage(
                              isFree
                                  ? 'assets/images/checkintro.png'
                                  : 'assets/images/closeicon.png',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            color: Colors.grey.withOpacity(0.3),
            thickness: 1,
            indent: 17.w,
            endIndent: 17.w,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeRow(BadgeIcon badge, double rowHeight) {
    return SizedBox(
      height: rowHeight,
      child: Center(
        child: Image.asset(
          badge.imagePath,
          width: (badge.width ?? 40).w,
          height: (badge.height ?? 40).h,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
