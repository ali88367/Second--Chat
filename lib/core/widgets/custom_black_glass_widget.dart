import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';

class CustomBlackGlassWidget extends StatelessWidget {
  final List<String> items;
  final bool isWeek;
  final Function(String)? onItemSelected;

  CustomBlackGlassWidget({
    super.key,
    required this.items,
    required this.isWeek,
    this.onItemSelected,
  });

  final controller = Get.put(GlassSelectorController());

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive radius based on estimated height
        final radiusValue = _calculateResponsiveRadius();
        final radius = BorderRadius.circular(radiusValue);

        return ClipRRect(
          borderRadius: radius,
          child: isWeek
              ? BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: _content(radiusValue),
          )
              : _content(radiusValue),
        );
      },
    );
  }

  double _calculateResponsiveRadius() {
    if (isWeek) return 30.0;

    // Calculate estimated height based on content
    final itemCount = items.length;

    // Base heights (approximate)
    const double headerHeight = 21.0; // checkmark + text
    const double dividerHeight = 17.0; // divider with padding
    const double itemHeight = 31.0; // text + padding (16 top padding + ~15 text height)
    const double verticalPadding = 40.0; // top + bottom padding (20 each)

    // Calculate total estimated height
    final estimatedHeight = headerHeight +
        dividerHeight +
        (itemHeight * (itemCount - 1)) + // -1 because selected item is hidden
        verticalPadding;

    // Calculate radius as a percentage of height
    // For optimal pill shape: radius should be ~15-20% of height for taller widgets
    // and can go up to ~30-35% for shorter widgets
    double radiusPercentage;

    if (estimatedHeight <= 150) {
      // Short widget (2-3 items): use larger radius percentage
      radiusPercentage = 0.30; // 30%
    } else if (estimatedHeight <= 200) {
      // Medium widget (4-5 items): balanced radius
      radiusPercentage = 0.22; // 22%
    } else if (estimatedHeight <= 280) {
      // Tall widget (6-7 items): smaller radius percentage
      radiusPercentage = 0.17; // 17%
    } else {
      // Very tall widget (8+ items): minimal radius percentage
      radiusPercentage = 0.13; // 13%
    }

    final calculatedRadius = (estimatedHeight * radiusPercentage) / 2;

    // Clamp between reasonable min/max values
    return calculatedRadius.clamp(22.0, 35.0);
  }

  Widget _content(double radiusValue) {
    return Container(
      width: isWeek ? 90.w : null,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: _decoration(radiusValue),
      child: Obx(() {
        final selected = controller.selectedIndex.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(selected),
            _divider(),
            ..._items(selected),
          ],
        );
      }),
    );
  }

  // ---------------- UI Parts ----------------

  Widget _header(int selected) {
    return GestureDetector(
      onTap: () => _select(0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.checkmark,
              color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            items[selected],
            style: sfProText600(
              15,
              selected == 0
                  ? Colors.white
                  : _color(items[selected]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Container(
      height: 1,
      width: 40,
      color: Colors.white.withOpacity(0.15),
    ),
  );

  List<Widget> _items(int selected) {
    return List.generate(items.length, (i) {
      if (i == selected) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () => _select(i),
        child: Padding(
          padding: EdgeInsets.only(top: isWeek ? 16 : 16),
          child: Text(
            items[i],
            textAlign: TextAlign.center,
            style: sfProText400(15, _color(items[i])),
          ),
        ),
      );
    });
  }

  // ---------------- Helpers ----------------

  void _select(int index) {
    controller.select(index);
    onItemSelected?.call(items[index]);
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
          stops: isWeek
              ? [0, .3, .34, .65, .75, 1]
              : [0, .35, .36, .82, .83, 1],
        ),
      ),
      color: isWeek ? Colors.black.withOpacity(.2) : null,
      gradient: isWeek ? null : _blackGradient(),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isWeek ? .25 : .5),
          blurRadius: isWeek ? 4 : 20,
          offset: Offset(0, isWeek ? 4 : 10),
        ),
      ],
    );
  }

  LinearGradient _blackGradient() => const LinearGradient(
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
  );

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

class GlassSelectorController extends GetxController {
  final RxInt selectedIndex = 0.obs;

  void select(int index) {
    selectedIndex.value = index;
  }
}