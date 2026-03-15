import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/app_api.dart';
import '../api/auth/auth_api.dart';
import '../api/auth/models/session_tokens.dart';
import '../api/auth/oauth_api.dart';
import '../api/auth/oauth_flow.dart';
import '../api/auth/oauth_provider.dart';
import '../api/http/api_json.dart';

class AuthController extends GetxController {
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
      final authUrl = await oauthApi.getAuthUrl(
        provider: provider,
        link: isAuthenticated.value,
      );

      final callbackUri = await _oauthFlow.begin(
        provider: provider,
        authorizationUrl: authUrl,
      );
      // Ensure the in-app browser sheet is dismissed (best-effort).
      unawaited(closeInAppWebView());

      final parsed = _oauthFlow.parseCallback(callbackUri);
      if (!parsed.isSuccess) {
        lastError.value = 'OAuth failed: ${parsed.error ?? 'unknown error'}';
        if (kDebugMode) {
          debugPrint('OAUTH ERROR(${provider.name}): ${parsed.error}');
          debugPrint('OAUTH PARAMS(${provider.name}): ${parsed.rawParams ?? {}}');
        }
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
        }
      }

      await refreshMe(silent: true);
      lastError.value = null;
      if (kDebugMode) debugPrint('OAUTH OK(${provider.name})');
      return true;
    } on TimeoutException {
      lastError.value = 'Timed out waiting for OAuth callback';
      if (kDebugMode) debugPrint('OAUTH TIMEOUT(${provider.name})');
      return false;
    } catch (e) {
      lastError.value = 'Failed to connect ${provider.name}: $e';
      if (kDebugMode) debugPrint('OAUTH ERROR(${provider.name}): $e');
      return false;
    }
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
    _oauthFlow.dispose();
    super.onClose();
  }
}
