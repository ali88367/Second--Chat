import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:second_chat/core/localization/l10n.dart';

import 'stream_embed_url_utils.dart';

/// Renders the live stream in the same container as the stream images.
/// When [url] is null or empty, shows a black placeholder.
///
/// If [streamExpectedLive] is false, always shows the "no stream" state and loads the idle
/// shell — even when [url] is still non-empty (stale embed URL).
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

    /// When true (e.g. in-app fullscreen opened from multi-preview), blocks
    /// document/iframe fullscreen APIs so the embed's fullscreen control
    /// cannot crash against the host route.
    this.suppressNativeFullscreen = false,

    /// When set (e.g. fullscreen route), constrains width so the WebView fills
    /// the entire viewport for correct aspect / layout.
    this.width,

    /// When true (default), uses [EagerGestureRecognizer] so the embed wins
    /// drags against outer [ScrollView]s. Set false for small preview tiles
    /// where a parent [GestureDetector] or overlay must receive taps.
    this.useEagerGestureArena = true,
  });

  final String url;
  final double height;
  final double? width;
  final String cacheKey;
  final void Function(String runningUrl)? onStreamReady;
  final bool muted;
  final bool streamExpectedLive;
  final bool suppressNativeFullscreen;
  final bool useEagerGestureArena;

  @override
  State<StreamWebView> createState() => StreamWebViewState();
}

