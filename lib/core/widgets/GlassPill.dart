import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';

class GlassPill extends StatelessWidget {
  final double width;
  final double height;
  final Widget? child;

  const GlassPill({
    super.key,
    required this.width,
    required this.height,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: width,
      height: height,
      borderRadius: 50,
      blur: 20,
      alignment: Alignment.center,
      border: 2,

      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF000000).withOpacity(0.8),
          const Color(0xFF1a1a1a).withOpacity(0.6),
        ],
        stops: const [0.1, 1],
      ),

      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(1.0),
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(1.0),
        ],
        stops: const [0.0, 0.07, 0.90, 1.0],
      ),

      child: child,
    );
  }
}
