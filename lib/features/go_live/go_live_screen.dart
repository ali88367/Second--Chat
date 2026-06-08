import 'dart:async';



import 'package:apivideo_live_stream/apivideo_live_stream.dart';

import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get/get.dart';



import '../../controllers/rtmp_broadcast_controller.dart';

import 'go_live_route_controller.dart';

import 'go_live_setup_bottom_sheet.dart';

import '../../core/constants/app_colors/app_colors.dart';

import '../../core/themes/textstyles.dart';

import '../../core/widgets/custom_back_button.dart';



/// Opens [GoLiveScreen] with route-scoped init/teardown (safe for GetX/Obx).

void openGoLiveScreen() {

  Get.to(

    () => const GoLiveScreen(),

    binding: BindingsBuilder(() {

      Get.put(GoLiveRouteController());

    }),

    transition: Transition.cupertino,

    duration: const Duration(milliseconds: 250),

    curve: Curves.fastOutSlowIn,

  );

}



class GoLiveScreen extends GetView<GoLiveRouteController> {

  const GoLiveScreen({super.key});



  RtmpBroadcastController get _broadcast => controller.broadcast;



  @override

  Widget build(BuildContext context) {

    return PopScope(

      canPop: true,

      child: Scaffold(

        backgroundColor: Colors.black,

        body: Stack(

          fit: StackFit.expand,

          children: [

            _GoLiveCameraPreview(controller: _broadcast),

            const _GoLiveTopGradient(),

            const _GoLiveBottomGradient(),

            SafeArea(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  _GoLiveTopBar(controller: _broadcast),

                  const Spacer(),

                  _GoLiveControls(controller: _broadcast),

                  SizedBox(height: 16.h),

                ],

              ),

            ),

          ],

        ),

      ),

    );

  }

}



class _GoLiveCameraPreview extends StatelessWidget {

  const _GoLiveCameraPreview({required this.controller});



  final RtmpBroadcastController controller;



  @override

  Widget build(BuildContext context) {

    return Obx(() {

      if (controller.isInitializing.value) {

        return const ColoredBox(

          color: Color(0xFF0A0A0A),

          child: Center(

            child: CircularProgressIndicator(

              color: Color(0xFFB950EF),

              strokeWidth: 2.5,

            ),

          ),

        );

      }



      if (!controller.isReady.value) {

        return ColoredBox(

          color: const Color(0xFF0A0A0A),

          child: Center(

            child: Padding(

              padding: EdgeInsets.symmetric(horizontal: 32.w),

              child: Text(

                controller.errorMessage.value ??

                    'Unable to prepare camera',

                textAlign: TextAlign.center,

                style: sfProText400(14.sp, Colors.white70),

              ),

            ),

          ),

        );

      }



      final live = controller.liveController;

      if (live == null || !controller.canShowCameraPreviewInGoLive) {

        return ColoredBox(

          color: const Color(0xFF0A0A0A),

          child: Center(

            child: Text(

              'Camera preview active elsewhere',

              style: sfProText400(13.sp, Colors.white38),

            ),

          ),

        );

      }



      return ApiVideoCameraPreview(

        controller: live,

        fit: BoxFit.cover,

      );

    });

  }

}



class _GoLiveTopGradient extends StatelessWidget {

  const _GoLiveTopGradient();



  @override

  Widget build(BuildContext context) {

    return Positioned(

      top: 0,

      left: 0,

      right: 0,

      height: 160.h,

      child: DecoratedBox(

        decoration: BoxDecoration(

          gradient: LinearGradient(

            begin: Alignment.topCenter,

            end: Alignment.bottomCenter,

            colors: [

              Colors.black.withValues(alpha: 0.72),

              Colors.transparent,

            ],

          ),

        ),

      ),

    );

  }

}



class _GoLiveBottomGradient extends StatelessWidget {

  const _GoLiveBottomGradient();



  @override

  Widget build(BuildContext context) {

    return Positioned(

      left: 0,

      right: 0,

      bottom: 0,

      height: 220.h,

      child: DecoratedBox(

        decoration: BoxDecoration(

          gradient: LinearGradient(

            begin: Alignment.bottomCenter,

            end: Alignment.topCenter,

            colors: [

              Colors.black.withValues(alpha: 0.82),

              Colors.transparent,

            ],

          ),

        ),

      ),

    );

  }

}



class _GoLiveTopBar extends StatelessWidget {

  const _GoLiveTopBar({required this.controller});



  final RtmpBroadcastController controller;



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: EdgeInsets.fromLTRB(8.w, 8.h, 16.w, 8.h),

