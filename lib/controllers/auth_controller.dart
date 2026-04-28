import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_api.dart';
import '../api/auth/auth_api.dart';
import '../api/auth/google_sign_in_service.dart';
import '../api/auth/jwt_utils.dart';
import '../api/auth/models/google_sign_in_credentials.dart';
import '../api/auth/models/session_tokens.dart';
import '../api/auth/oauth_api.dart';
import '../api/auth/oauth_flow.dart';
import '../api/auth/oauth_provider.dart';
import '../api/http/api_json.dart';
import '../core/constants/app_colors/app_colors.dart';
import '../core/constants/constants.dart';
import '../core/localization/get_l10n.dart';
import '../core/utils/platform_token_provider.dart';

class AuthController extends GetxController with WidgetsBindingObserver {
  AuthController({AppApi? api, OAuthFlow? oauthFlow})
    : _api = api ?? AppApi.create(),
      _oauthFlow = oauthFlow ?? OAuthFlow();

  final AppApi _api;
  final OAuthFlow _oauthFlow;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AppApi get api => _api;

  final RxBool isReady = false.obs;
  final RxBool isAuthenticated = false.obs;
  final Rxn<Map<String, dynamic>> me = Rxn<Map<String, dynamic>>();
  final RxnString lastError = RxnString();

  static const String _kIntroDoneUsers = 'second_chat.intro_done_users';
  static const String _kLastRegisteredPushToken =
      'second_chat.push_token.last_registered';

  AuthApi get authApi => _api.auth;
  OAuthApi get oauthApi => _api.oauth;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _oauthFlow.init();

