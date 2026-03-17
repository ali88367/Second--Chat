import 'package:flutter/material.dart';
import 'package:second_chat/core/localization/l10n.dart';

@Deprecated('OAuth now uses Custom Tabs. This screen is no longer used.')
class OAuthWebViewScreen extends StatelessWidget {
  const OAuthWebViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          context.l10n.oauthHandledInBrowser,
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
