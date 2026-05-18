import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:second_chat/core/localization/l10n.dart';
import 'package:second_chat/core/widgets/edge_glow_painter.dart';

/// Demo page for edge LED glow (same painter + timing as live app on iOS/Android).
class EdgeGlowNotificationPage extends StatefulWidget {
  const EdgeGlowNotificationPage({super.key});

  @override
  State<EdgeGlowNotificationPage> createState() =>
      _EdgeGlowNotificationPageState();
}

class _EdgeGlowNotificationPageState extends State<EdgeGlowNotificationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool showGlow = false;
  bool showNotification = false;

  StreamPlatform currentPlatform = StreamPlatform.twitch;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: EdgeGlowPainter.rotationDuration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _platformKey {
    switch (currentPlatform) {
      case StreamPlatform.twitch:
        return 'twitch';
      case StreamPlatform.kick:
        return 'kick';
      case StreamPlatform.youtube:
        return 'youtube';
    }
  }

  Color _platformMainColor() {
    switch (currentPlatform) {
      case StreamPlatform.twitch:
        return const Color(0xFF9146FF);
      case StreamPlatform.kick:
        return const Color(0xFF00E701);
      case StreamPlatform.youtube:
        return const Color(0xFFFF0000);
    }
  }

  void _startGlowAnimation() {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!mounted) return;
      _controller
        ..stop()
        ..reset()
        ..repeat();
    });
  }

  Future<void> triggerNotification(StreamPlatform platform) async {
    setState(() {
      currentPlatform = platform;
      showGlow = true;
      showNotification = true;
    });

    _startGlowAnimation();

    await Future.delayed(const Duration(seconds: 4));

    if (!mounted) return;

    _controller.stop();
    setState(() {
      showGlow = false;
      showNotification = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = EdgeGlowPainter.platformColors(_platformKey);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _demoButton('Twitch', StreamPlatform.twitch),
                      _demoButton('Kick', StreamPlatform.kick),
                      _demoButton('YouTube', StreamPlatform.youtube),
                    ],
                  ),
                ),
                if (showNotification)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 32.w,
                      vertical: 40.h,
                    ),
                    child: _notificationCard(),
                  ),
              ],
            ),
          ),
          if (showGlow)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: ClipRect(
                    clipBehavior: Clip.none,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedBuilder(
                          animation: _controller,
                          builder: (_, __) {
                            return CustomPaint(
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                              painter: EdgeGlowPainter(
                                progress: _controller.value,
                                colors: colors,
                                animate: true,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _demoButton(String text, StreamPlatform platform) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ElevatedButton(
        onPressed: () => triggerNotification(platform),
        child: Text(text),
      ),
    );
  }

  Widget _notificationCard() {
    final platformColor = _platformMainColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            platformColor.withValues(alpha: 0.35),
            const Color(0xFF121212),
          ],
        ),
        border: Border.all(
          color: platformColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: platformColor.withValues(alpha: 0.2),
            child: const Icon(Icons.notifications, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.superFanSentYouAMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

enum StreamPlatform { twitch, kick, youtube }
