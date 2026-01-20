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
    final radius = BorderRadius.circular(isWeek ? 30 : 35);

    return ClipRRect(
      borderRadius: radius,
      child: isWeek
          ? BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: _content(),
      )
          : _content(),
    );
  }

  Widget _content() {
    return Container(
      width: isWeek ? 90.w : null,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: _decoration(),
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

  BoxDecoration _decoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(isWeek ? 38 : 35),
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
