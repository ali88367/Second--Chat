import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../constants/app_colors/app_colors.dart';

/// CustomBackButton
/// 
/// A reusable back button widget that uses Get.back() for navigation.
/// Supports custom icon, color, and smooth animations.
/// 
/// Features:
/// - Uses GetX navigation (Get.back())
/// - Customizable icon
/// - Customizable color
/// - AnimateDo fade-in animation
/// - Optional onPressed callback for custom behavior
class CustomBackButton extends StatelessWidget {
  /// Custom icon to display (default: Icons.arrow_back)
  final IconData? icon;

  /// Color of the icon (default: AppColors.textPrimary)
  final Color? color;

  /// Size of the icon (default: 24.sp)
  final double? iconSize;

  /// Callback when button is pressed (default: Get.back())
  final VoidCallback? onPressed;

  /// Whether to show a circular background
  final bool showBackground;

  /// Background color when showBackground is true
  final Color? backgroundColor;

  /// Padding around the button
  final EdgeInsets? padding;

  const CustomBackButton({
    super.key,
    this.icon,
    this.color,
    this.iconSize,
    this.onPressed,
    this.showBackground = false,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final IconData finalIcon = icon ?? Icons.arrow_back;
    final Color finalColor = color ?? textPrimary;
    final double finalIconSize = iconSize ?? 24.sp;
    final VoidCallback finalOnPressed = onPressed ?? () => Get.back();

    Widget button = IconButton(
      onPressed: finalOnPressed,
      icon: Icon(
        finalIcon,
        color: finalColor,
        size: finalIconSize,
      ),
      padding: padding ?? EdgeInsets.all(8.w),
      constraints: const BoxConstraints(),
    );

    if (showBackground) {
      button = Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? greyScale100,
          shape: BoxShape.circle,
        ),
        child: button,
      );
    }

    return FadeInLeft(
      duration: const Duration(milliseconds: 300),
      child: button,
    );
  }
}

