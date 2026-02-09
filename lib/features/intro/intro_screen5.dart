import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/features/main_section/main/HomeScreen2.dart';

import '../../core/constants/app_colors/app_colors.dart';
import '../../core/themes/textstyles.dart';

class IntroScreen5 extends StatelessWidget {
  const IntroScreen5({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final IntroScreen5Controller controller = Get.put(IntroScreen5Controller());

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
          // Bottom rotated shade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Transform.rotate(
              angle: 3.14159, // 180 degrees
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Color(0x80F6F692), // F6F692 with 50% opacity
                  BlendMode.srcATop,
                ),
                child: Image.asset(
                  'assets/images/topbarshade.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Close Button
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

                SizedBox(height: 1.h),

                // Title
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.w),
                  child: Image.asset('assets/images/trialInfo.png'),
                ),

                SizedBox(height: 10.h),

                // -----------------------------------------------------
                // 1. SMOOTH SLIDING SECTION (Images)
                // -----------------------------------------------------
                Expanded(
                  child: PageView(
                    controller: controller.pageController,
                    scrollDirection: Axis.horizontal, // Enables vertical slide
                    physics:
                        const BouncingScrollPhysics(), // Native smooth feel
                    onPageChanged: controller.onPageChanged,
                    children: [
                      // Page 0 Image
                      Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.only(bottom: 20.h),
                        child: OverflowBox(
                          maxHeight: 330.h,
                          maxWidth: 420.w,
                          child: Image.asset(
                            'assets/images/secondGlow.png',
                            width: 420.w,
                            height: 360.h,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                SizedBox(width: 280.w, height: 200.h),
                          ),
                        ),
                      ),
                      // Page 1 Image
                      Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.only(bottom: 20.h),
                        child: Image.asset(
                          'assets/images/bunnyGlow.png',
                          width: 280.w,
                          height: 280.h,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 280.w,
                            height: 280.h,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Icon(
                              Icons.pets,
                              size: 100.sp,
                              color: Colors.orange.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // -----------------------------------------------------
                // 2. BOTTOM CARD (Static position, animates content)
                // -----------------------------------------------------
                GestureDetector(
                  onHorizontalDragStart: controller.onHorizontalDragStart,
                  onHorizontalDragUpdate: controller.onHorizontalDragUpdate,
                  onHorizontalDragEnd: controller.onHorizontalDragEnd,

                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 20.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(30, 29, 32, 1),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Page Indicators
                        Obx(
                          () => Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildDot(controller.currentPage.value == 0),
                              SizedBox(width: 8.w),
                              _buildDot(controller.currentPage.value == 1),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.h),

                        // Animated Content (Subscription vs Referral)
                        Obx(
                          () => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.1),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: controller.currentPage.value == 0
                                ? _buildSubscriptionContent(controller)
                                : _buildReferralContent(controller),
                          ),
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => print('Terms of Service tapped'),
                              child: Text(
                                'Terms of Service',
                                style: sfProText400(
                                  12.sp,
                                  const Color.fromRGBO(235, 235, 245, 0.6),
                                ),
                              ),
                            ),
                            SizedBox(width: 20.w),
                            GestureDetector(
                              onTap: () => print('Restore Purchase tapped'),
                              child: Text(
                                'Restore Purchase',
                                style: sfProText400(
                                  12.sp,
                                  const Color.fromRGBO(235, 235, 245, 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32.w,
      height: 6.h,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }

  Widget _buildSubscriptionContent(IntroScreen5Controller c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey('subscription'),
      children: [
        // Monthly Plan
        GestureDetector(
          onTap: () => c.selectPlan(0),
          child: Obx(
            () => _planCard(
              isSelected: c.selectedPlan.value == 0,
              title: 'Monthly',
              price: '£4.99/month',
            ),
          ),
        ),

        SizedBox(height: 13.h),

        // Yearly Plan
        GestureDetector(
          onTap: () => c.selectPlan(1),
          child: Obx(
            () => Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.only(
                    left: 16.w,
                    top: 35.h,
                    right: 16.w,
                    bottom: 20.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(47, 46, 51, 1),
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 21.h,
                        width: 21.w,
                        child: Image.asset(
                          c.selectedPlan.value == 1
                              ? 'assets/images/tick.png'
                              : 'assets/icons/loader_icon.png',
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text('Year', style: sfProText600(17.sp, Colors.white)),
                      const Spacer(),
                      Text(
                        '£2.99/month',
                        style: sfProText600(17.sp, Colors.white),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -2.h,
                  child: SizedBox(
                    height: 29.h,
                    width: 110.w,
                    child: Image.asset('assets/images/mostPopular.png'),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 14.h),

        // Start Trial Button
        Obx(
          () => GestureDetector(
            onTap: c.isLoading.value ? null : c.startTrial,
            child: Container(
              width: double.infinity,
              height: 52.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8B87E), Color(0xFFD4A574)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(36.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: c.isLoading.value
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
                    : RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Start Free Trial\n',
                              style: sfProText600(17.sp, Colors.white),
                            ),
                            TextSpan(
                              text: c.selectedPlan.value == 1
                                  ? 'Then £2.99/year'
                                  : 'Then £4.99/month',
                              style: sfProText400(
                                12.sp,
                                const Color.fromRGBO(0, 0, 0, 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
        SizedBox(height: 13.h),
      ],
    );
  }

  Widget _planCard({
    required bool isSelected,
    required String title,
    required String price,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(47, 46, 51, 1),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 21.h,
            width: 21.w,
            child: Image.asset(
              isSelected
                  ? 'assets/images/tick.png'
                  : 'assets/icons/loader_icon.png',
            ),
          ),
          SizedBox(width: 12.w),
          Text(title, style: sfProText600(17.sp, Colors.white)),
          const Spacer(),
          Text(price, style: sfProText600(17.sp, Colors.white)),
        ],
      ),
    );
  }

  Widget _buildReferralContent(IntroScreen5Controller c) {
    return Padding(
      key: const ValueKey('referral'),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Invite a friend and receive',
            style: sfProText600(17.sp, Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Container(height: 1.h, color: const Color(0xFF2C2C2E)),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                height: 20.h,
                child: Image.asset('assets/images/clap.png'),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Get ', style: sfProText500(18.sp, Colors.white)),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFE8B87E), Color(0xFFE89B7E)],
                        ).createShader(bounds),
                        child: Text(
                          '1 month Free',
                          style: sfProText600(18.sp, Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '1 time',
                style: sfProText600(
                  17.sp,
                  const Color.fromRGBO(235, 235, 245, 0.3),
                ),
              ),
            ],
          ),
          SizedBox(height: 30.h),
          GestureDetector(
            onTap: c.copyLink,
            child: Container(
              width: double.infinity,
              height: 52.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8B87E), Color(0xFFD4A574)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(36.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 16.h,
                    width: 16.w,
                    child: Image.asset('assets/images/copyIcon.png'),
                  ),
                  SizedBox(width: 8.w),
                  Text('Copy link', style: sfProText600(17.sp, Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IntroScreen5Controller extends GetxController {
  var isLoading = false.obs;
  var selectedPlan = 1.obs; // 0 = Monthly, 1 = Yearly
  var currentPage = 0.obs;

  final PageController pageController = PageController(initialPage: 0);
  // Track Horizontal Drag Distance
  double _dragDistance = 0.0;

  void onHorizontalDragStart(DragStartDetails details) {
    _dragDistance = 0.0; // Reset distance
  }

  void onHorizontalDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dx; // Track horizontal movement
  }

  void onHorizontalDragEnd(DragEndDetails details) {
    double velocity = details.primaryVelocity ?? 0;
    double distance = _dragDistance;

    // Thresholds
    double velocityThreshold = 300.0; // Fast swipe speed
    double distanceThreshold = 50.0; // Slow drag distance

    // LOGIC:
    // 1. Swipe LEFT (Negative values) -> Next Page (Page 1)
    if (velocity < -velocityThreshold || distance < -distanceThreshold) {
      switchPage(1);
    }
    // 2. Swipe RIGHT (Positive values) -> Previous Page (Page 0)
    else if (velocity > velocityThreshold || distance > distanceThreshold) {
      switchPage(0);
    }
  }

  void switchPage(int index) {
    if (currentPage.value != index) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void startTrial() async {
    if (isLoading.value) return;
    isLoading(true);
    await Future.delayed(const Duration(milliseconds: 100));
    isLoading(false);

    Get.offAll(
      () => const HomeScreen2(),
      transition: Transition.cupertino,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    );
  }

  void copyLink() {
    Get.snackbar(
      'Success',
      'Link copied to clipboard!',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(20),
      backgroundColor: Colors.black.withOpacity(0.7),
      colorText: Colors.white,
    );
  }

  void selectPlan(int plan) {
    selectedPlan.value = plan;
  }

  void onPageChanged(int index) {
    currentPage.value = index;
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