      child: Row(

        children: [

          const CustomBackButton(),

          SizedBox(width: 12.w),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  'Go Live',

                  style: sfProDisplay600(22.sp, Colors.white),

                ),

                Text(
                  controller.broadcastingSubtitle,
                  style: sfProText400(
                    13.sp,
                    const Color.fromRGBO(235, 235, 245, 0.45),
                  ),
                ),

              ],

            ),

          ),

          Obx(() {

            if (!controller.isStreaming.value) {

              return const SizedBox.shrink();

            }

            return Container(

              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),

              decoration: BoxDecoration(

                color: const Color(0xFFE53935),

                borderRadius: BorderRadius.circular(6.r),

                boxShadow: [

                  BoxShadow(

                    color: const Color(0xFFE53935).withValues(alpha: 0.45),

                    blurRadius: 12,

                  ),

                ],

              ),

              child: Text(

                '● LIVE',

                style: sfProText700(12.sp, Colors.white),

              ),

            );

          }),

        ],

      ),

    );

  }

}



class _GoLiveControls extends StatelessWidget {

  const _GoLiveControls({required this.controller});



  final RtmpBroadcastController controller;



  Future<void> _onMainButtonTap(BuildContext context) async {

    if (!controller.isReady.value || controller.isConnecting.value) return;



    if (controller.isStreaming.value) {

      await controller.stopBroadcast();

      return;

    }



    await showGoLiveSetupBottomSheet(context, controller);

  }



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: EdgeInsets.symmetric(horizontal: 16.w),

      child: Column(

        children: [

          Obx(() {

            final err = controller.errorMessage.value;

            if (err == null || err.isEmpty) return const SizedBox.shrink();

            return Padding(

              padding: EdgeInsets.only(bottom: 12.h),

              child: Text(

                err,

                textAlign: TextAlign.center,

                style: sfProText400(13.sp, const Color(0xFFFF8A80)),

              ),

            );

          }),

          Obx(() {

            final ready = controller.isReady.value;

            final streaming = controller.isStreaming.value;

            final connecting = controller.isConnecting.value;

            final muted = controller.isMicMuted.value;

            return Row(

              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                _RoundToolButton(

                  icon: Icons.cameraswitch_rounded,

                  onTap: ready

                      ? () => unawaited(controller.switchCamera())

                      : null,

                ),

                SizedBox(width: 20.w),

                _GoLiveMainButton(

                  ready: ready,

                  streaming: streaming,

                  connecting: connecting,

                  onTap: () => unawaited(_onMainButtonTap(context)),

                ),

                SizedBox(width: 20.w),

                _RoundToolButton(

                  icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,

                  onTap: ready

                      ? () => unawaited(controller.toggleMicrophone())

                      : null,

                ),

              ],

            );

          }),

        ],

      ),

    );

  }

}



class _RoundToolButton extends StatelessWidget {

  const _RoundToolButton({required this.icon, this.onTap});



  final IconData icon;

  final VoidCallback? onTap;



  @override

  Widget build(BuildContext context) {

    return Material(

      color: Colors.black.withValues(alpha: 0.45),

      shape: const CircleBorder(),

      clipBehavior: Clip.antiAlias,

      child: InkWell(

        onTap: onTap,

        child: SizedBox(

          width: 52.w,

          height: 52.w,

          child: Icon(icon, color: Colors.white, size: 24.sp),

        ),

      ),

    );

  }

}



class _GoLiveMainButton extends StatelessWidget {

  const _GoLiveMainButton({

    required this.ready,

    required this.streaming,

    required this.connecting,

    required this.onTap,

  });



  final bool ready;

  final bool streaming;

  final bool connecting;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: ready && !connecting ? onTap : null,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 220),

        width: 148.w,

        height: 56.h,

        decoration: BoxDecoration(

          gradient: streaming

              ? const LinearGradient(

                  colors: [Color(0xFFE53935), Color(0xFFB71C1C)],

                )

              : goldGradient,

          borderRadius: BorderRadius.circular(30.r),

          boxShadow: [

            BoxShadow(

              color: (streaming ? const Color(0xFFE53935) : beige)

                  .withValues(alpha: 0.35),

              blurRadius: 20,

              offset: const Offset(0, 6),

            ),

          ],

        ),

        alignment: Alignment.center,

        child: connecting

            ? SizedBox(

                width: 22.w,

                height: 22.w,

                child: const CircularProgressIndicator(

                  strokeWidth: 2,

                  color: Colors.black,

                ),

              )

            : Text(

                streaming ? 'End Stream' : 'Go Live',

                style: sfProText700(

                  17.sp,

                  streaming ? Colors.white : Colors.black,

                ),

              ),

      ),

    );

  }

}


