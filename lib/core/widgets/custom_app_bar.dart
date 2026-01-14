import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import '../constants/app_colors/app_colors.dart';
import 'custom_back_button.dart';

/// CustomAppBar
/// 
/// A reusable AppBar widget with consistent styling and customization options.
/// Supports back button, title, actions, and custom styling.
/// 
/// Features:
/// - Custom back button integration
/// - Customizable title and actions
/// - Consistent styling with AppColors and AppTypography
/// - Optional elevation and background color
/// - ScreenUtil sizing
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Title text displayed in the center
  final String? title;

  /// Custom title widget (overrides title if provided)
  final Widget? titleWidget;

  /// Whether to show back button (default: true)
  final bool showBackButton;

  /// Custom back button callback (default: Get.back())
  final VoidCallback? onBackPressed;

  /// List of action widgets displayed on the right
  final List<Widget>? actions;

  /// Background color of the app bar
  final Color? backgroundColor;

  /// Elevation of the app bar
  final double? elevation;

  /// Whether the app bar is automatically adjusted for system UI
  final bool automaticallyImplyLeading;

  /// Center title
  final bool centerTitle;

  /// Custom leading widget (overrides back button if provided)
  final Widget? leading;

  /// Preferred size height
  final double? preferredHeight;

  /// Bottom widget (e.g., TabBar)
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBackButton = true,
    this.onBackPressed,
    this.actions,
    this.backgroundColor,
    this.elevation,
    this.automaticallyImplyLeading = true,
    this.centerTitle = true,
    this.leading,
    this.preferredHeight,
    this.bottom,
  }) : assert(
          title == null || titleWidget == null,
          'Cannot provide both title and titleWidget',
        );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? background,
      elevation: elevation ?? 0,
      shadowColor: greyScale200,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      leading: leading ??
          (showBackButton
              ? Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: CustomBackButton(
                    onPressed: onBackPressed,
                  ),
                )
              : null),
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: sfProDisplay600(
                    14.sp,
                    textPrimary,
                  ),
                )
              : null),
      actions: actions != null
          ? [
              ...actions!,
              SizedBox(width: 8.w),
            ]
          : null,
      bottom: bottom,
      surfaceTintColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        preferredHeight ??
            (bottom != null
                ? kToolbarHeight + bottom!.preferredSize.height
                : kToolbarHeight),
      );
}

