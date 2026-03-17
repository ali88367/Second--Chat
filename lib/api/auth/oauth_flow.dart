import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:get/get.dart';

import '../config/api_config.dart';
import '../../core/localization/get_l10n.dart';
import 'oauth_provider.dart';

class OAuthFlow {
  OAuthFlow({
    AppLinks? appLinks,
  }) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  StreamSubscription<Uri>? _sub;
  Completer<Uri>? _pendingCompleter;

  OAuthProvider? _pendingProvider;
  String? _pendingState;

  static final Uri _redirectUri = Uri.parse(ApiConfig.oauthRedirectUri);

  Future<void> _tryDismissBrowser() async {
    // On iOS, the OAuth redirect can successfully open the app but leave SafariVC visible.
    // Closing here makes the flow feel like a real "redirect back" like Android.
    try {
      await closeCustomTabs();
    } catch (_) {
      // ignore
    }
  }

  Map<String, String> _allParams(Uri uri) {
    final params = <String, String>{...uri.queryParameters};
    final frag = uri.fragment;
    if (frag.isNotEmpty) {
      // Providers may return values in fragment: "#code=...&state=..."
      final fragParams = Uri.splitQueryString(frag);
      params.addAll(fragParams);
    }
    return params;
  }

  void _logRedirect(String tag, Uri uri) {
    if (!kDebugMode) return;
    debugPrint('OAUTH REDIRECT [$tag]: $uri');
    debugPrint('OAUTH REDIRECT [$tag] params: ${_allParams(uri)}');
  }

  bool _isLikelyOAuthResult(Uri uri) {
    final p = _allParams(uri);
    return p.containsKey('code') ||
        p.containsKey('error') ||
        p.containsKey('token') ||
        p.containsKey('accessToken') ||
        p.containsKey('refreshToken') ||
        p.containsKey('access_token') ||
        p.containsKey('refresh_token') ||
        // Link flows can return only a success marker.
        p.containsKey('success') ||
        p.containsKey('linked');
  }

  Future<void> init() async {
    _sub ??= _appLinks.uriLinkStream.listen((uri) {
      if (_pendingCompleter == null || _pendingCompleter!.isCompleted) return;
      if (!_isExpectedRedirect(uri)) return;
      _logRedirect('stream', uri);
      if (!_isLikelyOAuthResult(uri)) {
        if (kDebugMode) debugPrint('OAUTH REDIRECT (ignored): $uri');
        return;
      }
      if (kDebugMode) debugPrint('OAUTH REDIRECT: $uri');
      // Dismiss SafariVC/CustomTabs ASAP once we have the callback.
      unawaited(_tryDismissBrowser());
      _pendingCompleter!.complete(uri);
    });

    try {
      final dynamic al = _appLinks;
      Uri? initial;
      try {
        final v = await al.getInitialAppLink();
        if (v is Uri) initial = v;
      } catch (_) {}
      try {
        final v = await al.getInitialLink();
        if (v is String && v.isNotEmpty) initial ??= Uri.tryParse(v);
      } catch (_) {}

      if (initial != null &&
          _pendingCompleter != null &&
          !_pendingCompleter!.isCompleted &&
          _isExpectedRedirect(initial)) {
        _logRedirect('initial', initial);
        unawaited(_tryDismissBrowser());
        _pendingCompleter!.complete(initial);
      }
    } catch (_) {
      // Ignore: getInitialAppLink can throw on some platforms if not supported.
    }
  }

  Future<Uri> begin({
    required OAuthProvider provider,
    required Uri authorizationUrl,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    await init();

    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      throw StateError('OAuth flow already in progress');
    }

    _pendingProvider = provider;
    _pendingState = authorizationUrl.queryParameters['state'];

    _pendingCompleter = Completer<Uri>();

    try {
      await _launchCustomTab(authorizationUrl);
    } catch (_) {
      _resetPending();
      throw StateError('Failed to open OAuth browser view');
    }

    try {
      return await _pendingCompleter!.future.timeout(timeout);
    } on TimeoutException {
      _resetPending();
      rethrow;
    } catch (_) {
      _resetPending();
      rethrow;
    }
  }

