import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import '../constants/app_colors/app_colors.dart';

/// CustomSwitch
/// 
/// A beautiful custom switch widget using Flutter's built-in Switch
/// with customized appearance - wider, shorter, with rounded rectangle thumb.
/// 
/// Features:
/// - Uses Flutter's Material Switch widget for behavior
/// - Custom visual appearance (wider, shorter, rounded rectangle thumb)
/// - Customizable colors (active/inactive)
/// - Optional label and description
/// - Proper sizing with ScreenUtil
class CustomSwitch extends StatelessWidget {
  /// Whether the switch is on or off
  final bool value;

  /// Callback when switch value changes
  final ValueChanged<bool>? onChanged;

  /// Label text displayed before the switch
  final String? label;

  /// Description text displayed below the label
  final String? description;

  /// Active color when switch is on (default: light brown/golden)
  final Color? activeColor;

  /// Inactive color when switch is off (default: greyScale300)
  final Color? inactiveColor;

  /// Color of the switch thumb (default: Colors.white)
  final Color? thumbColor;

  /// Whether the switch is disabled
  final bool isDisabled;

  /// Main axis alignment for label and switch
  final MainAxisAlignment mainAxisAlignment;

  /// Spacing between label and switch
  final double? spacing;

  const CustomSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.description,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.isDisabled = false,
    this.mainAxisAlignment = MainAxisAlignment.spaceBetween,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    // Colors updated to requested hex codes
    final Color finalActiveColor = activeColor ?? const Color(0xFFE6C571);
    final Color finalInactiveColor = inactiveColor ?? const Color(0x4D3C3C43);
    final Color finalThumbColor = thumbColor ?? Colors.white;
    final double finalSpacing = spacing ?? 12.w;

    // Dimensions: wider and shorter for lengthy look
    final double switchWidth = 64.w; // Increased width for lengthy look
    final double switchHeight = 28.h; // Reduced height
    final double thumbPadding = 2.h;
    final double thumbHeight = switchHeight - (thumbPadding * 2);
    final double thumbWidth = 39.w; // Rectangle thumb (longer than tall)

    // Custom switch theme
    final SwitchThemeData switchTheme = SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.transparent), // Make transparent to overlay custom thumb
      trackColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return finalInactiveColor.withOpacity(0.5);
          }
          if (states.contains(WidgetState.selected)) {
            return finalActiveColor;
          }
          return finalInactiveColor;
        },
      ),
      overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
          if (states.contains(WidgetState.pressed)) {
            return finalActiveColor.withOpacity(0.2);
          }
          return null;
        },
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    // Build the switch widget with custom appearance
    Widget switchWidget = SizedBox(
      width: switchWidth,
      height: switchHeight,
      child: Theme(
        data: Theme.of(context).copyWith(switchTheme: switchTheme),
        child: Stack(
          children: [
            // Base Switch widget (handles behavior)
            Positioned.fill(
              child: Opacity(
                opacity: 0, // Make invisible, we'll overlay custom visuals
                child: Switch(
                  value: value,
                  onChanged: isDisabled ? null : onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            // Custom track background
            Container(
              width: switchWidth,
              height: switchHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100.r),
                color: value ? finalActiveColor : finalInactiveColor,
              ),
            ),
            // Custom rounded rectangle thumb
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: value ? (switchWidth - thumbWidth - thumbPadding) : thumbPadding,
              top: thumbPadding,
              child: Container(
                width: thumbWidth,
                height: thumbHeight,
                decoration: BoxDecoration(
                  color: finalThumbColor,
                  borderRadius: BorderRadius.circular(switchHeight / 1.5), // Rounded borders matching track
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Wrap in GestureDetector for tap handling
    if (!isDisabled && onChanged != null) {
      switchWidget = GestureDetector(
        onTap: () => onChanged!(!value),
        child: switchWidget,
      );
    } else if (isDisabled) {
      switchWidget = Opacity(
        opacity: 0.5,
        child: switchWidget,
      );
    }

    // If no label, return just the switch
    if (label == null && description == null) {
      return switchWidget;
    }

    // Build label section
    Widget? labelWidget;
    if (label != null || description != null) {
      labelWidget = Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null)
              Text(
                label!,
                style: sfProDisplay500(
                  14.sp,
                  isDisabled
                      ? textDisabled
                      : textPrimary,
                ),
              ),
            if (description != null) ...[
              SizedBox(height: 4.h),
              Text(
                description!,
                style: sfProDisplay500(
                  15.sp,
                  isDisabled
                      ? textDisabled
                      : textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (labelWidget != null) ...[
          labelWidget,
          SizedBox(width: finalSpacing),
        ],
        switchWidget,
      ],
    );
  }
}