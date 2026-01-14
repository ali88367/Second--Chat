import 'package:flutter/material.dart';

import 'main_section/stream/stream_screen.dart';

class Test extends StatefulWidget {
  const Test({super.key});

  @override
  State<Test> createState() => _TestState();
}

class _TestState extends State<Test> {
  String _test = '';
  bool _switchValue = false;

  @override
  Widget build(BuildContext context) {
    return StreamScreen();
  }
}
