import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/constants/app_images/app_images.dart';
import 'intro_screen2.dart';

class IntroScreen1 extends StatelessWidget {
  const IntroScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/intro1.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Stack(
            children: [
              // Base background
              Container(
                //   color: Colors.black,
              ),

              // Yellow smog / glow (top-right)
              Positioned(
                top: -200.h,
                left: -110.w,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.6,
                      colors: [
                        const Color.fromRGBO(246, 246, 146, 0.5), // soft yellow
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // UI content
          Positioned(
            bottom: 90.h,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 95.h,
              width: 165.w,
              child: Image.asset(logo),
            ),
          ),

          Positioned(
            bottom: 20.h,
            left: 16.w,
            right: 16.w,
            child: GestureDetector(
              onTap: () {
                Get.to(IntroScreen2());
              },
              child: Container(
                height: 52.h,
                //  padding: const EdgeInsets.symmetric(horizontal: 25),
                decoration: BoxDecoration(
                  color: Colors.white, // button color
                  borderRadius: BorderRadius.circular(36),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Get Started',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