class StreamWebViewState extends State<StreamWebView>
    with SingleTickerProviderStateMixin {
  static final Map<String, _StreamWebViewControllerSnapshot> _controllerCache =
      <String, _StreamWebViewControllerSnapshot>{};
  static const int _maxCachedControllers = 4;

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
  String _packageNameForYoutubeHeaders = 'second.chat';
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

  static String _normalizedPlatformKeyFromCacheKey(String rawCacheKey) {
    final key = rawCacheKey.toLowerCase().trim();
    if (key.contains('kick')) return 'kick';
    if (key.contains('twitch')) return 'twitch';
    if (key.contains('youtube')) return 'youtube';
    return key;
  }

  String get _normalizedPlatformKey {
    return _normalizedPlatformKeyFromCacheKey(widget.cacheKey);
  }

  bool get _disableLiveLoadingOverlayForPlatform {
    // Keep Kick behavior as before: no animated dots while waiting for URL.
    return _normalizedPlatformKey == 'kick';
  }

  static bool _shouldReuseControllerCacheForKey(String rawCacheKey) {
    final normalized = _normalizedPlatformKeyFromCacheKey(rawCacheKey);
    if (normalized == 'kick') return false;
    if (rawCacheKey.toLowerCase().startsWith('fullscreen_')) return false;
    return true;
  }

  bool get _shouldReuseControllerCache {
    // Kick is prone to stale native player/session state after mode toggles and
    // embed fullscreen transitions. Fresh controller per mount is more stable.
    return _shouldReuseControllerCacheForKey(widget.cacheKey);
  }

  void _trimControllerCache({String? keepKey}) {
    while (_controllerCache.length > _maxCachedControllers) {
      final oldestKey = _controllerCache.keys.first;
      if (keepKey != null &&
          oldestKey == keepKey &&
          _controllerCache.length > 1) {
        final snapshot = _controllerCache.remove(oldestKey);
        if (snapshot != null) {
          _controllerCache[oldestKey] = snapshot;
        }
        continue;
      }
      _controllerCache.remove(oldestKey);
    }
  }

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
    _trimControllerCache(keepKey: widget.cacheKey);
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
    if (_shouldReuseControllerCache && cached != null) {
      _hydrateFromSnapshot(cached);
    } else {
      _controllerCache.remove(widget.cacheKey);
      _controller = _createController();
    }
    _ensureNavigationDelegate();
    unawaited(_loadPackageInfo());
    _loadUrlIntoController(widget.url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncOverlays();
    });
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final packageName = info.packageName.trim();
      if (packageName.isNotEmpty && mounted) {
        setState(() {
          _packageNameForYoutubeHeaders = packageName;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_shouldReuseControllerCache) {
      _persistSnapshot();
    } else {
      _controllerCache.remove(widget.cacheKey);
    }
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
    // Platform offline: always show "no stream" and unload the embed, even if [url] is still
    // non-empty (stale props or race with socket `stream:status`).
    if (!widget.streamExpectedLive) {
      _noStreamOverlayTimer?.cancel();
      _noStreamOverlayTimer = null;
      _setDotsAnimating(false);
      _loadUrlIntoController('');
      setState(() {
        _showLiveLoadingOverlay = false;
        _showNoStreamOverlay = true;
      });
      return;
    }

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
      if (_disableLiveLoadingOverlayForPlatform) {
        _setDotsAnimating(false);
        if (_showLiveLoadingOverlay || _showNoStreamOverlay) {
          setState(() {
            _showNoStreamOverlay = false;
            _showLiveLoadingOverlay = false;
          });
        }
        return;
      }
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
      if (widget.suppressNativeFullscreen) {
        qp['allowfullscreen'] = 'false';
      }
      return uri.replace(queryParameters: qp).toString();
    }

    final host = uri.host.toLowerCase();
    final isYoutubeHost =
        host.contains('youtube.com') || host.contains('youtube-nocookie.com');
    final isYoutubeEmbedPath =
        uri.path.toLowerCase().contains('/embed/');
    if (isYoutubeHost && isYoutubeEmbedPath) {
      final qp = Map<String, String>.from(uri.queryParameters);
      // WebView-safe YouTube embed defaults: avoid common embed/player errors.
      qp['autoplay'] = '1';
      qp['mute'] = '1';
      qp['playsinline'] = '1';
      qp['enablejsapi'] = '1';
      if (widget.suppressNativeFullscreen) {
        qp['fs'] = '0';
      }
      final pathParts = uri.pathSegments;
      final embedIdx = pathParts.indexOf('embed');
      String videoId = '';
      if (embedIdx != -1 && embedIdx + 1 < pathParts.length) {
        videoId = pathParts[embedIdx + 1].trim();
      }
      if (videoId.isEmpty) {
        return uri.replace(queryParameters: qp).toString();
      }
      return Uri.https(
        'www.youtube-nocookie.com',
        '/embed/$videoId',
        qp,
      ).toString();
    }

    if (widget.suppressNativeFullscreen &&
        isYoutubeHost) {
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['fs'] = '0';
      return uri.replace(queryParameters: qp).toString();
    }

    // Kick embed: ensure fullscreen is allowed when not suppressed
    if (host.contains('kick.com') || host.contains('player.kick.com')) {
      final qp = Map<String, String>.from(uri.queryParameters);
      if (!qp.containsKey('allowfullscreen') &&
          !widget.suppressNativeFullscreen) {
        qp['allowfullscreen'] = 'true';
      }
      if (widget.suppressNativeFullscreen) {
        qp['allowfullscreen'] = 'false';
      }
      return uri.replace(queryParameters: qp).toString();
    }

    return trimmed;
  }

  Future<void> _suppressEmbeddedFullscreenChrome() async {
    if (!widget.suppressNativeFullscreen) return;
    try {
      await _controller.runJavaScript(r'''
(() => {
  const noop = function() { return Promise.resolve(); };
  const patch = () => {
    try {
      Element.prototype.requestFullscreen = noop;
      Element.prototype.webkitRequestFullscreen = noop;
      Element.prototype.mozRequestFullScreen = noop;
      Element.prototype.msRequestFullscreen = noop;
    } catch (_) {}
    document.querySelectorAll('iframe').forEach((f) => {
      try {
        f.removeAttribute('allowfullscreen');
      } catch (_) {}
    });
  };
  patch();
  try {
    const mo = new MutationObserver(() => patch());
    mo.observe(document.documentElement, { childList: true, subtree: true });
  } catch (_) {}
})();
''');
    } catch (_) {}
  }

  /// Kick multi-preview: fill the tile without clipping the player’s own overlay UI
  /// (`overflow:hidden` + absolutely positioned iframes broke controls). Re-apply
  /// briefly as the embed mounts subtrees (debounced MutationObserver).
  Future<void> _injectKickEmbedContainmentLayout() async {
    if (_normalizedPlatformKey != 'kick') return;
    if (widget.suppressNativeFullscreen) return;
    if (_shellIsIdle) return;
    // Only force the tile containment CSS in small multi-preview slots.
    // In larger/single previews this can fight the player's own fullscreen styles.
    if (widget.height > 200) return;
    try {
      await _controller.runJavaScript(r'''
(() => {
  try {
    if (window.__secondChatKickLayoutMo) {
      window.__secondChatKickLayoutMo.disconnect();
      window.__secondChatKickLayoutMo = null;
    }
    if (window.__secondChatKickLayoutTimer) {
      clearTimeout(window.__secondChatKickLayoutTimer);
      window.__secondChatKickLayoutTimer = null;
    }
  } catch (e0) {}
  var kickLayoutTimer = null;
  var kickLayoutObserver = null;
  function applyKickTileLayout() {
    try {
      if (document.fullscreenElement) return;
      var root = document.documentElement;
      var b = document.body;
      if (root) {
        root.style.margin = '0';
        root.style.padding = '0';
        root.style.width = '100%';
        root.style.height = '100%';
        root.style.minHeight = '100%';
        root.style.backgroundColor = '#000';
        root.style.overflow = 'hidden';
      }
      if (b) {
        b.style.margin = '0';
        b.style.padding = '0';
        b.style.width = '100%';
        b.style.minHeight = '100%';
        b.style.height = 'auto';
        b.style.backgroundColor = '#000';
        b.style.boxSizing = 'border-box';
        // Let Kick draw player chrome above the video (was broken with overflow:hidden).
        b.style.overflow = 'visible';
        b.style.position = 'relative';
      }
      document.querySelectorAll('iframe').forEach(function (f) {
        if (document.fullscreenElement && document.fullscreenElement === f) return;
        f.style.boxSizing = 'border-box';
        f.style.width = '100%';
        f.style.height = '100%';
        f.style.minHeight = '100%';
        f.style.border = '0';
        f.style.display = 'block';
        f.style.margin = '0';
        f.style.padding = '0';
        f.style.position = 'relative';
        f.style.flex = '1 1 auto';
      });
      var v = document.querySelector('video');
      if (v) {
        if (document.fullscreenElement && document.fullscreenElement === v) return;
        v.style.maxWidth = '100%';
        v.style.maxHeight = '100%';
        v.style.width = '100%';
        v.style.height = '100%';
        v.style.objectFit = 'contain';
      }
    } catch (e) {}
  }
  function scheduleApply() {
    if (window.__secondChatKickLayoutTimer) {
      clearTimeout(window.__secondChatKickLayoutTimer);
      window.__secondChatKickLayoutTimer = null;
    }
    kickLayoutTimer = setTimeout(function () {
      kickLayoutTimer = null;
      window.__secondChatKickLayoutTimer = null;
      applyKickTileLayout();
    }, 80);
    window.__secondChatKickLayoutTimer = kickLayoutTimer;
  }
  applyKickTileLayout();
  document.addEventListener('fullscreenchange', function () {
    if (document.fullscreenElement) {
      try {
        if (kickLayoutObserver) kickLayoutObserver.disconnect();
        kickLayoutObserver = null;
        window.__secondChatKickLayoutMo = null;
      } catch (e3) {}
      if (window.__secondChatKickLayoutTimer) {
        clearTimeout(window.__secondChatKickLayoutTimer);
        window.__secondChatKickLayoutTimer = null;
      }
      return;
    }
    // Player exited fullscreen; restore tile-fit styles.
    applyKickTileLayout();
  });
  try {
    kickLayoutObserver = new MutationObserver(function () {
      scheduleApply();
    });
    window.__secondChatKickLayoutMo = kickLayoutObserver;
    kickLayoutObserver.observe(document.documentElement, {
      childList: true,
      subtree: true,
    });
    setTimeout(function () {
      try {
        if (kickLayoutObserver) kickLayoutObserver.disconnect();
        kickLayoutObserver = null;
        window.__secondChatKickLayoutMo = null;
      } catch (e2) {}
    }, 10000);
  } catch (e1) {}
})();
''');
    } catch (_) {}
  }

  /// Same intent as the embed’s own fullscreen control: [video.requestFullscreen],
  /// same-origin iframe controls, or a labeled fullscreen button.
  /// No-op when [suppressNativeFullscreen] is true or the shell is idle.
  Future<void> requestEmbedNativeFullscreenFromTap() async {
    if (!mounted || _shellIsIdle) return;
    if (widget.suppressNativeFullscreen) return;
    try {
      await _controller.runJavaScript(r'''
(function () {
  function tryFs(el) {
    if (!el) return false;
    var fn = el.requestFullscreen ||
        el.webkitRequestFullscreen ||
        el.mozRequestFullScreen ||
        el.msRequestFullscreen;
    if (!fn) return false;
    try {
      fn.call(el);
      return true;
    } catch (e) {
      return false;
    }
  }
  function labelText(el) {
    if (!el || !el.getAttribute) return '';
    return (
      (el.getAttribute('aria-label') || '') +
      ' ' +
      (el.getAttribute('title') || '') +
      ' ' +
      (el.getAttribute('data-testid') || '') +
      ' ' +
      (el.textContent || '')
    );
  }
  function clickFullscreenControlIn(root) {
    if (!root || !root.querySelectorAll) return false;
    var candidates = [];
    try {
      candidates = candidates.concat(
        Array.from(root.querySelectorAll('[data-testid*="fullscreen"]')),
      );
    } catch (e0) {}
    try {
      candidates = candidates.concat(
        Array.from(root.querySelectorAll('button,[role="button"],a[href]')),
      );
    } catch (e1) {}
    for (var i = 0; i < candidates.length; i++) {
      var el = candidates[i];
      var t = labelText(el);
      if (
        /fullscreen|full-screen|enter full screen|wide screen|widescreen/i.test(
          t,
        )
      ) {
        try {
          el.click();
          return true;
        } catch (e2) {}
      }
    }
    return false;
  }
  /** Nudge the player so controls / video exist for requestFullscreen (Kick etc.). */
  function wakePlayerSurface() {
    try {
      var w = window.innerWidth || 320;
      var h = window.innerHeight || 180;
      var cx = Math.max(4, Math.floor(w / 2));
      var cy = Math.max(4, Math.floor(h / 2));
      var target = document.elementFromPoint(cx, cy);
      if (target && target !== document.documentElement) {
        ['pointerdown', 'pointerup', 'click'].forEach(function (t) {
          try {
            var e = new MouseEvent(t, {
              bubbles: true,
              cancelable: true,
              clientX: cx,
              clientY: cy,
              view: window,
            });
            target.dispatchEvent(e);
          } catch (x) {}
        });
      }
      var v0 = document.querySelector('video');
      if (v0) {
        try {
          v0.click();
        } catch (x) {}
        try {
          if (v0.play) v0.play();
        } catch (x) {}
      }
    } catch (e) {}
  }

  wakePlayerSurface();
  var v = document.querySelector('video');
  if (tryFs(v)) return;
  var ifr = document.querySelector('iframe');
  if (ifr) {
    try {
      var doc =
        ifr.contentDocument ||
        (ifr.contentWindow && ifr.contentWindow.document);
      if (doc) {
        var iv = doc.querySelector('video');
        if (tryFs(iv)) return;
        if (clickFullscreenControlIn(doc)) return;
      }
    } catch (e) {}
  }
  if (clickFullscreenControlIn(document)) return;
})();
''');
    } catch (_) {}
  }

  void _ensureNavigationDelegate() {
    if (_delegateAttached) return;
    _delegateAttached = true;
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          if (kDebugMode) {
            debugPrint(
              '[StreamWebView] page_started '
              'platform=$_normalizedPlatformKey url=$url',
            );
          }
        },
        onPageFinished: (url) {
          if (kDebugMode) {
            debugPrint(
              '[StreamWebView] page_finished '
              'platform=$_normalizedPlatformKey url=$url',
            );
          }
          _applyMuteState();
          unawaited(_suppressEmbeddedFullscreenChrome());
          unawaited(_injectKickEmbedContainmentLayout());
          if (_normalizedPlatformKey == 'kick' &&
              !widget.suppressNativeFullscreen &&
              !_shellIsIdle) {
            unawaited(
              Future<void>.delayed(const Duration(milliseconds: 350), () async {
                if (!mounted) return;
                await _injectKickEmbedContainmentLayout();
              }),
            );
            unawaited(
              Future<void>.delayed(
                const Duration(milliseconds: 1100),
                () async {
                  if (!mounted) return;
                  await _injectKickEmbedContainmentLayout();
                },
              ),
            );
          }
          _maybeReportStreamReady();
        },
        onWebResourceError: _logWebResourceError,
        onHttpError: (error) {
          if (!kDebugMode) return;
          debugPrint(
            '[StreamWebView] http_error '
            'platform=$_normalizedPlatformKey error=$error '
            'initial=${_initialUrl ?? '(none)'}',
          );
        },
        onNavigationRequest: (req) {
          // Keep iframe/media/control navigations untouched.
          // Blocking subframe requests can freeze some embeds (Kick play/pause path).
          if (!req.isMainFrame) return NavigationDecision.navigate;
          final allowed = _isAllowedMainFrameNavigation(req.url);
          return allowed
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ),
    );
  }

  void _logWebNavError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('[StreamWebView] navigation failed: $error');
    }
  }

  void _logWebResourceError(WebResourceError error) {
    if (!kDebugMode) return;
    String failingUrl = '(not_exposed_by_plugin_version)';
    try {
      final dynamic e = error;
      final dynamic url = e.failingUrl;
      if (url != null && url.toString().trim().isNotEmpty) {
        failingUrl = url.toString().trim();
      }
    } catch (_) {}
    debugPrint(
      '[StreamWebView] web_resource_error '
      'platform=$_normalizedPlatformKey '
      'code=${error.errorCode} type=${error.errorType} '
      'url=$failingUrl '
      'desc=${error.description} '
      'initial=${_initialUrl ?? '(none)'}',
    );
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
        // Same logical stream, but URL may still need a hard reload
        // (example: Twitch parent param repaired from localhost).
        if (_lastCommittedNavigation != sanitized) {
          _lastCommittedNavigation = sanitized;
          _initialUrl = sanitized;
          _initialUri = Uri.tryParse(sanitized);
          final uri = Uri.tryParse(sanitized);
          final host = uri?.host.toLowerCase() ?? '';
          final isYoutubeEmbed =
              uri != null &&
              (host.contains('youtube.com') ||
                  host.contains('youtube-nocookie.com')) &&
              uri.path.toLowerCase().contains('/embed/');
          if (isYoutubeEmbed) {
            final origin = 'https://$_packageNameForYoutubeHeaders';
            _controller
                .loadRequest(
                  uri,
                  headers: <String, String>{
                    'Referer': origin,
                    'Origin': origin,
                  },
                )
                .catchError(_logWebNavError);
          } else {
            _controller
                .loadRequest(Uri.parse(sanitized))
                .catchError(_logWebNavError);
          }
          _persistSnapshot();
        }
        _applyMuteState();
        return;
      }
      _lastCommittedNavigation = sanitized;
      _lastCanonicalEmbedId = nextId;
      _initialUrl = sanitized;
      _initialUri = Uri.tryParse(sanitized);
      final uri = Uri.tryParse(sanitized);
      final host = uri?.host.toLowerCase() ?? '';
      final isYoutubeEmbed =
          uri != null &&
          (host.contains('youtube.com') || host.contains('youtube-nocookie.com')) &&
          uri.path.toLowerCase().contains('/embed/');
      if (isYoutubeEmbed) {
        final origin = 'https://$_packageNameForYoutubeHeaders';
        _controller
            .loadRequest(
              uri,
              headers: <String, String>{
                'Referer': origin,
                'Origin': origin,
              },
            )
            .catchError(_logWebNavError);
      } else {
        _controller.loadRequest(Uri.parse(sanitized)).catchError(_logWebNavError);
      }
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
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'about' ||
        scheme == 'data' ||
        scheme == 'blob' ||
        scheme == 'javascript') {
      return true;
    }
    if (scheme != 'http' && scheme != 'https') return false;

    // First load from idle shell → real embed.
    if (initUri.host == 'secondchat.idle' &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return true;
    }

    final host = uri.host.toLowerCase();
    bool hostMatchesAny(List<String> suffixes) {
      for (final s in suffixes) {
        if (host == s || host.endsWith('.$s')) return true;
      }
      return false;
    }

    final key = _normalizedPlatformKey;
    if (key == 'kick') {
      return hostMatchesAny(const <String>[
        'kick.com',
        'player.kick.com',
        'amazonaws.com',
        'cloudfront.net',
      ]);
    }
    if (key == 'twitch') {
      return hostMatchesAny(const <String>[
        'twitch.tv',
        'player.twitch.tv',
        'twitchcdn.net',
        'jtvnw.net',
        'twitch.amazon.com',
      ]);
    }
    if (key == 'youtube') {
      return hostMatchesAny(const <String>[
        'youtube.com',
        'youtube-nocookie.com',
        'google.com',
        'googlevideo.com',
        'googleapis.com',
        'gstatic.com',
      ]);
    }

    return host == initUri.host.toLowerCase();
  }

  @override
  void didUpdateWidget(StreamWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) {
      if (_shouldReuseControllerCacheForKey(oldWidget.cacheKey)) {
        _controllerCache[oldWidget.cacheKey] = _StreamWebViewControllerSnapshot(
          controller: _controller,
          initialUrl: _initialUrl,
          initialUri: _initialUri,
          lastCommittedNavigation: _lastCommittedNavigation,
          lastCanonicalEmbedId: _lastCanonicalEmbedId,
        );
        _trimControllerCache(keepKey: oldWidget.cacheKey);
      } else {
        _controllerCache.remove(oldWidget.cacheKey);
      }
      final cached = _controllerCache[widget.cacheKey];
      if (_shouldReuseControllerCache && cached != null) {
        _hydrateFromSnapshot(cached);
      } else {
        _controllerCache.remove(widget.cacheKey);
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
      // Stream can restart with the same embed URL. Reset ready dedupe and
      // re-emit readiness when live flips true so chat gate can reopen.
      _lastStreamReadyReportedId = '';
      if (widget.streamExpectedLive) {
        // Force a real reload on live restart even when URL string is unchanged.
        // Some providers (notably Twitch) keep showing stale "offline" state unless
        // the embed document is re-requested.
        _lastCanonicalEmbedId = '';
        _lastCommittedNavigation = null;
        if (widget.url.trim().isNotEmpty) {
          _loadUrlIntoController(widget.url);
        }
      }
    }
    if (oldWidget.muted != widget.muted) {
      _applyMuteState();
    }
    if (oldWidget.suppressNativeFullscreen != widget.suppressNativeFullscreen) {
      unawaited(_suppressEmbeddedFullscreenChrome());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers =
        widget.useEagerGestureArena
            ? <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            }
            : const <Factory<OneSequenceGestureRecognizer>>{};
    final Widget frame = Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(
          controller: _controller,
          gestureRecognizers: gestureRecognizers,
        ),
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
                  Icon(Icons.videocam_off, color: Colors.white38, size: 28.sp),
                  SizedBox(height: 5.h),
                  Text(
                    l10n.noStreamAtTheMoment,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, height: widget.height, child: frame);
    }
    return SizedBox(height: widget.height, child: frame);
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
