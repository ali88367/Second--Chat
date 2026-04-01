import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:second_chat/core/localization/l10n.dart';

/// Renders the live stream in the same container as the stream images.
/// When [url] is null or empty, shows a black placeholder.
class StreamWebView extends StatefulWidget {
  const StreamWebView({
    super.key,
    required this.url,
    required this.height,
    this.muted = false,
  });

  final String url;
  final double height;
  final bool muted;

  @override
  State<StreamWebView> createState() => _StreamWebViewState();
}

class _StreamWebViewState extends State<StreamWebView> {
  late final WebViewController _controller;
  String? _initialUrl;
  Uri? _initialUri;
  bool _restoringInitial = false;

  @override
  void initState() {
    super.initState();
    // Configure iOS autoplay/inline playback via WebKit params when available.
    // IMPORTANT: WKWebView params cause platform channel errors on Android, so
    // we only create them on iOS.
    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    late final PlatformWebViewControllerCreationParams params;
    if (isIOS) {
      try {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } catch (_) {
        params = const PlatformWebViewControllerCreationParams();
      }
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _setInitial(_sanitizeUrl(widget.url));
  }

  String _sanitizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    // Twitch embed often fails if `parent=localhost` inside in-app WebViews.
    // Prefer a stable parent (your backend domain).
    if (uri.host.toLowerCase().contains('player.twitch.tv')) {
      final qp = Map<String, String>.from(uri.queryParameters);
      final parent = qp['parent'];
      if (parent == null || parent.isEmpty || parent == 'localhost') {
        qp['parent'] = 'cafe7bygasco.com';
      }
      return uri.replace(queryParameters: qp).toString();
    }

    return trimmed;
  }

  void _setInitial(String url) {
    final trimmed = url.trim();
    _initialUrl = trimmed.isEmpty ? null : trimmed;
    _initialUri = trimmed.isEmpty ? null : Uri.tryParse(trimmed);
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          if (_isAllowedMainFrameNavigation(url)) return;
          _restoreInitialUrl();
        },
        onPageFinished: (_) {
          _applyMuteState();
        },
        onNavigationRequest: (req) {
          final allowed = _isAllowedMainFrameNavigation(req.url);
          if (!allowed) _restoreInitialUrl();
          return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ),
    );
    if (trimmed.isNotEmpty) {
      _controller.loadRequest(Uri.parse(trimmed));
      _applyMuteState();
    }
  }

  Future<void> _applyMuteState() async {
    try {
      final mutedValue = widget.muted ? 'true' : 'false';
      await _controller.runJavaScript('''
(() => {
  const muted = $mutedValue;
  const media = Array.from(document.querySelectorAll('video,audio'));
  for (const el of media) {
    try {
      el.muted = muted;
      el.volume = muted ? 0 : 1;
    } catch (_) {}
  }
  const cmd = muted ? 'mute' : 'unMute';
  const payload = JSON.stringify({ event: 'command', func: cmd, args: '' });
  const frames = Array.from(document.querySelectorAll('iframe'));
  for (const frame of frames) {
    try {
      frame.contentWindow.postMessage(payload, '*');
    } catch (_) {}
  }
})();
''');
    } catch (_) {}
  }

  bool _isAllowedMainFrameNavigation(String rawUrl) {
    final init = _initialUrl;
    final initUri = _initialUri;
    if (init == null || init.isEmpty || initUri == null) return false;
    if (rawUrl == init || rawUrl == 'about:blank') return true;

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;

    final sameHost = uri.host.toLowerCase() == initUri.host.toLowerCase();
    if (!sameHost) return false;

    final initPath = initUri.path.isEmpty ? '/' : initUri.path;
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path == initPath) return true;
    return path.startsWith('$initPath/');
  }

  void _restoreInitialUrl() {
    if (_restoringInitial) return;
    final init = _initialUrl;
    if (init == null || init.isEmpty) return;
    _restoringInitial = true;
    _controller.loadRequest(Uri.parse(init)).whenComplete(() {
      _restoringInitial = false;
    });
  }

  @override
  void didUpdateWidget(StreamWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _setInitial(_sanitizeUrl(widget.url));
      return;
    }
    if (oldWidget.muted != widget.muted) {
      _applyMuteState();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) {
      final l10n = context.l10n;
      return SizedBox(
        height: widget.height,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, color: Colors.white38, size:43.sp),
              SizedBox(height: 7.h),
              Center(
                child: Text(
                  l10n.noStreamAtTheMoment,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
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
