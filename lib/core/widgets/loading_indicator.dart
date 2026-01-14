import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors/app_colors.dart';

/// LoadingIndicator
/// 
/// A reusable loading indicator widget that can be used as a
/// full-screen overlay or inline loading indicator.
/// 
/// Features:
/// - Full-screen or inline mode
/// - Customizable color and size
/// - Optional message text
/// - Smooth animations
enum LoadingIndicatorType { circular, linear }

class LoadingIndicator extends StatelessWidget {
  /// Type of loading indicator
  final LoadingIndicatorType type;

  /// Color of the loading indicator
  final Color? color;

  /// Size of the circular indicator (for circular type)
  final double? size;

  /// Stroke width of the circular indicator
  final double? strokeWidth;

  /// Optional message to display below the indicator
  final String? message;

  /// Whether to show as full-screen overlay
  final bool isFullScreen;

  /// Background color for full-screen mode
  final Color? backgroundColor;

  /// Whether to show a semi-transparent overlay
  final bool showOverlay;

  const LoadingIndicator({
    super.key,
    this.type = LoadingIndicatorType.circular,
    this.color,
    this.size,
    this.strokeWidth,
    this.message,
    this.isFullScreen = false,
    this.backgroundColor,
    this.showOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color finalColor = color ?? primary;
    final double finalSize = size ?? 40.w;
    final double finalStrokeWidth = strokeWidth ?? 4;

    Widget indicator;

    switch (type) {
      case LoadingIndicatorType.circular:
        indicator = SizedBox(
          width: finalSize,
          height: finalSize,
          child: CircularProgressIndicator(
            strokeWidth: finalStrokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(finalColor),
          ),
        );
        break;
      case LoadingIndicatorType.linear:
        indicator = LinearProgressIndicator(
          minHeight: finalStrokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(finalColor),
          backgroundColor: greyScale200,
        );
        break;
    }

    // Add message if provided
    if (message != null) {
      indicator = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          SizedBox(height: 16.h),
          Text(
            message!,
            style: TextStyle(
              color: textSecondary,
              fontSize: 14.sp,
            ),
          ),
        ],
      );
    }

    // Wrap in center if not full screen
    if (!isFullScreen) {
      return Center(child: indicator);
    }

    // Full-screen mode
    return Container(
      color: showOverlay
          ? (backgroundColor ?? overlayLight)
          : (backgroundColor ?? Colors.transparent),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: greyScale900.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: indicator,
        ),
      ),
    );
  }
}

/// FullScreenLoading
/// 
/// A convenience widget for showing a full-screen loading indicator.
/// This is a pre-configured LoadingIndicator with full-screen mode enabled.
class FullScreenLoading extends StatelessWidget {
  /// Optional message to display
  final String? message;

  /// Color of the loading indicator
  final Color? color;

  const FullScreenLoading({
    super.key,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LoadingIndicator(
      isFullScreen: true,
      message: message,
      color: color,
    );
  }
}

/// InlineLoading
/// 
/// A convenience widget for showing an inline loading indicator.
/// This is a pre-configured LoadingIndicator with inline mode.
class InlineLoading extends StatelessWidget {
  /// Optional message to display
  final String? message;

  /// Color of the loading indicator
  final Color? color;

  /// Size of the indicator
  final double? size;

  const InlineLoading({
    super.key,
    this.message,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return LoadingIndicator(
      isFullScreen: false,
      message: message,
      color: color,
      size: size,
    );
  }
}

