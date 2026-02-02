import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';

import '../../core/themes/textstyles.dart';
import 'intro_screen4.dart'; // Make sure this import points to your screen

// Step 1: Create a GetX Controller
class IntroScreen3Controller extends GetxController {
  var isLoading = false.obs;

  void startTrial() async {
    isLoading.value = true;

    // // Show loading for 2 seconds
    // await Future.delayed(const Duration(seconds: 1));

    isLoading.value = false;

    // Navigate to IntroScreen4 using GetX
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
    // Step 2: Initialize the controller
    final IntroScreen3Controller controller = Get.put(IntroScreen3Controller());

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  clipBehavior: Clip.none,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Bar with Close Button
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

                        //  SizedBox(height: 20.h),

                        // Logo Image
                        Image.asset(
                          'assets/images/glowintro.png',
                          width: 280.w,
                          height: 165.h,
                          fit: BoxFit.contain,
                        ),

                        SizedBox(height: 20.h),

                        // Title
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'How your ',
                                style: sfProDisplay600(34.sp, Colors.white),
                              ),
                              TextSpan(
                                text: 'Premium',
                                style:
                                sfProDisplay600(
                                  34.sp,
                                  Colors
                                      .white, // base color won't matter, overridden by foreground
                                ).copyWith(
                                  foreground: Paint()
                                    ..shader =
                                    LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(
                                          0xFFF2B269,
                                        ), // yellow-orange
                                        Color(
                                          0xFFF17A7A,
                                        ), // fully opaque red
                                        Color(
                                          0xFFFFE6A7,
                                        ), // light yellow
                                      ],
                                      stops: [
                                        0.2,
                                        0.5,
                                        0.8,
                                      ], // shift stops to give more space to red
                                      transform: GradientRotation(
                                        185.5 * 3.1415927 / 180,
                                      ),
                                    ).createShader(
                                      Rect.fromLTWH(0, 0, 200, 50),
                                    ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Text(
                          'free trial works',
                          style: sfProDisplay600(32.sp, Colors.white),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 20.h),

                        // Trial Image
                        SizedBox(
                          height: 420.h, // controls whole overlap area
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              /// TRIAL IMAGE (TOP)
                              Positioned(
                                top: 0,
                                child: Image.asset(
                                  'assets/images/trial.png',
                                  height: 283.h,
                                  fit: BoxFit.contain,
                                ),
                              ),

                              /// GLOW (CENTER – overlaps image + button)
                              Positioned(
                                top: 210.h, // tweak this for perfect overlap
                                child: Image.asset(
                                  'assets/images/freetrialGlow.png',
                                  width: 530.w,
                                  fit: BoxFit.contain,
                                ),
                              ),

                              /// BUTTON (BOTTOM)
                              Positioned(
                                bottom: 0,
                                left: 30.w,
                                right: 30.w,
                                child: Obx(
                                      () => GestureDetector(
                                    onTap: controller.isLoading.value
                                        ? null
                                        : controller.startTrial,
                                    child: Container(
                                      height: 52.h,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFE8B87E),
                                            Color(0xFFD4A574),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(28.r),
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
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                            AlwaysStoppedAnimation<Color>(Colors.white),
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

