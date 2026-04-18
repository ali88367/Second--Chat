import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/settings_controller.dart';

class CustomBlackGlassWidget extends StatelessWidget {
  /// Fixed slot heights so [Stack] hit layers align with the visual column.
  static const double _kHeaderSlotH = 38;
  static const double _kDividerSlotH = 17;
  static const double _kItemRowH = 46;

  final List<String> items;
  final bool isWeek;
  final Function(String)? onItemSelected;
  final int? initialSelectedIndex;
  final String? initialSelectedItem;

  CustomBlackGlassWidget({
    super.key,
    required this.items,
    required this.isWeek,
    this.onItemSelected,
    this.initialSelectedIndex,
    this.initialSelectedItem,
  });

  final controller = Get.put(GlassSelectorController());

  @override
  Widget build(BuildContext context) {
    // Reset selected index to 0 when widget is built to prevent out-of-range errors
    // This ensures each widget instance starts with a valid selection
    if (controller.selectedIndex.value >= items.length) {
      controller.selectedIndex.value = 0;
    }
    final wanted = _resolveInitialIndex();
    if (wanted >= 0 &&
        wanted < items.length &&
        controller.selectedIndex.value != wanted) {
      controller.selectedIndex.value = wanted;
    }
    
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
  }

  int _resolveInitialIndex() {
    final direct = initialSelectedIndex;
    if (direct != null) return direct;
    final selectedItem = initialSelectedItem?.trim();
    if (selectedItem == null || selectedItem.isEmpty) return 0;
    final idx = items.indexWhere(
      (e) => e.toLowerCase().trim() == selectedItem.toLowerCase(),
    );
    return idx >= 0 ? idx : 0;
  }

  double _calculateResponsiveRadius() {
    if (isWeek) return 30.0;

    // Calculate estimated height based on content
    final itemCount = items.length;

    const double verticalPadding = 40.0; // top + bottom padding (20 each)

    // Match slot heights in [_content].
    final estimatedHeight = _kHeaderSlotH +
        _kDividerSlotH +
        (_kItemRowH * (itemCount - 1)) +
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: _decoration(radiusValue),
      child: Obx(() {
        // Clamp selected index to valid range
        final selected = controller.selectedIndex.value.clamp(0, items.length - 1);

        return IntrinsicWidth(
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            children: [
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: _kHeaderSlotH,
                      child: Center(child: _headerVisual(selected)),
                    ),
                    SizedBox(
                      height: _kDividerSlotH,
                      child: _dividerVisual(),
                    ),
                    ..._itemVisualRows(selected),
                  ],
                ),
              ),
              ..._platformHitStack(selected),
            ],
          ),
        );
      }),
    );
  }

  // ---------------- Visual (non-interactive; taps handled by stack layers) ----------------

  Widget _headerVisual(int selected) {
    final safeIndex = selected.clamp(0, items.length - 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 15),
        const SizedBox(width: 6),
        Text(
          items[safeIndex],
          style: sfProText600(
            15,
            safeIndex == 0 ? Colors.white : _color(items[safeIndex]),
          ),
        ),
      ],
    );
  }

  Widget _dividerVisual() => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: Container(
            height: 1,
            width: 40,
            color: Colors.white.withOpacity(0.15),
          ),
        ),
      );

  List<Widget> _itemVisualRows(int selected) {
    return List.generate(items.length, (i) {
      if (i == selected) return const SizedBox.shrink();
      return SizedBox(
        height: _kItemRowH,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: isWeek ? 16 : 16),
            child: Text(
              items[i],
              textAlign: TextAlign.center,
              style: sfProText400(
                15,
                items[i].toLowerCase().trim() == 'all'
                    ? Colors.white
                    : _color(items[i]),
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Full-width hit targets per row, stacked by [top] from fixed slot heights.
  List<Widget> _platformHitStack(int selected) {
    final layers = <Widget>[
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: _kHeaderSlotH,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _select(0),
          child: const SizedBox.expand(),
        ),
      ),
      Positioned(
        top: _kHeaderSlotH,
        left: 0,
        right: 0,
        height: _kDividerSlotH,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: const SizedBox.expand(),
        ),
      ),
    ];

    var y = _kHeaderSlotH + _kDividerSlotH;
    for (var i = 0; i < items.length; i++) {
      if (i == selected) continue;
      final index = i;
      layers.add(
        Positioned(
          top: y,
          left: 0,
          right: 0,
          height: _kItemRowH,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _select(index),
            child: const SizedBox.expand(),
          ),
        ),
      );
      y += _kItemRowH;
    }
    return layers;
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
    try {
      final controller = Get.find<SettingsController>();
      return controller.getPlatformColor(text);
    } catch (e) {
      // Fallback to defaults if controller not found
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
}

class GlassSelectorController extends GetxController {
  final RxInt selectedIndex = 0.obs;

  void select(int index) {
    selectedIndex.value = index;
  }
}