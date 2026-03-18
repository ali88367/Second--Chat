import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_api.dart';
import '../api/auth/auth_api.dart';
import '../api/auth/models/session_tokens.dart';
import '../api/auth/oauth_api.dart';
import '../api/auth/oauth_flow.dart';
import '../api/auth/oauth_provider.dart';
import '../api/http/api_json.dart';
import '../core/constants/app_colors/app_colors.dart';
import '../core/localization/get_l10n.dart';

class AuthController extends GetxController with WidgetsBindingObserver {
  AuthController({
    AppApi? api,
    OAuthFlow? oauthFlow,
  })  : _api = api ?? AppApi.create(),
        _oauthFlow = oauthFlow ?? OAuthFlow();

  final AppApi _api;
  final OAuthFlow _oauthFlow;

  AppApi get api => _api;

  final RxBool isReady = false.obs;
  final RxBool isAuthenticated = false.obs;
  final Rxn<Map<String, dynamic>> me = Rxn<Map<String, dynamic>>();
  final RxnString lastError = RxnString();

  AuthApi get authApi => _api.auth;
  OAuthApi get oauthApi => _api.oauth;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _oauthFlow.init();

    final tokens = await _api.tokenStore.read();
    isAuthenticated.value = tokens != null;

    if (tokens != null) {
      await refreshMe(silent: true);
    }