      final hasSession = await ensureValidSession(
        refreshIfExpired: true,
        failOnRefreshError: true,
      );
      if (hasSession) {
        await refreshMe(silent: true, clearSessionOnFailure: true);
        if (isAuthenticated.value) {
          unawaited(_registerPushTokenAfterAuth('bootstrap'));
        }
      }
      await _migrateIntroOnboardingFlagIfNeeded();
    } catch (e) {
      if (kDebugMode) debugPrint('AUTH BOOTSTRAP ERROR: $e');
      await _api.tokenStore.clear();
      isAuthenticated.value = false;
      me.value = null;
    } finally {
      isReady.value = true;
    }
  }

  /// Sessions created before intro onboarding existed: skip the notification → intro flow.
  Future<void> _migrateIntroOnboardingFlagIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(AppConstants.keyIntroOnboardingComplete)) return;
    final tokens = await _api.tokenStore.read();
    if (tokens != null) {
      await prefs.setBool(AppConstants.keyIntroOnboardingComplete, true);
      try {
        await rememberIntroOnboardingCompletedForCurrentUser();
      } catch (_) {}
    }
  }

  Future<void> _setIntroOnboardingComplete(bool isComplete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIntroOnboardingComplete, isComplete);
  }

  Future<void> _syncIntroOnboardingFlagAfterLogin() async {
    final rememberedForUser =
        await _isIntroOnboardingRememberedForCurrentUser();
    // Do not use server premium/trial state here: that skips the notification
    // intro entirely. Trial branching uses [shouldSkipFreeTrialIntro] after
    // the notification step instead.
    final shouldSkip = rememberedForUser;

    await _setIntroOnboardingComplete(shouldSkip);
    if (shouldSkip) {
      await rememberIntroOnboardingCompletedForCurrentUser();
    }
    if (kDebugMode) {
      debugPrint(
        'INTRO ONBOARDING FLAG AFTER LOGIN: '
        '${shouldSkip ? 'complete (device remembered)' : 'pending (show notification intro)'}',
      );
    }
  }

  /// Server / profile snapshot: skip the free-trial UI (Intro 3) only.
  Future<bool> shouldSkipFreeTrialIntro() async {
    return _shouldSkipIntroOnboardingFromServerState();
  }

  Future<bool> isIntroOnboardingPreferenceComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIntroOnboardingComplete) ?? false;
  }

  Future<bool> _shouldSkipIntroOnboardingFromServerState() async {
    if (me.value == null || me.value!.isEmpty) {
      try {
        await refreshMe(silent: true);
      } catch (_) {}
    }

    if (_looksPremiumLike(me.value) || _looksTrialPreviouslyUsed(me.value)) {
      return true;
    }

    try {
      final res = await _api.client.dio.get<dynamic>('/api/v1/settings');
      final root = _toMap(res.data);
      final data = _toMap(root?['data']) ?? root;
      final account = _toMap(data?['account']);

      if (_looksPremiumLike(data) ||
          _looksPremiumLike(account) ||
          _looksTrialPreviouslyUsed(data) ||
          _looksTrialPreviouslyUsed(account)) {
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('INTRO ONBOARDING CHECK (/api/v1/settings) failed: $e');
      }
    }

    return false;
  }

  bool _looksPremiumLike(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return false;

    const premiumBoolKeys = <String>[
      'isPremium',
      'is_premium',
      'premium',
      'hasPremium',
      'has_premium',
      'isSubscribed',
      'is_subscribed',
      'isPaid',
      'is_paid',
    ];
    for (final key in premiumBoolKeys) {
      final parsed = _toBool(map[key]);
      if (parsed == true) return true;
    }

    const planKeys = <String>[
      'yourPlan',
      'plan',
      'planType',
      'plan_type',
      'subscriptionPlan',
      'subscription_plan',
      'accountType',
      'account_type',
    ];
    for (final key in planKeys) {
      final plan = _normalizeText(map[key]);
      if (plan.isEmpty) continue;
      if (plan.contains('premium') ||
          plan.contains('pro') ||
          plan.contains('plus') ||
          plan.contains('paid')) {
        return true;
      }
    }

    const subscriptionStatusKeys = <String>[
      'subscriptionStatus',
      'subscription_status',
      'billingStatus',
      'billing_status',
      'membershipStatus',
      'membership_status',
    ];
    for (final key in subscriptionStatusKeys) {
      final status = _normalizeText(map[key]);
      if (_isPaidLikeStatus(status)) return true;
    }

    return false;
  }

  bool _looksTrialPreviouslyUsed(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return false;

    var found = false;
    _walkJsonEntries(map, (key, value) {
      if (found) return;
      final normalizedKey = _normalizeKey(key);

      if (_trialUsedBoolKeys.contains(normalizedKey)) {
        if (_toBool(value) == true) {
          found = true;
        }
        return;
      }

      if (_trialEligibilityBoolKeys.contains(normalizedKey)) {
        final eligible = _toBool(value);
        if (eligible == false) {
          found = true;
        }
        return;
      }

      if (_trialStatusKeys.contains(normalizedKey)) {
        if (_trialStatusIndicatesUsed(_normalizeText(value))) {
          found = true;
        }
        return;
      }

      if (_trialDateKeys.contains(normalizedKey)) {
        if (_toDateTime(value) != null) {
          found = true;
        }
        return;
      }

      if (_trialNumericKeys.contains(normalizedKey)) {
        final count = _toNum(value);
        if (count != null && count >= 0) {
          found = true;
        }
      }
    });

    return found;
  }

  static const Set<String> _trialUsedBoolKeys = <String>{
    'trialused',
    'istrialused',
    'hasusedtrial',
    'usedtrial',
    'trialconsumed',
    'istrialconsumed',
    'hadtrial',
    'hashadtrial',
    'freetrialused',
    'hasclaimedtrial',
    'trialclaimed',
  };

  static const Set<String> _trialEligibilityBoolKeys = <String>{
    'iseligiblefortrial',
    'eligiblefortrial',
    'canstarttrial',
    'canclaimtrial',
    'istrialavailable',
    'trialavailable',
    'trialeligible',
    'hasfreetrialavailable',
  };

  static const Set<String> _trialStatusKeys = <String>{
    'trialstatus',
    'freetrialstatus',
    'subscriptiontrialstatus',
    'trialstate',
  };

  static const Set<String> _trialDateKeys = <String>{
    'trialstart',
    'trialstartedat',
    'trialstartdate',
    'trialend',
    'trialendedat',
    'trialenddate',
    'trialexpiresat',
    'trialexpirydate',
    'freetrialstart',
    'freetrialend',
  };

  static const Set<String> _trialNumericKeys = <String>{
    'trialdaysused',
    'trialdaysremaining',
    'freetrialdaysused',
    'freetrialdaysremaining',
  };

  bool _trialStatusIndicatesUsed(String status) {
    if (status.isEmpty) return false;

    const eligibleStates = <String>{
      'eligible',
      'notstarted',
      'never',
      'new',
      'none',
      'available',
    };
    if (eligibleStates.contains(status)) return false;

    return status.contains('active') ||
        status.contains('started') ||
        status.contains('expired') ||
        status.contains('ended') ||
        status.contains('used') ||
        status.contains('consumed') ||
        status.contains('converted') ||
        status.contains('cancel');
  }

  bool _isPaidLikeStatus(String status) {
    if (status.isEmpty) return false;
    return status.contains('active') ||
        status.contains('paid') ||
        status.contains('subscribed') ||
        status.contains('premium') ||
        status.contains('trialing') ||
        status.contains('trialactive') ||
        status.contains('intrial');
  }

  bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return null;
  }

  num? _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return null;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString().trim());
  }

  String _normalizeText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
  }

  String _normalizeKey(String key) {
    return key
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .replaceAll('_', '');
  }

  void _walkJsonEntries(
    dynamic node,
    void Function(String key, dynamic value) visit,
  ) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        visit(key, value);
        _walkJsonEntries(value, visit);
      }
      return;
    }
    if (node is List) {
      for (final item in node) {
        _walkJsonEntries(item, visit);
      }
    }
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _currentUserIdentity() {
    final profile = me.value;
    if (profile == null) return null;
    const identityKeys = <String>[
      'id',
      'user_id',
      'userId',
      'email',
      'google_id',
      'googleId',
      'sub',
    ];
    for (final key in identityKeys) {
      final raw = profile[key];
      if (raw == null) continue;
      final normalized = raw.toString().trim().toLowerCase();
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  Future<Set<String>> _readRememberedIntroUsers() async {
    try {
      final raw = await _secureStorage.read(key: _kIntroDoneUsers);
      if (raw == null || raw.trim().isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  Future<void> _writeRememberedIntroUsers(Set<String> users) async {
    final payload = jsonEncode(users.toList()..sort());
    await _secureStorage.write(key: _kIntroDoneUsers, value: payload);
  }

  Future<bool> _isIntroOnboardingRememberedForCurrentUser() async {
    final id = _currentUserIdentity();
    if (id == null) return false;
    final users = await _readRememberedIntroUsers();
    return users.contains(id);
  }

  Future<void> rememberIntroOnboardingCompletedForCurrentUser() async {
    final id = _currentUserIdentity();
    if (id == null) return;
    final users = await _readRememberedIntroUsers();
    if (users.add(id)) {
      await _writeRememberedIntroUsers(users);
    }
  }

  static const Duration _tokenExpiryLeeway = Duration(seconds: 30);

  bool _isTokenExpired(SessionTokens tokens) {
    final expiresAt = tokens.accessTokenExpiresAt;
    if (expiresAt == null) return false;
    final now = DateTime.now().toUtc();
    return expiresAt.toUtc().isBefore(now.add(_tokenExpiryLeeway));
  }

  /// True when the access token expires within [within] (proactive refresh).
  bool _isTokenExpiredWithin(SessionTokens tokens, Duration within) {
    final expiresAt = tokens.accessTokenExpiresAt;
    if (expiresAt == null) return false;
    final now = DateTime.now().toUtc();
    return expiresAt.toUtc().isBefore(now.add(within));
  }

  Future<void> _persistRefreshedSession(SessionTokens refreshed) async {
    var r = refreshed;
    if (r.accessTokenExpiresAt == null && r.accessToken.isNotEmpty) {
      final exp = parseJwtAccessTokenExpiryUtc(r.accessToken);
      if (exp != null) {
        r = r.copyWith(accessTokenExpiresAt: exp);
      }
    }
    await _api.tokenStore.write(r);
  }

  Future<bool> ensureValidSession({
    bool refreshIfExpired = true,
    bool failOnRefreshError = false,
  }) async {
    final tokens = await _api.tokenStore.read();
    if (tokens == null) {
      isAuthenticated.value = false;
      me.value = null;
      await _api.tokenStore.clear();
      return false;
    }

    if (_isTokenExpired(tokens)) {
      if (!refreshIfExpired) {
        await _api.tokenStore.clear();
        isAuthenticated.value = false;
        me.value = null;
        return false;
      }

      try {
        final refreshed = await authApi.refresh(tokens.refreshToken);
        await _persistRefreshedSession(refreshed);
        isAuthenticated.value = true;
        return true;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403 || failOnRefreshError) {
          await _api.tokenStore.clear();
          isAuthenticated.value = false;
          me.value = null;
          return false;
        }
        if (kDebugMode) debugPrint('API ERROR(refresh): $e');
        isAuthenticated.value = true;
        return true;
      } catch (e) {
        if (kDebugMode) debugPrint('API ERROR(refresh): $e');
        await _api.tokenStore.clear();
        isAuthenticated.value = false;
        me.value = null;
        return false;
      }
    }

    // Still valid: optionally refresh early so the next API call uses a fresh JWT.
    if (refreshIfExpired &&
        tokens.refreshToken.isNotEmpty &&
        _isTokenExpiredWithin(tokens, const Duration(minutes: 5))) {
      try {
        final refreshed = await authApi.refresh(tokens.refreshToken);
        await _persistRefreshedSession(refreshed);
      } catch (e) {
        if (failOnRefreshError) {
          if (kDebugMode) debugPrint('API ERROR(proactive refresh): $e');
          await _api.tokenStore.clear();
          isAuthenticated.value = false;
          me.value = null;
          return false;
        }
        // Keep existing tokens; [AuthInterceptor] will retry refresh on 401.
      }
    }

    isAuthenticated.value = true;
    return true;
  }

  /// Premium from `/api/v1/users/me` only (not settings cache or local toggles).
  bool get isPremiumFromMe {
    final profile = me.value;
    if (profile == null || profile.isEmpty) return false;

    bool scan(Map<String, dynamic> map) {
      if (_toBool(map['isPremium']) == true) return true;
      if (_toBool(map['is_premium']) == true) return true;
      return false;
    }

    if (scan(profile)) return true;

    final data = _toMap(profile['data']);
    if (data != null && data.isNotEmpty && scan(data)) return true;

    final user = _toMap(profile['user']);
    if (user != null && user.isNotEmpty && scan(user)) return true;

    return false;
  }

  Future<void> refreshMe({
    bool silent = false,
    bool clearSessionOnFailure = false,
  }) async {
    try {
      final profile = await authApi.me();
      me.value = profile;
      isAuthenticated.value = true;
    } catch (e) {
      lastError.value = 'Failed to load profile: $e';
      if (kDebugMode) debugPrint('API ERROR(me): $e');
      final unauthorized = e is DioException && e.response?.statusCode == 401;
      if (unauthorized || clearSessionOnFailure) {
        await _api.tokenStore.clear();
        isAuthenticated.value = false;
        me.value = null;
      }
    }
  }

  /// Uses `/api/v1/users/me` as source-of-truth for notification preference.
  /// Returns [defaultValue] when the flag can't be inferred.
  Future<bool> isNotificationEnabledOnServer({
    bool refresh = true,
    bool defaultValue = false,
  }) async {
    try {
      if (refresh || me.value == null) {
        await refreshMe(silent: true);
      }
      final inferred = _extractNotificationEnabledFromProfile(me.value);
      return inferred ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  bool? _extractNotificationEnabledFromProfile(Map<String, dynamic>? profile) {
    if (profile == null || profile.isEmpty) return null;

    bool? readToggle(dynamic node) {
      final parsed = _toBool(node);
      if (parsed != null) return parsed;
      if (node is Map) {
        final map = Map<String, dynamic>.from(node);
        for (final key in const [
          'enabled',
          'isEnabled',
          'is_enabled',
          'pushEnabled',
          'push_enabled',
          'allow',
          'allowed',
          'value',
        ]) {
          final v = _toBool(map[key]);
          if (v != null) return v;
        }
      }
      return null;
    }

    final roots = <Map<String, dynamic>>[
      profile,
      _toMap(profile['data']) ?? const <String, dynamic>{},
      _toMap(profile['settings']) ?? const <String, dynamic>{},
      _toMap(profile['preferences']) ?? const <String, dynamic>{},
      _toMap(profile['userPreference']) ?? const <String, dynamic>{},
      _toMap(profile['user_preference']) ?? const <String, dynamic>{},
    ];

    for (final root in roots) {
      if (root.isEmpty) continue;

      for (final key in const [
        'notificationsEnabled',
        'notifications_enabled',
        'notificationEnabled',
        'notification_enabled',
        'isNotificationsEnabled',
        'is_notifications_enabled',
      ]) {
        final v = _toBool(root[key]);
        if (v != null) return v;
      }

      for (final key in const [
        'notifications',
        'notification',
        'notification_settings',
        'notificationSettings',
      ]) {
        final parsed = readToggle(root[key]);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  /// Runs the Google sign-in UI and returns id token, access token (if granted), and Google user id.
  Future<GoogleSignInCredentials> fetchGoogleAccountCredentials() {
    return GoogleSignInService.instance.signInAndFetchCredentials();
  }

  /// Message when [loginWithGoogle] already obtained Google tokens but the backend rejected the request.
  String _messageForGoogleLoginApiFailure(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final err = data['error'];
        if (err is Map) {
          final code = err['code']?.toString();
          final raw = err['message']?.toString().trim();
          if (code == 'INVALID_TOKEN') {
            return 'Could not finish signing in with the server. '
                'If this continues, the app may need an update or the server configuration must allow this Google project.';
          }
          if (raw != null && raw.isNotEmpty) {
            return raw;
          }
        }
        final top = data['message']?.toString().trim();
        if (top != null && top.isNotEmpty) return top;
      }
      final status = e.response?.statusCode;
      if (status != null) {
        return 'Could not complete sign-in (server responded with $status). Please try again.';
      }
    }
    return 'Could not complete sign-in. Please try again.';
  }

  /// Google Sign-In, then POST tokens to [AuthApi.loginWithGoogle] and persist the app session.
  ///
  /// Returns `true` only when the backend session is created successfully.
  /// Returns `false` when the user cancels the Google UI (no navigation should happen).
  Future<bool> loginWithGoogle() async {
    try {
      final creds = await fetchGoogleAccountCredentials();
      try {
        var tokens = await authApi.loginWithGoogle(
          idToken: creds.idToken,
          accessToken: creds.accessToken,
        );
        if (tokens.accessTokenExpiresAt == null &&
            tokens.accessToken.isNotEmpty) {
          final exp = parseJwtAccessTokenExpiryUtc(tokens.accessToken);
          if (exp != null) {
            tokens = tokens.copyWith(accessTokenExpiresAt: exp);
          }
        }
        await _api.tokenStore.write(tokens);
        await PlatformTokenProvider().setGoogleOAuthAccessToken(
          creds.accessToken,
        );
        isAuthenticated.value = true;
        lastError.value = null;
        await refreshMe(silent: true);
        if (!isAuthenticated.value) {
          // If `/me` decided the session is invalid, treat login as failed.
          throw StateError('Could not verify session after sign-in.');
        }
        try {
          await _syncIntroOnboardingFlagAfterLogin();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('INTRO ONBOARDING SYNC (Google login) failed: $e');
          }
        }
        unawaited(_registerPushTokenAfterAuth('google_login'));
        return true;
      } on DioException catch (e) {
        lastError.value = _messageForGoogleLoginApiFailure(e);
        if (kDebugMode) {
          debugPrint('loginWithGoogle: Google OK, backend error: $e');
        }
        rethrow;
      } catch (e) {
        lastError.value = 'Could not complete sign-in. Please try again.';
        if (kDebugMode)
          debugPrint('loginWithGoogle: Google OK, unexpected: $e');
        rethrow;
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        lastError.value = null;
        return false;
      }
      lastError.value =
          'Google sign-in failed: ${e.description ?? e.code.name}';
      if (kDebugMode) debugPrint('Google sign-in: $e');
      rethrow;
    } catch (e) {
      lastError.value = 'Google sign-in failed: $e';
      if (kDebugMode) debugPrint('Google sign-in: $e');
      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      var tokens = await authApi.login(email: email, password: password);
      if (tokens.accessTokenExpiresAt == null &&
          tokens.accessToken.isNotEmpty) {
        final exp = parseJwtAccessTokenExpiryUtc(tokens.accessToken);
        if (exp != null) {
          tokens = tokens.copyWith(accessTokenExpiresAt: exp);
        }
      }
      await _api.tokenStore.write(tokens);
      await PlatformTokenProvider().setGoogleOAuthAccessToken(null);
      isAuthenticated.value = true;
      lastError.value = null;
      await refreshMe(silent: true);
      try {
        await _syncIntroOnboardingFlagAfterLogin();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('INTRO ONBOARDING SYNC (email login) failed: $e');
        }
      }
      unawaited(_registerPushTokenAfterAuth('email_login'));
    } catch (e) {
      lastError.value = 'Login failed: $e';
      if (kDebugMode) debugPrint('API ERROR(login): $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await logoutAndClearAllStoredData();
  }

  /// Ends the server session, clears secure token store and **all** SharedPreferences.
  Future<void> logoutAndClearAllStoredData() async {
    final tokens = await _api.tokenStore.read();
    final accessToken = tokens?.accessToken;

    try {
      await unregisterCurrentDevicePushToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PUSH TOKEN UNREGISTER ON LOGOUT failed: $e');
      }
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await _persistLastRegisteredPushToken(null);

    try {
      final res = await authApi.logout(accessToken: accessToken);
      // ignore: avoid_print
      print('LOGOUT API response: status=${res.statusCode} data=${res.data}');
    } catch (e) {
      if (kDebugMode) debugPrint('LOGOUT API error: $e');
    }

    await _api.tokenStore.clear();
    try {
      await _secureStorage.delete(key: _kIntroDoneUsers);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    isAuthenticated.value = false;
    me.value = null;
    lastError.value = null;
    await GoogleSignInService.instance.signOut();
  }

  Future<void> _registerPushTokenAfterAuth(String source) async {
    try {
      final ok = await registerCurrentDevicePushToken();
      if (kDebugMode) {
        debugPrint('PUSH TOKEN AUTO REGISTER [$source]: $ok');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PUSH TOKEN AUTO REGISTER [$source] failed: $e');
      }
    }
  }

  String _currentDevicePushPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  Future<String?> _readLastRegisteredPushToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kLastRegisteredPushToken)?.trim();
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistLastRegisteredPushToken(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = token?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        await prefs.remove(_kLastRegisteredPushToken);
      } else {
        await prefs.setString(_kLastRegisteredPushToken, trimmed);
      }
    } catch (_) {}
  }

  Future<Map<String, String>?> _authJsonHeaders() async {
    final tokens = await _api.tokenStore.read();
    final accessToken = tokens?.accessToken.trim();
    if (accessToken == null || accessToken.isEmpty) return null;
    return <String, String>{
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  Future<bool> registerCurrentDevicePushToken() async {
    try {
      final headers = await _authJsonHeaders();
      if (headers == null) return false;

      final fcmToken = (await FirebaseMessaging.instance.getToken())?.trim();
      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) debugPrint('PUSH TOKEN REGISTER skipped: empty FCM token');
        return false;
      }

      if (kDebugMode) {
        debugPrint(
          'PUSH TOKEN API REQUEST: POST /api/v1/notifications/push-tokens '
          'body={"token":"***","platform":"${_currentDevicePushPlatform()}"}',
        );
      }
      final res = await _api.client.dio.post<dynamic>(
        '/api/v1/notifications/push-tokens',
        data: <String, dynamic>{
          'token': fcmToken,
          'platform': _currentDevicePushPlatform(),
        },
        options: Options(headers: headers),
      );
      if (kDebugMode) {
        debugPrint(
          'PUSH TOKEN API RESPONSE: POST /api/v1/notifications/push-tokens '
          'status=${res.statusCode} data=${res.data}',
        );
      }
      await _persistLastRegisteredPushToken(fcmToken);
      if (kDebugMode) {
        debugPrint(
          'PUSH TOKEN REGISTERED: platform=${_currentDevicePushPlatform()} tokenLen=${fcmToken.length}',
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode && e is DioException) {
        debugPrint(
          'PUSH TOKEN API ERROR: POST /api/v1/notifications/push-tokens '
          'status=${e.response?.statusCode} data=${e.response?.data}',
        );
      }
      if (kDebugMode) debugPrint('PUSH TOKEN REGISTER failed: $e');
      return false;
    }
  }

  Future<bool> unregisterCurrentDevicePushToken() async {
    try {
      final headers = await _authJsonHeaders();
      if (headers == null) return false;

      final tokenFromFcm = (await FirebaseMessaging.instance.getToken())?.trim();
      final token = tokenFromFcm?.isNotEmpty == true
          ? tokenFromFcm
          : await _readLastRegisteredPushToken();
      if (token == null || token.isEmpty) return false;

      if (kDebugMode) {
        debugPrint(
          'PUSH TOKEN API REQUEST: DELETE /api/v1/notifications/push-tokens '
          'body={"token":"***"}',
        );
      }
      final res = await _api.client.dio.delete<dynamic>(
        '/api/v1/notifications/push-tokens',
        data: <String, dynamic>{'token': token},
        options: Options(headers: headers),
      );
      if (kDebugMode) {
        debugPrint(
          'PUSH TOKEN API RESPONSE: DELETE /api/v1/notifications/push-tokens '
          'status=${res.statusCode} data=${res.data}',
        );
      }
      await _persistLastRegisteredPushToken(null);
      if (kDebugMode) {
        debugPrint('PUSH TOKEN UNREGISTERED: tokenLen=${token.length}');
      }
      return true;
    } catch (e) {
      if (kDebugMode && e is DioException) {
        debugPrint(
          'PUSH TOKEN API ERROR: DELETE /api/v1/notifications/push-tokens '
          'status=${e.response?.statusCode} data=${e.response?.data}',
        );
      }
      if (kDebugMode) debugPrint('PUSH TOKEN UNREGISTER failed: $e');
      return false;
    }
  }

  Future<bool> connectProvider(
    OAuthProvider provider, {
    bool forceVerify = false,
  }) async {
    try {
      final hasTokens = (await _api.tokenStore.read()) != null;
      if (!hasTokens) {
        isAuthenticated.value = false;
        me.value = null;
      }
      final authUrl = await oauthApi.getAuthUrl(
        provider: provider,
        link: hasTokens,
        forceVerify: forceVerify,
      );
      if (kDebugMode) {
        debugPrint(
          'OAUTH AUTH URL REQUEST(${provider.name}): link=$hasTokens force_verify=$forceVerify',
        );
      }

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
          debugPrint(
            'OAUTH PARAMS(${provider.name}): ${parsed.rawParams ?? {}}',
          );
        }
        _showOauthError('Login failed. Please try again.', error: err);
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
        final at = parsed.accessToken!;
        final rt = parsed.refreshToken!;
        await _api.tokenStore.write(
          SessionTokens(
            accessToken: at,
            refreshToken: rt,
            accessTokenExpiresAt: parseJwtAccessTokenExpiryUtc(at),
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
        map =
            decoded is Map<String, dynamic>
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
    final refreshToken = extractString(json, const [
      'refreshToken',
      'refresh_token',
    ]);

    if (accessToken == null || accessToken.isEmpty) return null;
    if (refreshToken == null || refreshToken.isEmpty) return null;

    return SessionTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: parseJwtAccessTokenExpiryUtc(accessToken),
    );
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
