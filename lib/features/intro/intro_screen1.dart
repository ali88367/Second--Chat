import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/constants/app_images/app_images.dart';
import 'intro_screen2.dart';

class IntroScreen1 extends StatefulWidget {
  const IntroScreen1({super.key});

  @override
  State<IntroScreen1> createState() => _IntroScreen1State();
}

class _IntroScreen1State extends State<IntroScreen1> {
  @override
  void initState() {
    super.initState();
    // Preload Screen 3 images in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadScreen3Images(context);
    });
  }

  void _preloadScreen3Images(BuildContext context) {
    // Preload all images used in Screen 3
    precacheImage(const AssetImage('assets/images/Background.png'), context);
    precacheImage(const AssetImage('assets/images/topbarshade.png'), context);
    precacheImage(const AssetImage('assets/images/glowintro.png'), context);
    precacheImage(const AssetImage('assets/images/trial.png'), context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
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
                  Get.to(
                    () => IntroScreen2(),
                    transition: Transition.cupertino,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                  );
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
                      fontFamily: 'SFProText',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
