import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors/app_colors.dart';
import '../themes/textstyles.dart'; // <-- Import your SF Pro helper file

/// CustomTextField
///
/// A highly reusable TextFormField widget with consistent SF Pro styling,
/// validation, and icon support.
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool isRequired;
  final bool isReadOnly;
  final bool isEnabled;
  final bool isPassword;
  final bool showPasswordToggle;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final Color? borderColor;
  final Color? fillColor;
  final Color? errorColor;
  final double? borderRadius;
  final EdgeInsets? contentPadding;
  final bool showCounter;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.isRequired = false,
    this.isReadOnly = false,
    this.isEnabled = true,
    this.isPassword = false,
    this.showPasswordToggle = true,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.focusNode,
    this.autofillHints,
    this.borderColor,
    this.fillColor,
    this.errorColor,
    this.borderRadius,
    this.contentPadding,
    this.showCounter = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color finalBorderColor = widget.borderColor ?? border;
    final Color finalFillColor = widget.fillColor ?? greyScale50;
    final Color finalErrorColor = widget.errorColor ?? error;
    final double finalBorderRadius = widget.borderRadius ?? 12.r;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label with optional required asterisk
        if (widget.label != null) ...[
          Row(
            children: [
              Text(
                widget.label!,
                style: sfProText600(
                  16.sp,
                  widget.isEnabled ? textPrimary : textDisabled,
                ),
              ),
              if (widget.isRequired) ...[
                SizedBox(width: 4.w),
                Text(
                  '*',
                  style: sfProText600(16.sp, finalErrorColor),
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
        ],

        // TextFormField
        TextFormField(
          controller: _controller,
          obscureText: widget.isPassword ? _obscureText : false,
          readOnly: widget.isReadOnly,
          enabled: widget.isEnabled,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          inputFormatters: widget.inputFormatters,
          focusNode: widget.focusNode,
          autofillHints: widget.autofillHints,
          style: sfProText500(
            16.sp,
            widget.isEnabled ? textPrimary : textDisabled,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: sfProText400(
              16.sp,
              textTertiary,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
              widget.prefixIcon,
              size: 20.sp,
              color: textSecondary,
            )
                : null,
            suffixIcon: _buildSuffixIcon(),
            filled: true,
            fillColor: widget.isEnabled ? finalFillColor : greyScale100,
            contentPadding: widget.contentPadding ??
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(finalBorderRadius),
              borderSide: BorderSide(color: finalBorderColor, width: 1.w),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(finalBorderRadius),
              borderSide: BorderSide(color: finalBorderColor, width: 1.w),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(finalBorderRadius),
              borderSide: BorderSide(color: primary, width: 2.w),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(finalBorderRadius),
              borderSide: BorderSide(color: finalErrorColor, width: 1.w),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(finalBorderRadius),
              borderSide: BorderSide(color: finalErrorColor, width: 2.w),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(finalBorderRadius),
              borderSide: BorderSide(color: border, width: 1.w),
            ),
            errorStyle: sfProText400(12.sp, finalErrorColor),
            counterText: widget.showCounter ? null : '',
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.isPassword && widget.showPasswordToggle) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          size: 20.sp,
          color: textSecondary,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    } else if (widget.suffixIcon != null) {
      return Icon(
        widget.suffixIcon,
        size: 20.sp,
        color: textSecondary,
      );
    }
    return null;
  }
}