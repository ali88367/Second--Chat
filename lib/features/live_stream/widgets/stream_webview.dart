import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders the live stream in the same container as the stream images.
/// When [url] is null or empty, shows a black placeholder.
class StreamWebView extends StatefulWidget {
  const StreamWebView({super.key, required this.url, required this.height});

  final String url;
  final double height;

  @override
  State<StreamWebView> createState() => _StreamWebViewState();
}

class _StreamWebViewState extends State<StreamWebView> {
  late final WebViewController _controller;
  String? _initialUrl;
  Uri? _initialUri;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    _setInitial(widget.url);
  }

  void _setInitial(String url) {
    final trimmed = url.trim();
    _initialUrl = trimmed.isEmpty ? null : trimmed;
    _initialUri = trimmed.isEmpty ? null : Uri.tryParse(trimmed);
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (req) {
          final init = _initialUrl;
          if (init == null || init.isEmpty) return NavigationDecision.prevent;
          // Prevent leaving the embedded player.
          // Allow:
          // - the initial URL itself
          // - same-origin navigations (some platforms redirect www -> apex, etc.)
          // - known player hosts (e.g. Twitch).
          final u = req.url;
          if (u == init) return NavigationDecision.navigate;
          final uri = Uri.tryParse(u);
          if (uri == null) return NavigationDecision.prevent;
          final initUri = _initialUri;
          bool sameOriginAllowed() {
            if (initUri == null) return false;
            final a = initUri.host.toLowerCase();
            final b = uri.host.toLowerCase();
            if (a.isEmpty || b.isEmpty) return false;
            if (a == b) return true;
            if (b.endsWith('.$a')) return true; // subdomain of initial
            if (a.endsWith('.$b')) return true; // initial is a subdomain
            // common redirects
            if (a == 'kick.com' && b == 'www.kick.com') return true;
            if (a == 'www.kick.com' && b == 'kick.com') return true;
            if (a == 'youtube.com' && b == 'www.youtube.com') return true;
            if (a == 'www.youtube.com' && b == 'youtube.com') return true;
            return false;
          }

          final host = uri.host.toLowerCase();
          final knownPlayerHosts = <String>{
            'player.twitch.tv',
            'twitch.tv',
            'www.twitch.tv',
            'kick.com',
            'www.kick.com',
            'youtube.com',
            'www.youtube.com',
            'm.youtube.com',
            'youtu.be',
          };

          if (sameOriginAllowed()) return NavigationDecision.navigate;
          if (knownPlayerHosts.contains(host)) return NavigationDecision.navigate;
          if (host.endsWith('.twitch.tv') ||
              host.endsWith('.kick.com') ||
              host.endsWith('.youtube.com')) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ),
    );
    if (trimmed.isNotEmpty) {
      _controller.loadRequest(Uri.parse(trimmed));
    }
  }

  @override
  void didUpdateWidget(StreamWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _setInitial(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child:  Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, color: Colors.white38, size:43.sp),
              SizedBox(height: 7.h),
              Center(
                child: Text(
                  'No stream at the moment',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      child: WebViewWidget(controller: _controller),
    );
  }
}
