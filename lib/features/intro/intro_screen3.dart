import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';

import '../../core/themes/textstyles.dart';
import 'intro_screen4.dart';

// Controller
class IntroScreen3Controller extends GetxController {
  var isLoading = false.obs;

  void startTrial() async {
    isLoading.value = true;
    isLoading.value = false;

    Get.to(
          () => const IntroScreen4(),
      transition: Transition.cupertino,
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
    );
  }
}

class IntroScreen3 extends StatelessWidget {
  const IntroScreen3({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final IntroScreen3Controller controller =
    Get.put(IntroScreen3Controller());

    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),

      body: Stack(
        children: [
          // Background
          // Positioned.fill(
          //   child: Image.asset(
          //     'assets/images/Background.png',
          //     fit: BoxFit.cover,
          //   ),
          // ),
          Image.asset('assets/images/topbarshade.png', fit: BoxFit.cover),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.only(
                    // 🔑 KEY FIX FOR SCROLL SCREENS
                    bottom: mq.systemGestureInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Close Button
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 10.h,
                          ),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  color: blackbox.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 24.sp,
                                ),
                              ),
                            ),
                          ),
                        ),

                        Image.asset(
                          'assets/images/glowintro.png',
                          width: 280.w,
                          height: 165.h,
                          fit: BoxFit.contain,
                        ),

                        SizedBox(height: 20.h),

                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'How your ',
                                style:
                                sfProDisplay600(34.sp, Colors.white),
                              ),
                              TextSpan(
                                text: 'Premium',
                                style: sfProDisplay600(
                                  34.sp,
                                  Colors.white,
                                ).copyWith(
                                  foreground: Paint()
                                    ..shader = LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: const [
                                        Color(0xFFF2B269),
                                        Color(0xFFF17A7A),
                                        Color(0xFFFFE6A7),
                                      ],
                                      stops: const [0.2, 0.5, 0.8],
                                      transform: GradientRotation(
                                        185.5 * 3.1415927 / 180,
                                      ),
                                    ).createShader(
                                      const Rect.fromLTWH(0, 0, 200, 50),
                                    ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Text(
                          'free trial works',
                          style:
                          sfProDisplay600(32.sp, Colors.white),
                        ),

                        SizedBox(height: 20.h),

                        SizedBox(
                          height: 420.h,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: 0,
                                child: Image.asset(
                                  'assets/images/trial.png',
                                  height: 283.h,
                                ),
                              ),

                              Positioned(
                                top: 210.h,
                                child: Image.asset(
                                  'assets/images/freetrialGlow.png',
                                  width: 530.w,
                                ),
                              ),

                              /// 🔑 BUTTON FIXED HERE
                              Positioned(
                                left: 30.w,
                                right: 30.w,
                                bottom: 0,
                                child: AnimatedPadding(
                                  duration:
                                  const Duration(milliseconds: 120),
                                  curve: Curves.easeOut,
                                  padding: EdgeInsets.only(
                                    bottom:
                                    mq.systemGestureInsets.bottom,
                                  ),
                                  child: Obx(
                                        () => GestureDetector(
                                      onTap: controller.isLoading.value
                                          ? null
                                          : controller.startTrial,
                                      child: Container(
                                        height: 52.h,
                                        decoration: BoxDecoration(
                                          gradient:
                                          const LinearGradient(
                                            colors: [
                                              Color(0xFFE8B87E),
                                              Color(0xFFD4A574),
                                            ],
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(
                                              28.r),
                                          border: Border.all(
                                            width: 0.7,
                                            color: Colors.white,
                                          ),
                                        ),
                                        child: Center(
                                          child: controller.isLoading.value
                                              ? SizedBox(
                                            width: 24.w,
                                            height: 24.w,
                                            child:
                                            const CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                              AlwaysStoppedAnimation<
                                                  Color>(
                                                  Colors.white),
                                            ),
                                          )
                                              : Text(
                                            'Start My 14 Day Free Trial',
                                            style: sfProText600(
                                                17.sp,
                                                Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
