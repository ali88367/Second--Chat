import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'intro_screen3.dart';

class IntroScreenNotification2 extends StatelessWidget {
  const IntroScreenNotification2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Get.to(IntroScreen3());
        },
        child: Image.asset(
          'assets/images/notification.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
