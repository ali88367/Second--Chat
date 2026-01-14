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
    Get.to(() => const IntroScreen4());
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
            child: Column(
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

                SizedBox(height: 10.h),

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
                                ..shader = LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF2B269), // yellow-orange
                                    Color(0xFFF17A7A), // fully opaque red
                                    Color(0xFFFFE6A7), // light yellow
                                  ],
                                  stops: [
                                    0.2,
                                    0.5,
                                    0.8,
                                  ], // shift stops to give more space to red
                                  transform: GradientRotation(
                                    185.5 * 3.1415927 / 180,
                                  ),
                                ).createShader(Rect.fromLTWH(0, 0, 200, 50)),
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
                  height: 283.h,
                  child: Image.asset('assets/images/trial.png'),
                ),
Spacer(),
                // Bottom Button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 30.w,
                    vertical: 20.h,
                  ),
                  child: SizedBox(
                    height: 90.h, // controls glow space (SAFE)
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        /// BACKGROUND GLOW
                        _GlowOval(
                          width: 1.sw - 60.w, // match button width
                          height: 60.h,
                          blur: 30,
                          colors: [
                            const Color(0xFFFFF59D).withOpacity(0.6),
                            const Color(0xFFFFC107).withOpacity(0.35),
                            Colors.transparent,
                          ],
                        ),

                        /// BUTTON
                        Obx(
                          () => GestureDetector(
                            onTap: controller.isLoading.value
                                ? null
                                : controller.startTrial,
                            child: Container(
                              width: double.infinity,
                              height: 56.h,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE8B87E),
                                    Color(0xFFD4A574),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28.r),
                                border: Border.all(width: 0.7,color: Colors.white),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFC107,
                                    ).withOpacity(0.35),
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
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        'Start My 14 Day Free Trial',
                                        style: sfProText600(
                                          17.sp,
                                          Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 10.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOval extends StatelessWidget {
  final double width;
  final double height;
  final List<Color> colors;
  final double blur;

  const _GlowOval({
    required this.width,
    required this.height,
    required this.colors,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          gradient: RadialGradient(radius: 0.8, colors: colors),
        ),
      ),
    );
  }
}
