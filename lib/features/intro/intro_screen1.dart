import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_images/app_images.dart';
import 'intro_screen2.dart';

class IntroScreen1 extends StatefulWidget {
  const IntroScreen1({super.key, this.initialController});

  final VideoPlayerController? initialController;

  @override
  State<IntroScreen1> createState() => _IntroScreen1State();
}

class _IntroScreen1State extends State<IntroScreen1> {
  VideoPlayerController? _controller;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.initialController;
    if (_controller == null) {
      _initializeVideo();
    } else {
      _controller!
        ..setLooping(true)
        ..setVolume(0)
        ..play();
    }
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.asset('assets/intro.mp4');

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller
        ..setLooping(true)
        ..setVolume(0)
        ..play();

      setState(() {
        _controller = controller;
        _videoFailed = false;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;

      setState(() {
        _videoFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [

            Positioned.fill(
              child: _controller?.value.isInitialized == true
                  ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
                  : _videoFailed
                          ? Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              child: const Text(
                                'Video failed to load',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : Container(color: Colors.black),
            ),

            /// Yellow Glow Overlay
            Positioned(
              top: -200.h,
              left: -110.w,
              child: Container(
                width: 400,
                height: 400,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.6,
                    colors: [
                      Color.fromRGBO(246, 246, 146, 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            /// Logo
            Positioned(
              bottom: 120.h,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 95.h,
                width: 165.w,
                child: Image.asset(logo),
              ),
            ),

            /// Get Started Button
            Positioned(
              bottom: 40.h,
              left: 24.w,
              right: 24.w,
              child: GestureDetector(
                onTap: () {
                  Get.to(
                        () => const IntroScreen2(),
                    transition: Transition.cupertino,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                  );
                },
                child: Container(
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36.r),
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
