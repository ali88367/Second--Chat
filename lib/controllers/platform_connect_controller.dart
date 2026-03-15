import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

import '../api/auth/oauth_provider.dart';
import 'auth_controller.dart';

class PlatformConnectController extends GetxController {
  PlatformConnectController({AuthController? authController})
      : _auth = authController ?? Get.find<AuthController>();

  final AuthController _auth;

  final RxBool isLoading = false.obs;
  final Rxn<OAuthProvider> connectingProvider = Rxn<OAuthProvider>();
  final RxMap<OAuthProvider, bool> isConnected = <OAuthProvider, bool>{}.obs;
  final RxSet<OAuthProvider> optimisticLinked = <OAuthProvider>{}.obs;

  @override
  void onInit() {
    super.onInit();
    ever(_auth.isAuthenticated, (_) {
      refreshConnections();
    });
    refreshConnections();
  }

  Future<void> refreshConnections() async {
    if (!_auth.isAuthenticated.value) {
      isConnected.assignAll({
        OAuthProvider.twitch: false,
        OAuthProvider.kick: false,
        OAuthProvider.youtube: false,
      });
      return;
    }

    isLoading.value = true;
    try {
      final connections = await _auth.api.platforms.getConnections();
      if (kDebugMode) {
        debugPrint('PLATFORMS raw count=${connections.length}');
      }
      final map = <OAuthProvider, bool>{
        OAuthProvider.twitch: false,
        OAuthProvider.kick: false,
        OAuthProvider.youtube: false,
      };

      for (final c in connections) {
        final platformRaw = (c['platform'] ?? c['name'] ?? c['type'] ?? '')
            .toString()
            .toLowerCase();
        // Treat "linked/authorized" separately from "enabled" or "currently connected/live".
        final linkedRaw = c['isLinked'] ??
            c['linked'] ??
            c['authorized'] ??
            c['isAuthorized'] ??
            c['hasAuth'] ??
            c['hasTokens'] ??
            c['hasAccessToken'] ??
            c['accessToken'] ??
            c['refreshToken'] ??
            (c['status']?.toString().toLowerCase() == 'linked') ??
            (c['status']?.toString().toLowerCase() == 'authorized');

        final connectedRaw =
            c['isConnected'] ?? c['connected'] ?? c['isLive'] ?? c['live'];

        bool asBool(dynamic v) {
          if (v is bool) return v;
          if (v is num) return v != 0;
          if (v is String) {
            final s = v.toLowerCase().trim();
            return s == 'true' || s == '1' || s == 'yes' || s == 'connected';
          }
          // Non-empty token strings count as linked.
          if (v != null && v is! bool && v is! num) {
            final s = v.toString();
            return s.isNotEmpty;
          }
          return false;
        }

        final linked = asBool(linkedRaw);
        final connected = asBool(connectedRaw);
        final finalConnected = linked || connected;

        if (kDebugMode) {
          debugPrint(
            'PLATFORMS item platform=$platformRaw linkedRaw=$linkedRaw connectedRaw=$connectedRaw => linked=$linked connected=$connected final=$finalConnected',
          );
        }

        if (platformRaw.contains('twitch')) {
          map[OAuthProvider.twitch] = finalConnected;
        }
        if (platformRaw.contains('kick')) map[OAuthProvider.kick] = finalConnected;
        if (platformRaw.contains('youtube') || platformRaw.contains('google')) {
          map[OAuthProvider.youtube] = finalConnected;
        }
      }

      isConnected.assignAll(map);
      // If backend doesn't reflect link state (or uses a different field), keep optimistic state.
      for (final p in optimisticLinked) {
        if (isConnected[p] != true) isConnected[p] = true;
      }
      if (kDebugMode) debugPrint('PLATFORMS mapped=$map');
    } catch (_) {
      // Keep last known state; avoid noisy UI errors in settings.
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> connect(OAuthProvider provider) async {
    if (connectingProvider.value != null) return;
    connectingProvider.value = provider;
    try {
      final ok = await _auth.connectProvider(provider);
      if (ok) {
        optimisticLinked.add(provider);
        isConnected[provider] = true;
      }
    } finally {
      connectingProvider.value = null;
    }
    await refreshConnections();
    // Backend can take a moment to reflect link status; quick retry if still false.
    if (isConnected[provider] != true) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await refreshConnections();
    }
  }
}
