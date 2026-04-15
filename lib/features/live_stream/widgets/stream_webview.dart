import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:second_chat/core/localization/l10n.dart';

import 'stream_embed_url_utils.dart';

/// Renders the live stream in the same container as the stream images.
/// When [url] is null or empty, shows a black placeholder.
///
/// If [streamExpectedLive] is true (platform is live but embed URL not ready yet),
/// shows an animated loading indicator instead of the delayed "no stream" message.
class StreamWebView extends StatefulWidget {
  const StreamWebView({
    super.key,
    required this.url,
    required this.height,
    required this.cacheKey,
    this.onStreamReady,
    this.muted = false,
    this.streamExpectedLive = false,
  });

  final String url;
  final double height;
  final String cacheKey;
  final void Function(String runningUrl)? onStreamReady;
  final bool muted;
  final bool streamExpectedLive;

  @override
  State<StreamWebView> createState() => _StreamWebViewState();
}

class _StreamWebViewState extends State<StreamWebView>
    with SingleTickerProviderStateMixin {
  static final Map<String, _StreamWebViewControllerSnapshot> _controllerCache =
      <String, _StreamWebViewControllerSnapshot>{};

  /// In-app idle document (avoids `about:blank` on Android, which can trigger
  /// pigeon/WebViewClient races with resource error callbacks).
  static const String _kIdleBase = 'https://secondchat.idle/stream-view/';
  static const String _kIdleHtml =
      '<!DOCTYPE html><html><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '</head><body style="margin:0;background:#000;height:100vh"></body></html>';

  late WebViewController _controller;
  String? _initialUrl;
  Uri? _initialUri;
  bool _restoringInitial = false;
  bool _delegateAttached = false;

  /// Dedupes navigations: `''` = idle shell, else last sanitized embed URL.
  String? _lastCommittedNavigation;

  /// Same logical embed as [_lastCommittedNavigation] even if the raw string differs.
  String _lastCanonicalEmbedId = '';
  String _lastStreamReadyReportedId = '';

  /// Avoids overlay flicker when [url] briefly toggles empty during socket/overview updates.
  bool _showNoStreamOverlay = false;
  bool _showLiveLoadingOverlay = false;
  Timer? _noStreamOverlayTimer;
  static const Duration _noStreamOverlayDelay = Duration(milliseconds: 480);

  late final AnimationController _dotsController;

  bool get _shellIsIdle =>
      _initialUri != null && _initialUri!.host == 'secondchat.idle';

  WebViewController _createController() {
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
    return WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  void _persistSnapshot() {
    _controllerCache[widget.cacheKey] = _StreamWebViewControllerSnapshot(
      controller: _controller,
      initialUrl: _initialUrl,
      initialUri: _initialUri,
      lastCommittedNavigation: _lastCommittedNavigation,
      lastCanonicalEmbedId: _lastCanonicalEmbedId,
    );
  }

  void _hydrateFromSnapshot(_StreamWebViewControllerSnapshot snapshot) {
    _controller = snapshot.controller;
    _initialUrl = snapshot.initialUrl;
    _initialUri = snapshot.initialUri;
    _lastCommittedNavigation = snapshot.lastCommittedNavigation;
    _lastCanonicalEmbedId = snapshot.lastCanonicalEmbedId;
  }

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    final cached = _controllerCache[widget.cacheKey];
    if (cached != null) {
      _hydrateFromSnapshot(cached);
    } else {
      _controller = _createController();
    }
    _ensureNavigationDelegate();
    _loadUrlIntoController(widget.url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncOverlays();
    });
  }

  @override
  void dispose() {
    _persistSnapshot();
    _noStreamOverlayTimer?.cancel();
    _dotsController.dispose();
    super.dispose();
  }

  void _setDotsAnimating(bool on) {
    if (on) {
      if (!_dotsController.isAnimating) {
        _dotsController.repeat();
      }
    } else {
      _dotsController.stop();
    }
  }

  void _syncOverlays() {
    final empty = widget.url.trim().isEmpty;
    if (!empty) {
      _noStreamOverlayTimer?.cancel();
      _noStreamOverlayTimer = null;
      _setDotsAnimating(false);
      if (_showNoStreamOverlay || _showLiveLoadingOverlay) {
        setState(() {
          _showNoStreamOverlay = false;
          _showLiveLoadingOverlay = false;
        });
      }
      return;
    }
    if (widget.streamExpectedLive) {
      _noStreamOverlayTimer?.cancel();
      _noStreamOverlayTimer = null;
      if (!_showLiveLoadingOverlay || _showNoStreamOverlay) {
        setState(() {
          _showNoStreamOverlay = false;
          _showLiveLoadingOverlay = true;
        });
      }
      _setDotsAnimating(true);
      return;
    }

    _setDotsAnimating(false);
    if (_showLiveLoadingOverlay) {
      setState(() => _showLiveLoadingOverlay = false);
    }
    if (_showNoStreamOverlay) return;
    _noStreamOverlayTimer?.cancel();
    _noStreamOverlayTimer = Timer(_noStreamOverlayDelay, () {
      _noStreamOverlayTimer = null;
      if (!mounted) return;
      if (widget.url.trim().isEmpty && !widget.streamExpectedLive) {
        setState(() => _showNoStreamOverlay = true);
      }
    });
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

  void _ensureNavigationDelegate() {
    if (_delegateAttached) return;
    _delegateAttached = true;
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          if (_isAllowedMainFrameNavigation(url)) return;
          _restoreInitialUrl();
        },
        onPageFinished: (_) {
          _applyMuteState();
          _maybeReportStreamReady();
        },
        onNavigationRequest: (req) {
          final allowed = _isAllowedMainFrameNavigation(req.url);
          if (!allowed) _restoreInitialUrl();
          return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ),
    );
  }

  void _logWebNavError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('[StreamWebView] navigation failed: $error');
    }
  }

  /// Keeps the native WebView alive: empty URL → local black HTML shell under overlay.
  void _loadUrlIntoController(String raw) {
    try {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        if (_lastCommittedNavigation == '') return;
        _lastCommittedNavigation = '';
        _lastCanonicalEmbedId = '';
        _initialUrl = _kIdleBase;
        _initialUri = Uri.parse(_kIdleBase);
        _controller
            .loadHtmlString(_kIdleHtml, baseUrl: _kIdleBase)
            .catchError(_logWebNavError);
        _persistSnapshot();
        _applyMuteState();
        return;
      }
      final sanitized = _sanitizeUrl(trimmed);
      final nextId = canonicalStreamEmbedIdentity(sanitized);
      if (nextId.isNotEmpty && nextId == _lastCanonicalEmbedId) {
        _applyMuteState();
        return;
      }
      _lastCommittedNavigation = sanitized;
      _lastCanonicalEmbedId = nextId;
      _initialUrl = sanitized;
      _initialUri = Uri.tryParse(sanitized);
      _controller
          .loadRequest(Uri.parse(sanitized))
          .catchError(_logWebNavError);
      _persistSnapshot();
      _applyMuteState();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StreamWebView] _loadUrlIntoController: $e');
      }
    }
  }

  Future<void> _applyMuteState() async {
    if (_shellIsIdle) return;
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

  Future<void> _maybeReportStreamReady() async {
    final cb = widget.onStreamReady;
    if (cb == null) return;
    if (_shellIsIdle) return;
    final currentUrl = _initialUrl?.trim() ?? '';
    if (currentUrl.isEmpty) return;
    final currentId = canonicalStreamEmbedIdentity(currentUrl);
    if (currentId.isEmpty || currentId == _lastStreamReadyReportedId) return;
    // A completed page load with non-idle URL is treated as stream-ready trigger.
    _lastStreamReadyReportedId = currentId;
    cb(currentUrl);
  }

  bool _isAllowedMainFrameNavigation(String rawUrl) {
    final init = _initialUrl;
    final initUri = _initialUri;
    if (init == null || init.isEmpty || initUri == null) return false;
    if (rawUrl == init) return true;

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;

    // First load from idle shell → real embed.
    if (initUri.host == 'secondchat.idle' &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return true;
    }

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
    void done() {
      _restoringInitial = false;
    }

    if (_shellIsIdle) {
      _controller
          .loadHtmlString(_kIdleHtml, baseUrl: _kIdleBase)
          .catchError(_logWebNavError)
          .whenComplete(done);
      return;
    }
    _controller
        .loadRequest(Uri.parse(init))
        .catchError(_logWebNavError)
        .whenComplete(done);
  }

  @override
  void didUpdateWidget(StreamWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) {
      _controllerCache[oldWidget.cacheKey] = _StreamWebViewControllerSnapshot(
        controller: _controller,
        initialUrl: _initialUrl,
        initialUri: _initialUri,
        lastCommittedNavigation: _lastCommittedNavigation,
        lastCanonicalEmbedId: _lastCanonicalEmbedId,
      );
      final cached = _controllerCache[widget.cacheKey];
      if (cached != null) {
        _hydrateFromSnapshot(cached);
      } else {
        _controller = _createController();
      }
      _delegateAttached = false;
      _ensureNavigationDelegate();
    }
    final urlChanged =
        !streamEmbedUrlsCanonicallyEqual(oldWidget.url, widget.url);
    final liveFlagChanged =
        oldWidget.streamExpectedLive != widget.streamExpectedLive;
    if (urlChanged) {
      _syncOverlays();
      _loadUrlIntoController(widget.url);
      _lastStreamReadyReportedId = '';
    } else if (liveFlagChanged) {
      _syncOverlays();
    }
    if (oldWidget.muted != widget.muted) {
      _applyMuteState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller),
          if (_showLiveLoadingOverlay)
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: AnimatedBuilder(
                  animation: _dotsController,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final base =
                            _dotsController.value * 2 * math.pi + i * 0.9;
                        final opacity =
                            0.35 + 0.65 * (0.5 + 0.5 * math.sin(base));
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3.w),
                          child: Opacity(
                            opacity: opacity.clamp(0.2, 1.0),
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 32.sp,
                                height: 1,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),
          if (_showNoStreamOverlay)
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off, color: Colors.white38, size: 43.sp),
                    SizedBox(height: 7.h),
                    Text(
                      l10n.noStreamAtTheMoment,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreamWebViewControllerSnapshot {
  _StreamWebViewControllerSnapshot({
    required this.controller,
    required this.initialUrl,
    required this.initialUri,
    required this.lastCommittedNavigation,
    required this.lastCanonicalEmbedId,
  });

  final WebViewController controller;
  final String? initialUrl;
  final Uri? initialUri;
  final String? lastCommittedNavigation;
  final String lastCanonicalEmbedId;
}
