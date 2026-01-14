import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/features/intro/intro_screen5.dart';
import 'package:second_chat/features/main_section/main/HomeScreen2.dart';

import '../../core/themes/textstyles.dart';

// Step 1: Create a GetX Controller
class IntroScreen4Controller extends GetxController {
  var isLoading = false.obs;

  void startTrial() async {
    isLoading.value = true;
    //
    // // Show loading for 2 seconds
    // await Future.delayed(const Duration(milliseconds: 100));

    isLoading.value = false;

    // Navigate to IntroScreen4 using GetX
    Get.to(() => const IntroScreen5());
  }
}

class IntroScreen4 extends StatefulWidget {
  const IntroScreen4({Key? key}) : super(key: key);

  @override
  State<IntroScreen4> createState() => _IntroScreen4State();
}

class _IntroScreen4State extends State<IntroScreen4> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IntroScreen4Controller controller = Get.put(IntroScreen4Controller());

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/Background.png',
              fit: BoxFit.cover,
            ),
          ),
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
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Unlock the full experience with  ',
                            style: sfProDisplay600(34.sp, Colors.white),
                          ),
                          TextSpan(
                            text: 'Premium',
                            style: sfProDisplay600(34.sp, Colors.white).copyWith(
                              foreground: Paint()
                                ..shader = LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF2B269),
                                    Color(0xFFF17A7A),
                                    Color(0xFFFFE6A7),
                                  ],
                                  stops: [0.2, 0.5, 0.8],
                                  transform: GradientRotation(
                                    135.5 * 3.1415927 / 180,
                                  ),
                                ).createShader(Rect.fromLTWH(0, 0, 200, 50)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 30.h),

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
                                  controller: _scrollController,
                                  // Padding at top so first item isn't hidden by header
                                  padding: EdgeInsets.only(top: 82.h),
                                  child: Column(
                                    children: [
                                      _buildFeatureRow('Multi-Platform Chat', true, false),
                                      _buildFeatureRow('Multi-Stream Monitor', false, true),
                                      _buildFeatureRow('Activity Feed', true, false),
                                      _buildFeatureRow('Title/Category Manage', false, true),
                                      _buildFeatureRow('Edge LED Notification', false, true),
                                      _buildFeatureRow('Custom Notification', false, true),
                                      _buildFeatureRow('Analytics', false, true),
                                      _buildFeatureRow('Animated Elements', false, true),
                                      _buildFeatureRow('Stream Streak', true, false),
                                    ],
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
                        child: AnimatedBuilder(
                          animation: _scrollController,
                          builder: (context, child) {
                            return _buildPremiumBadge();
                          },
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
                    onTap: controller.isLoading.value ? null : controller.startTrial,
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
                        border: Border.all(width: 0.7,color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFC107).withOpacity(0.35),
                            blurRadius: 16,
                            spreadRadius: 9,
                          ),
                        ],
                      ),
                      child: Center(
                        child: controller.isLoading.value
                            ? SizedBox(
                          width: 24.w,
                          height: 24.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          'Start My 14 Day Free Trial',
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
              Text("Feature's", style: sfProText600(17.sp, Colors.white)),
              Text('Free', style: sfProText600(17.sp, Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String feature, bool isFree, bool showInfo) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(left: 17.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Text(feature, style: sfProText400(17.sp, Colors.white)),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      color: isFree
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFree ? Icons.check : Icons.close,
                      color: isFree ? Colors.white : Colors.white.withOpacity(0.5),
                      size: 16.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        Divider(
          color: Colors.grey.withOpacity(0.3),
          thickness: 1,
          indent: 17.w,
          endIndent: 17.w,
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildPremiumBadge() {
    return Container(
      width: 40.w,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromRGBO(255, 230, 167, 1),
            Color.fromRGBO(242, 178, 105, 1),
                 ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8B87E).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32.h,
              width: 32.w,
              child: Image.asset('assets/images/crown.png'),
            ),
            SizedBox(height: 20.h),
            _buildBadgeIcon(imagePath: 'assets/images/checkPlus.png', isInfo: false),
            SizedBox(height: 48.h),
            _buildBadgeIcon(imagePath: 'assets/images/checkInfo.png', isInfo: true),
            SizedBox(height: 48.h),
            _buildBadgeIcon(imagePath: 'assets/images/checkPlus.png', isInfo: false),
            SizedBox(height: 48.h),
            _buildBadgeIcon(imagePath: 'assets/images/checkInfo.png', isInfo: true),
            SizedBox(height: 48.h),
            _buildBadgeIcon(imagePath: 'assets/images/checkInfo.png', isInfo: true),
            SizedBox(height: 48.h),
            _buildBadgeIcon(imagePath: 'assets/images/checkInfo.png', isInfo: true),
            SizedBox(height: 48.h),
            _buildBadgeIcon(imagePath: 'assets/images/checkInfo.png', isInfo: true),
            SizedBox(height: 48.h),
            _buildBadgeIcon(imagePath: 'assets/images/checkInfo.png', isInfo: true),
            SizedBox(height: 48.h),
            _buildBadgeIcon(imagePath: 'assets/images/checkInfo.png', isInfo: true),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon({required String imagePath, required bool isInfo}) {
    return Container(
      child: Center(
        child: Image.asset(
          imagePath,
          width: 40.w,
          height: 40.w,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}