    isReady.value = true;
  }

  Future<void> refreshMe({bool silent = false}) async {
    try {
      final profile = await authApi.me();
      me.value = profile;
      isAuthenticated.value = true;
    } catch (e) {
      lastError.value = 'Failed to load profile: $e';
      if (kDebugMode) debugPrint('API ERROR(me): $e');
      if (e is DioException && e.response?.statusCode == 401) {
        await _api.tokenStore.clear();
        isAuthenticated.value = false;
        me.value = null;
      }
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final tokens = await authApi.login(email: email, password: password);
      await _api.tokenStore.write(tokens);
      isAuthenticated.value = true;
      lastError.value = null;
      await refreshMe(silent: true);
    } catch (e) {
      lastError.value = 'Login failed: $e';
      if (kDebugMode) debugPrint('API ERROR(login): $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await authApi.logout();
    } catch (_) {}
    await _api.tokenStore.clear();
    isAuthenticated.value = false;
    me.value = null;
    lastError.value = null;
  }

  Future<bool> connectProvider(OAuthProvider provider) async {
    try {
      final hasTokens = (await _api.tokenStore.read()) != null;
      if (!hasTokens) {
        isAuthenticated.value = false;
        me.value = null;
      }
      final authUrl = await oauthApi.getAuthUrl(
        provider: provider,
        link: hasTokens,
      );

      final callbackUri = await _oauthFlow.begin(
        provider: provider,
        authorizationUrl: authUrl,
      );
      if (kDebugMode) {
        debugPrint('OAUTH CALLBACK URI: $callbackUri');
        debugPrint('OAUTH CALLBACK params: ${_extractParams(callbackUri)}');
      }
      final parsed = _oauthFlow.parseCallback(callbackUri);
      if (!parsed.isSuccess) {
        final err = parsed.error ?? 'unknown error';
        lastError.value = 'OAuth failed: $err';
        if (kDebugMode) {
          debugPrint('OAUTH ERROR(${provider.name}): $err');
          debugPrint('OAUTH PARAMS(${provider.name}): ${parsed.rawParams ?? {}}');
        }
        _showOauthError(
          'Login failed. Please try again.',
          error: err,
        );
        return false;
      }

      // Link-only completion: backend may redirect back with `success=true&linked=...`
      // without returning tokens or an auth code.
      if (parsed.linkedPlatform != null && parsed.linkedPlatform!.isNotEmpty) {
        lastError.value = null;
        if (kDebugMode) {
          debugPrint(
            'OAUTH LINK OK(${provider.name}): linked=${parsed.linkedPlatform}',
          );
        }
        await refreshMe(silent: true);
        return true;
      }

      // Some backends complete the OAuth flow server-side and redirect back with app tokens.
      if (parsed.accessToken != null &&
          parsed.accessToken!.isNotEmpty &&
          parsed.refreshToken != null &&
          parsed.refreshToken!.isNotEmpty) {
        await _api.tokenStore.write(
          SessionTokens(
            accessToken: parsed.accessToken!,
            refreshToken: parsed.refreshToken!,
          ),
        );
        isAuthenticated.value = true;
        await _saveTokensToPrefs(
          provider: provider,
          accessToken: parsed.accessToken!,
          refreshToken: parsed.refreshToken!,
        );
      } else {
        final result = await oauthApi.exchangeCallback(
          provider: parsed.provider!,
          code: parsed.code!,
          state: parsed.state,
        );

        final tokens = _tryParseTokens(result);
        if (tokens != null) {
          await _api.tokenStore.write(tokens);
          isAuthenticated.value = true;
          await _saveTokensToPrefs(
            provider: provider,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
          );
        }
      }

      await refreshMe(silent: true);
      lastError.value = null;
      if (kDebugMode) debugPrint('OAUTH OK(${provider.name})');
      return true;
    } on TimeoutException {
      lastError.value = 'Timed out waiting for OAuth callback';
      if (kDebugMode) debugPrint('OAUTH TIMEOUT(${provider.name})');
      final l10n = getAppL10n();
      _showOauthError(
        l10n?.loginTimedOutPleaseTryAgain ??
            'Login timed out. Please try again.',
        error: 'Timeout',
      );
      return false;
    } catch (e) {
      if (e is StateError && e.message == 'OAuth flow cancelled') {
        lastError.value = 'OAuth flow cancelled';
        final l10n = getAppL10n();
        _showOauthError(
          l10n?.authenticationCancelled ?? 'Authentication cancelled.',
          title: l10n?.cancel ?? 'Cancel',
          error: e,
        );
        return false;
      }
      lastError.value = 'Failed to connect ${provider.name}: $e';
      if (kDebugMode) debugPrint('OAUTH ERROR(${provider.name}): $e');
      if (!(e is StateError &&
          e.message == 'Failed to open OAuth browser view')) {
        final l10n = getAppL10n();
        _showOauthError(
          l10n?.couldntConnectPleaseTryAgain ??
              'We couldn\'t connect. Please try again.',
          error: e,
        );
      }
      return false;
    }
  }

  void _showOauthError(String message, {Object? error, String? title}) {
    if (error != null) {
      debugPrint('OAUTH UI ERROR: $error');
    }
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    final l10n = getAppL10n();
    Get.snackbar(
      title ?? (l10n?.connectionIssue ?? 'Connection issue'),
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: blackbox.withOpacity(0.9),
      colorText: onDark,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 14,
    );
  }

  static const _kPrefsAccessToken = 'second_chat.access_token';
  static const _kPrefsRefreshToken = 'second_chat.refresh_token';
  static const _kPrefsPlatformTokens = 'second_chat.platform_tokens';

  Map<String, String> _extractParams(Uri uri) {
    final params = <String, String>{...uri.queryParameters};
    final frag = uri.fragment;
    if (frag.isNotEmpty) {
      try {
        params.addAll(Uri.splitQueryString(frag));
      } catch (_) {}
    }
    return params;
  }

  Future<void> _saveTokensToPrefs({
    required OAuthProvider provider,
    required String accessToken,
    required String refreshToken,
  }) async {
    debugPrint('OAUTH TOKENS(${provider.name}): accessToken=$accessToken');
    debugPrint('OAUTH TOKENS(${provider.name}): refreshToken=$refreshToken');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsAccessToken, accessToken);
    await prefs.setString(_kPrefsRefreshToken, refreshToken);

    final raw = prefs.getString(_kPrefsPlatformTokens);
    Map<String, dynamic> map;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        map = decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map);
      } catch (_) {
        map = <String, dynamic>{};
      }
    } else {
      map = <String, dynamic>{};
    }

    map[provider.name] = {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
    await prefs.setString(_kPrefsPlatformTokens, jsonEncode(map));

    debugPrint(
      'OAUTH TOKENS STORED(${provider.name}) prefs=$_kPrefsPlatformTokens map=$map',
    );
  }

  SessionTokens? _tryParseTokens(dynamic json) {
    final accessToken = extractString(json, const [
      'accessToken',
      'access_token',
      'token',
    ]);
    final refreshToken =
        extractString(json, const ['refreshToken', 'refresh_token']);

    if (accessToken == null || accessToken.isEmpty) return null;
    if (refreshToken == null || refreshToken.isEmpty) return null;

    return SessionTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _oauthFlow.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _oauthFlow.handleAppResumed();
    }
  }
}






