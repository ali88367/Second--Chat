import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';

import '../../controllers/Main Section Controllers/streak_controller.dart';

class CCustomBlackGlassWidget extends StatelessWidget {
  final List<String> items;
  final bool isWeek;
  final Function(String)? onItemSelected;

  CCustomBlackGlassWidget({
    super.key,
    required this.items,
    required this.isWeek,
    this.onItemSelected,
  });

  // Use different controllers depending on mode (or same if you refactor later)
  final streakController = Get.find<StreamStreaksController>(); // ← from your streak example
  final glassController = Get.put(GlassSelectorController1());  // original one

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final radiusValue = _calculateResponsiveRadius();
        final radius = BorderRadius.circular(radiusValue);

        return ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: isWeek ? 90.w : null,
              padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
              decoration: _decoration(radiusValue),
              child: isWeek
                  ? _buildStreakContent(radiusValue)
                  : _buildNormalContent(radiusValue),
            ),
          ),
        );
      },
    );
  }

  // ── Streak mode (week == true) ────────────────────────────────────────────
  Widget _buildStreakContent(double radiusValue) {
    return Obx(() {
      final selectedNumbers = streakController.selectedMenuNumbers;
      final availableNumbers = streakController.availableNumbers;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected items (with checkmark)
          ...selectedNumbers.map((num) => _buildSelectedStreakItem(num)),

          // Divider (only if there are selected items)
          if (selectedNumbers.isNotEmpty) _divider(),

          // Available items (no checkmark, lower opacity)
          ...availableNumbers.map((num) => _buildAvailableStreakItem(num)),
        ],
      );
    });
  }

  Widget _buildSelectedStreakItem(int num) {
    return GestureDetector(
      onTap: () {
        streakController.toggleMenuNumber(num);
        onItemSelected?.call("$num");
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 14),
            SizedBox(width: 6.w),
            Text(
              "$num",
              style: sfProText600(17.sp, Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableStreakItem(int num) {
    return GestureDetector(
      onTap: () {
        streakController.toggleMenuNumber(num);
        onItemSelected?.call("$num");
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text(
          "$num",
          textAlign: TextAlign.center,
          style: sfProText600(17.sp, Colors.white.withOpacity(0.6)),
        ),
      ),
    );
  }

  // ── Normal mode (week == false) ───────────────────────────────────────────
  Widget _buildNormalContent(double radiusValue) {
    return Obx(() {
      final selected = glassController.selectedIndex.value;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(selected),
          _divider(),
          ..._items(selected),
        ],
      );
    });
  }

  Widget _header(int selected) {
    return GestureDetector(
      onTap: () => _select(0, isStreak: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            items[selected],
            style: sfProText600(
              15,
              selected == 0 ? Colors.white : _color(items[selected]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _items(int selected) {
    return List.generate(items.length, (i) {
      if (i == selected) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () => _select(i, isStreak: false),
        child: Padding(
          padding: EdgeInsets.only(top: 16.h),
          child: Text(
            items[i],
            textAlign: TextAlign.center,
            style: sfProText400(15, _color(items[i])),
          ),
        ),
      );
    });
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _divider() => Padding(
    padding: EdgeInsets.only(top: 16.h, bottom: 8.h),
    child: Container(
      height: 1,
      width: 40.w,
      color: Colors.white.withOpacity(0.15),
    ),
  );

  void _select(int index, {required bool isStreak}) {
    if (isStreak) {
      // handled inside streakController.toggleMenuNumber()
    } else {
      glassController.select(index);
      onItemSelected?.call(items[index]);
    }
  }

  double _calculateResponsiveRadius() {
    if (isWeek) {
      // Streak mode — simpler estimation (like your second file)
      final totalItems = streakController.selectedMenuNumbers.length +
          streakController.availableNumbers.length;
      final estimatedHeight = (31.h * totalItems) + 40.h;
      return (estimatedHeight * 0.2).clamp(22.0, 35.0);
    }

    // Normal mode — your original logic
    final itemCount = items.length;
    const double headerHeight = 21.0;
    const double dividerHeight = 17.0;
    const double itemHeight = 31.0;
    const double verticalPadding = 40.0;

    final estimatedHeight = headerHeight +
        dividerHeight +
        (itemHeight * (itemCount - 1)) +
        verticalPadding;

    double radiusPercentage;
    if (estimatedHeight <= 150) {
      radiusPercentage = 0.30;
    } else if (estimatedHeight <= 200) {
      radiusPercentage = 0.22;
    } else if (estimatedHeight <= 280) {
      radiusPercentage = 0.17;
    } else {
      radiusPercentage = 0.13;
    }

    final calculated = (estimatedHeight * radiusPercentage) / 2;
    return calculated.clamp(22.0, 35.0);
  }

  BoxDecoration _decoration(double radiusValue) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusValue),
      border: GradientBoxBorder(
        width: 1.2,
        gradient: SweepGradient(
          colors: [
            Colors.white.withOpacity(.12),
            Colors.black,
            Colors.white.withOpacity(.12),
            Colors.white.withOpacity(.12),
            Colors.black,
            Colors.white.withOpacity(.12),
          ],
          stops: isWeek ? [0, .3, .34, .65, .75, 1] : [0, .35, .36, .82, .83, 1],
        ),
      ),
      color: Colors.black.withOpacity(.2),
      gradient: isWeek
          ? null
          : const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, .33, .43, .7, 1],
        colors: [
          Color(0xFF000000),
          Color(0xFF171717),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0xFF262626),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isWeek ? .25 : .5),
          blurRadius: isWeek ? 4 : 20,
          offset: Offset(0, isWeek ? 4 : 10),
        ),
      ],
    );
  }

  Color _color(String text) {
    switch (text.toLowerCase()) {
      case 'twitch':
        return twitchPurple;
      case 'kick':
        return kickGreen;
      case 'youtube':
        return youtubeRed;
      default:
        return Colors.white;
    }
  }
}

// Keep your original controller for non-streak mode
class GlassSelectorController1 extends GetxController {
  final RxInt selectedIndex = 0.obs;

  void select(int index) {
    selectedIndex.value = index;
  }
}