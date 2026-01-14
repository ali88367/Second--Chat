import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import '../../core/themes/textstyles.dart';
import 'intro_screen3.dart';

class IntroScreen2 extends StatelessWidget {
  const IntroScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
// Top Bar
          Positioned(
            top: 40.h,
            right: 2,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(48, 48, 48, 0.5),

    borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: NetworkImage(
                                'https://flagcdn.com/w40/us.png',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Eng',
                          style: sfProText400(17.sp, Colors.white)
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: grey,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Spacer(flex: 2),
          /// Glow Effect (20% smaller)
          Positioned(
            top: 100.h,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 320.w * 0.8, // 256.w
                height: 320.w * 0.8, // 256.w
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: goldeffect.withOpacity(0.4),
                      blurRadius: 180 * 0.8, // 144
                      spreadRadius: 60 * 0.8, // 48
                    ),
                  ],
                ),
              ),
            ),
          ),


          /// Bunny
          Positioned(
            top: 60.h,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/bunny.png',
              height: 300.h,
            ),
          ),

          /// Titles
          Positioned(
            top: 380.h,
            left: 0.w,
            right: 0.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'All-In-One',
                  style:sfProDisplay600(34.sp, Colors.white)
                ),
                ShimmerText(
                  text: 'Multichat',
                  style: sfProDisplay600(34.sp, Colors.white),
                  gradientColors: [
                    Color(0xFFFFD966),
                    Color(0xFFFF7A18),
                  ],
                ),
              ],
            ),
          ),

          /// Compact Glass Card
          Positioned(
            bottom: 32.h,
            left: 16.w,
            right: 16.w,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 24.h,
                  ),
                  decoration: BoxDecoration(
                    color: blackbox,
                    borderRadius: BorderRadius.circular(22.r),

                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: (){
                          Get.to(IntroScreen3());
                        },
                        child: Text(
                          'Enjoy Better Streaming',
                          style: sfProDisplay600(22.sp, Colors.white)
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                          'And enjoy a smoother experience',
                          style: sfProText400(15.sp, grey)
                      ),
                      SizedBox(height: 18.h),

                      PlatformButton(
                        label: 'Twitch',
                        gradient: const LinearGradient(
                          colors: [
                            Color.fromRGBO(185, 80, 239, 0.5),
                            Color.fromRGBO(64, 17, 98, 0.5),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        imagePath: 'assets/images/twitch.png',
                      ),
                      SizedBox(height: 12.h),

                      PlatformButton(
                        label: 'Kick',
                        color: const Color(0xFF42A720), // solid green
                        imagePath: 'assets/images/kick.png',                      ),
                      SizedBox(height: 12.h),

                      PlatformButton(
                        label: 'YouTube',
                        color: const Color(0xFFDD2C28), // solid red
                        imagePath: 'assets/images/youtube.png',                      ),

                    ],
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



class PlatformButton extends StatelessWidget {
  final String label;
  final String? imagePath; // path to your image asset
  final Color? color;
  final LinearGradient? gradient;

  const PlatformButton({
    required this.label,
    this.imagePath,
    this.color,
    this.gradient,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final _controller = Get.put(_PlatformButtonController());

    return MouseRegion(
      onEnter: (_) => _controller.onEnter(),
      onExit: (_) => _controller.onExit(),
      child: Obx(
            () => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 50.h,
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? color : null,
            borderRadius: BorderRadius.circular(30),
            boxShadow: _controller.isHover.value
                ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ]
                : [],
          ),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(36.r),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (imagePath != null)
                  Image.asset(
                    imagePath!,
                    height: 24.h,
                    width: 24.w,
                  ),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: sfProText600(17.sp, Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformButtonController extends GetxController {
  var isHover = false.obs;

  void onEnter() => isHover.value = true;
  void onExit() => isHover.value = false;
}



class ButtonController extends GetxController {
  final RxBool isLoading = false.obs;

  Future<void> handlePress() async {
    if (isLoading.value) return;
    isLoading.value = true;
    await Future.delayed(const Duration(seconds: 2));
    isLoading.value = false;
  }
}


class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<Color> gradientColors;
  final double glowBlur; // optional glow intensity

  const ShimmerText({
    super.key,
    required this.text,
    required this.style,
    required this.gradientColors,
    this.glowBlur = 12.0,
  });

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
          },
          child: Text(
            widget.text,
            style: widget.style.copyWith(
              color: Colors.white, // needed for ShaderMask
              shadows: [
                Shadow(
                  blurRadius: widget.glowBlur,
                  color: Colors.white.withOpacity(_glowAnimation.value),
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
