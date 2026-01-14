import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import '../constants/app_colors/app_colors.dart';

/// CustomButton
///
/// A premium, highly customizable button widget built with Container.
/// All properties are optional except for the text parameter.
///
/// Features:
/// - Fully customizable styling (colors, radius, size, shadow)
/// - Linear gradient background support (takes priority over backgroundColor)
/// - Loading state with spinner
/// - Custom widget support for prefix and suffix (Image, Icon, Svg, etc.)
/// - Full-width by default (can be customized)
/// - Disabled state
/// - Smooth tap animations
/// - Box shadow support
class CustomButton extends StatelessWidget {
  /// The text to display on the button (REQUIRED)
  final String text;

  /// Callback function when button is tapped
  final VoidCallback? onPressed;

  /// Solid background color of the button (used only if gradient is null)
  final Color? backgroundColor;

  /// Linear gradient background (takes priority over backgroundColor)
  final LinearGradient? gradient;

  /// Foreground/text color of the button
  final Color? foregroundColor;

  /// Border radius for rounded corners
  final double? borderRadius;

  /// Height of the button
  final double? height;

  /// Width of the button (null = full width)
  final double? width;

  /// Box shadow for the button
  final List<BoxShadow>? boxShadow;

  /// Whether the button is in loading state
  final bool isLoading;

  /// Whether the button is disabled
  final bool isDisabled;

  /// Custom widget to display before the text (e.g. Icon, Image, SvgPicture)
  final Widget? prefixWidget;

  /// Custom widget to display after the text
  final Widget? suffixWidget;

  /// Custom text style (optional)
  final TextStyle? textStyle;

  /// Horizontal padding around content
  final double? horizontalPadding;

  /// Vertical padding around content
  final double? verticalPadding;

  /// Border color (optional)
  final Color? borderColor;

  /// Border width (optional)
  final double? borderWidth;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.gradient,
    this.foregroundColor,
    this.borderRadius,
    this.height,
    this.width,
    this.boxShadow,
    this.isLoading = false,
    this.isDisabled = false,
    this.prefixWidget,
    this.suffixWidget,
    this.textStyle,
    this.horizontalPadding,
    this.verticalPadding,
    this.borderColor,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isDisabled && !isLoading && onPressed != null;

    // Default values
    final Color finalForegroundColor = foregroundColor ?? textInverse;
    final double finalHeight = height ?? 50.h;
    final double finalBorderRadius = borderRadius ?? (finalHeight / 2);
    final double? finalWidth = width;
    final double finalHorizontalPadding = horizontalPadding ?? 0.w;
    final double finalVerticalPadding = verticalPadding ?? 0.h;
    final List<BoxShadow> finalBoxShadow = boxShadow ??
        [
          BoxShadow(
            color: greyScale900.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];

    // Background decoration
    final BoxDecoration decoration = BoxDecoration(
      gradient: isEnabled ? gradient : null,
      color: isEnabled
          ? (gradient != null ? null : backgroundColor ?? primary)
          : greyScale300,
      borderRadius: BorderRadius.circular(finalBorderRadius),
      border: borderColor != null
          ? Border.all(
        color: isEnabled ? borderColor! : greyScale300,
        width: borderWidth ?? 1.5.w,
      )
          : null,
      boxShadow: isEnabled ? finalBoxShadow : null,
    );

    final Color effectiveForegroundColor = isEnabled
        ? finalForegroundColor
        : textDisabled;

    final TextStyle finalTextStyle = textStyle ??
        sfProDisplay500(14.sp, effectiveForegroundColor);

    Widget buttonContent = Container(
      width: finalWidth ?? double.infinity,
      height: finalHeight,
      decoration: decoration,
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(finalBorderRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: finalHorizontalPadding,
              vertical: finalVerticalPadding,
            ),
            child: isLoading
                ? Center(
              child: SizedBox(
                width: 24.w,
                height: 24.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    effectiveForegroundColor,
                  ),
                ),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (prefixWidget != null) ...[
                  prefixWidget!,
                  SizedBox(width: 8.w),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: finalTextStyle,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (suffixWidget != null) ...[
                  SizedBox(width: 8.w),
                  suffixWidget!,
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return FadeIn(
      duration: const Duration(milliseconds: 200),
      child: buttonContent,
    );
  }
}