import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:second_chat/core/constants/app_images/app_images.dart';

/// Blur + simple solid border; sizes to [padding] + [child] (no fixed width/height).
class _GlassHeaderChip extends StatelessWidget {
  const _GlassHeaderChip({
    required this.padding,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  static const double _borderRadius = 22;
  static const double _blur = 12;
  static const Color _fillColor = Color(0xFF141414);
  static const Color _borderColor = Color(0xFF4A4A4A);

  @override
  Widget build(BuildContext context) {
    const r = _borderRadius;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur * 2),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Glass pill showing stream streak count.
class StreakButton extends StatelessWidget {
  const StreakButton({
    super.key,
    this.count,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.iconAsset = gradient_flame_icon,
  });

  final int? count;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final label = '${count ?? 0}';

    return GestureDetector(
      onTap: onTap,
      child: _GlassHeaderChip(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(iconAsset, width: 24, height: 24),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass pill for whether any connected platform stream is live.
class StreamStatusButton extends StatelessWidget {
  const StreamStatusButton({
    super.key,
    required this.isOnline,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.offlineIconAsset = bolt_icon,
  });

  final bool isOnline;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String offlineIconAsset;

  @override
  Widget build(BuildContext context) {
    final statusLabel = isOnline ? 'Online' : 'Offline';

    return GestureDetector(
      onTap: onTap,
      child: _GlassHeaderChip(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isOnline) ...[
              Image.asset(offlineIconAsset, width: 24, height: 24),
              const SizedBox(width: 6),
            ],
            Text(
              statusLabel,
              style: const TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
