import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';



class EdgeGlowNotificationPage extends StatefulWidget {
  const EdgeGlowNotificationPage({super.key});

  @override
  State<EdgeGlowNotificationPage> createState() =>
      _EdgeGlowNotificationPageState();
}

class _EdgeGlowNotificationPageState extends State<EdgeGlowNotificationPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  bool showGlow = false;
  bool showNotification = false;

  StreamPlatform currentPlatform = StreamPlatform.twitch;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _platformGlowColors() {
    switch (currentPlatform) {
      case StreamPlatform.twitch:
  return const [
    Color(0xFF8F3DDB), // Deep violet (darker than base, good for depth)
    Color(0xFFC45BFF), // Lighter purple highlight (close to base)
   
  ];

      case StreamPlatform.kick:
       return const [
  Color(0xFF00FF87), // Soft neon green
  Color(0xFF2BFF00), // Electric green
  Color(0xFF00E6A8), // Teal-green glow
  Color(0xFF7CFF3A), // Apple-style lime
  Color(0xFF00FF5A), // Bright pulse green
];

      case StreamPlatform.youtube:
        return const [
          Color(0xFFFF1744),
          Color(0xFFFF5252),
        
        ];
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

  Future<void> triggerNotification(StreamPlatform platform) async {
    setState(() {
      currentPlatform = platform;
      showGlow = true;
      showNotification = true;
    });

    _controller.repeat();

    await Future.delayed(const Duration(seconds: 4));

    _controller.stop();
    _controller.reset();

    if (!mounted) return;

    setState(() {
      showGlow = false;
      showNotification = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _demoButton("Twitch", StreamPlatform.twitch),
                  _demoButton("Kick", StreamPlatform.kick),
                  _demoButton("YouTube", StreamPlatform.youtube),
                ],
              ),
            ),

            if (showNotification)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h),
                child: _notificationCard(),
              ),

            if (showGlow)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      return CustomPaint(
                        painter: SiriEdgeGlowPainter(
                          progress: _controller.value,
                          colors: _platformGlowColors(),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
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
            platformColor.withOpacity(0.35),
            const Color(0xFF121212),
          ],
        ),
        border: Border.all(
          color: platformColor.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: platformColor.withOpacity(0.2),
            child: const Icon(Icons.notifications, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "SuperFan sent you a message",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

enum StreamPlatform { twitch, kick, youtube }

/// ================= SIRI STYLE EDGE GLOW =================

class SiriEdgeGlowPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  SiriEdgeGlowPainter({
    required this.progress,
    required this.colors,
  });

  @override
void paint(Canvas canvas, Size size) {
  // Fixed margin — NO expansion
  const margin = 10.0;

  final rect = Rect.fromLTWH(
    margin,
    margin,
    size.width - margin * 2,
    size.height - margin * 2,
  );

  final path = Path()
    ..addRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(26)),
    );

  // Siri-style organic breathing
  final breathing =
      0.75 + (0.25 * sin(progress * pi * 2).abs());

  // Continuous flowing colors
  final gradient = SweepGradient(
    colors: colors,
    stops: List.generate(
      colors.length,
      (i) => i / (colors.length - 1),
    ),
    transform: GradientRotation(progress * pi * 2),
  );

 // OUTER DIFFUSED GLOW (reduce spread)
final outerPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 20 * breathing       // smaller than before (was 30)
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25)  // smaller blur (was 45)
  ..shader = gradient.createShader(rect)
  ..color = Colors.white.withOpacity(0.45);

// INNER CORE (slightly tighter)
final innerPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 10 * breathing       // smaller than before (was 12)
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)  // tighter blur
  ..shader = gradient.createShader(rect)
  ..color = Colors.white.withOpacity(0.85);

// SHARP INNER EDGE (definition stays almost the same)
final sharpPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2
  ..shader = gradient.createShader(rect)
  ..color = Colors.white.withOpacity(0.35);


  canvas.drawPath(path, outerPaint);
  canvas.drawPath(path, innerPaint);
  canvas.drawPath(path, sharpPaint);
}


  @override
  bool shouldRepaint(covariant SiriEdgeGlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}