  Future<void> _launchCustomTab(Uri authorizationUrl) async {
    try {
      await launchUrl(
        authorizationUrl,
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: Color(0xFF1E1D20),
          ),
          urlBarHidingEnabled: true,
          showTitle: false,
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: Color(0xFF1E1D20),
          preferredControlTintColor: Colors.white,
          barCollapsingEnabled: true,
          dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        ),
      );
    } catch (e) {
      _showLaunchError(e);
      rethrow;
    }
  }

  void _showLaunchError(Object error) {
    debugPrint('OAUTH CUSTOM TABS ERROR: $error');
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    final l10n = getAppL10n();
    Get.snackbar(
      l10n?.connectionIssue ?? 'Connection issue',
      l10n?.couldntOpenLoginPagePleaseTryAgain ??
          'We couldn\'t open the login page. Please try again.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF232225),
      colorText: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 14,
    );
  }

  OAuthCallback parseCallback(Uri callbackUri) {
    if (!_isExpectedRedirect(callbackUri)) {
      throw StateError('Unexpected redirect URI: $callbackUri');
    }

    _logRedirect('parse', callbackUri);
    final params = _allParams(callbackUri);

    final error = params['error'];
    if (error != null && error.isNotEmpty) {
      _resetPending();
      return OAuthCallback(error: error);
    }

    final state = params['state'];
    if (_pendingState != null && state != null && state != _pendingState) {
      _resetPending();
      return OAuthCallback(error: 'State mismatch', rawParams: params);
    }

    final successRaw = params['success']?.toLowerCase();
    final isSuccess = successRaw == 'true' || successRaw == '1' || successRaw == 'yes';
    final linkedPlatform = params['linked'];
    if (isSuccess && (linkedPlatform != null && linkedPlatform.isNotEmpty)) {
      final provider = _pendingProvider;
      _resetPending();
      if (provider == null) {
        return OAuthCallback(
          error: 'Missing pending provider',
          rawParams: params,
        );
      }
      return OAuthCallback(
        provider: provider,
        state: state,
        linkedPlatform: linkedPlatform,
        rawParams: params,
      );
    }

    final accessToken =
        params['token'] ?? params['accessToken'] ?? params['access_token'];
    final refreshToken = params['refreshToken'] ?? params['refresh_token'];

    if (accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty) {
      final provider = _pendingProvider;
      _resetPending();
      if (provider == null) {
        return OAuthCallback(
          error: 'Missing pending provider',
          rawParams: params,
        );
      }
      return OAuthCallback(
        provider: provider,
        accessToken: accessToken,
        refreshToken: refreshToken,
        state: state,
        rawParams: params,
      );
    }

    final code = params['code'];
    if (code == null || code.isEmpty) {
      _resetPending();
      return OAuthCallback(
        error: 'Missing authorization code',
        rawParams: params,
      );
    }

    final provider = _pendingProvider;
    _resetPending();

    if (provider == null) return OAuthCallback(error: 'Missing pending provider');
    return OAuthCallback(
      provider: provider,
      code: code,
      state: state,
      rawParams: params,
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _resetPending();
  }

  bool _isExpectedRedirect(Uri uri) {
    // Accept scheme/host match; path can vary a bit depending on platform and backend.
    return uri.scheme == _redirectUri.scheme &&
        uri.host == _redirectUri.host &&
        (uri.path == _redirectUri.path || uri.path.endsWith(_redirectUri.path));
  }

  void _resetPending() {
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.completeError(StateError('OAuth flow cancelled'));
    }
    _pendingCompleter = null;
    _pendingProvider = null;
    _pendingState = null;
  }
}

class OAuthCallback {
  OAuthCallback({
    this.provider,
    this.code,
    this.state,
    this.error,
    this.accessToken,
    this.refreshToken,
    this.linkedPlatform,
    this.rawParams,
  });

  final OAuthProvider? provider;
  final String? code;
  final String? state;
  final String? error;
  final String? accessToken;
  final String? refreshToken;
  final String? linkedPlatform;
  final Map<String, String>? rawParams;

  bool get isSuccess => error == null;
}
