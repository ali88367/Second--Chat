import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../features/go_live/go_live_screen.dart';

/// Glass go-live entry point used on home and live stream screens.
class GoLiveFabButton extends StatelessWidget {
  const GoLiveFabButton({
    super.key,
    this.padding,
    this.iconSize,
  });

  final EdgeInsetsGeometry? padding;
  final double? iconSize;

  static const Color _fill = Color(0xFF141414);
  static const Color _border = Color(0xFF4A4A4A);

  void _openGoLive() => openGoLiveScreen();

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? EdgeInsets.all(8.w);
    final size = iconSize ?? 22.sp;

    return GestureDetector(
      onTap: _openGoLive,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: pad,
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: _border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB950EF).withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              Icons.sensors_rounded,
              color: const Color(0xFFB950EF),
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}
