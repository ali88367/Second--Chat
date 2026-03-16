import 'package:flutter/material.dart';

@Deprecated('OAuth now uses Custom Tabs. This screen is no longer used.')
class OAuthWebViewScreen extends StatelessWidget {
  const OAuthWebViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'OAuth is handled in your browser.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
