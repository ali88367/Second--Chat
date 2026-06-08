import 'dart:async';



import 'package:apivideo_live_stream/apivideo_live_stream.dart';

import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/scheduler.dart';

import 'package:flutter/widgets.dart';

import 'package:get/get.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:wakelock_plus/wakelock_plus.dart';



import '../api/app_api.dart';

import '../controllers/auth_controller.dart';

import '../data/models/platform_publish_config.dart';

import '../data/services/platform_publish_service.dart';

import '../services/broadcast_pip_platform.dart';



enum BroadcastPlatform { twitch, kick, youtube }



/// Title, category, and optional Kick stream ID collected before going live.

class GoLivePlatformSetup {

  const GoLivePlatformSetup({

    required this.title,

    required this.category,

    this.categoryId,

    this.kickStreamId,

  });



  final String title;

  final String category;

  final String? categoryId;

  final String? kickStreamId;

}



extension BroadcastPlatformX on BroadcastPlatform {

  String get key {

    switch (this) {

      case BroadcastPlatform.twitch:

        return 'twitch';

      case BroadcastPlatform.kick:

        return 'kick';

      case BroadcastPlatform.youtube:

        return 'youtube';

    }

  }



  String get label {

    switch (this) {

      case BroadcastPlatform.twitch:

        return 'Twitch';

      case BroadcastPlatform.kick:

        return 'Kick';

      case BroadcastPlatform.youtube:

        return 'YouTube';

    }

  }



  bool get isBroadcastSupported => true;

}



/// Global RTMP broadcast + floating PiP state (GetX, no setState).

class RtmpBroadcastController extends GetxController with WidgetsBindingObserver {

  RtmpBroadcastController({
    PlatformPublishService? publishService,
  }) : _publishServiceOverride = publishService;

  final PlatformPublishService? _publishServiceOverride;
  PlatformPublishService? _cachedPublishService;

  PlatformPublishService get _publishService {
    if (_publishServiceOverride != null) return _publishServiceOverride;
    if (_cachedPublishService != null) return _cachedPublishService!;
    if (!Get.isRegistered<AuthController>()) {
      return PlatformPublishService(AppApi.create().client.dio);
    }
    final auth = Get.find<AuthController>();
    return _cachedPublishService = PlatformPublishService(
      auth.api.client.dio,
      ensureSession: () => auth.ensureValidSession(refreshIfExpired: true),
    );
  }



  ApiVideoLiveStreamController? liveController;



  final RxBool isInitializing = false.obs;

  final RxBool isReady = false.obs;

  final RxBool isStreaming = false.obs;

  final RxBool isConnecting = false.obs;

  final RxBool showFloatingPip = false.obs;

  final RxBool isOnGoLiveScreen = false.obs;

  final RxBool isMicMuted = false.obs;

  final RxnString errorMessage = RxnString();

  final RxnString kickStreamId = RxnString();

  final RxBool kickManualConfigured = false.obs;



  static const _kKickStreamIdPref = 'second_chat.kick.stream_id';



  final RxSet<BroadcastPlatform> selectedPlatforms =

      <BroadcastPlatform>{BroadcastPlatform.twitch}.obs;



  final RxDouble pipOffsetX = 16.0.obs;

  final RxDouble pipOffsetY = 120.0.obs;



  PublishConfigBundle? _publishBundle;
  bool _isStoppingIntentionally = false;
  bool _isPreviewHandoff = false;
  Completer<bool>? _rtmpConnectionCompleter;

  String get broadcastingSubtitle {
    final bundle = _publishBundle;
    if (bundle != null) {
      for (final platform in selectedPlatforms) {
        final config = bundle.forPlatform(platform.key);
        final channel = config?.channel.trim() ?? '';
        if (channel.isNotEmpty) return '@$channel';
      }
    }
    return 'Broadcast from your device';
  }

  bool get hasActiveBroadcast =>

      isStreaming.value && liveController?.isInitialized == true;



  bool get shouldShowInAppFloatingPip =>

      showFloatingPip.value &&

      hasActiveBroadcast &&

      !isOnGoLiveScreen.value;



  bool get canShowCameraPreviewInGoLive =>

      isOnGoLiveScreen.value && isReady.value && liveController != null;



  bool get canShowCameraPreviewInPip => shouldShowInAppFloatingPip;



  bool get canShowCameraPreviewInEmbed =>

      hasActiveBroadcast &&

      !isOnGoLiveScreen.value &&

      !showFloatingPip.value;



  bool get hasStoredKickStreamId =>

      kickManualConfigured.value || (kickStreamId.value ?? '').trim().isNotEmpty;



  bool isPlatformSelected(BroadcastPlatform platform) =>

      selectedPlatforms.contains(platform);



  bool shouldShowBroadcastPreviewForPlatform(String platformKey) {

    if (!canShowCameraPreviewInEmbed) return false;

    final key = platformKey.toLowerCase().trim();

    for (final platform in selectedPlatforms) {

      if (platform.key == key) return true;

    }

    return false;

  }



  @override

  void onInit() {

    super.onInit();

    WidgetsBinding.instance.addObserver(this);

    unawaited(refreshKickManualState());

  }



  Future<void> refreshKickManualState() async {

    await loadKickStreamIdFromPrefs();

    try {

      if (!Get.isRegistered<AuthController>()) return;

      final auth = Get.find<AuthController>();

      if (!auth.isAuthenticated.value) return;

      final config = await _publishService.fetchPublishConfig('kick');

      kickManualConfigured.value = config.hasManualConfig || config.hasRtmpCredentials;

    } catch (_) {}

  }



  Future<void> loadKickStreamIdFromPrefs() async {

    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getString(_kKickStreamIdPref)?.trim();

    kickStreamId.value = (id != null && id.isNotEmpty) ? id : null;

    if (kickStreamId.value != null) {

      kickManualConfigured.value = true;

    }

  }



  Future<void> saveKickStreamIdLocally(String id) async {

    final trimmed = id.trim();

    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_kKickStreamIdPref, trimmed);

    kickStreamId.value = trimmed;

    kickManualConfigured.value = true;

  }



  String? validateGoLiveSetup(Map<BroadcastPlatform, GoLivePlatformSetup> setup) {

    if (setup.isEmpty) {

      return 'Turn on at least one platform';

    }

    for (final entry in setup.entries) {
      final platform = entry.key;
      final data = entry.value;

      if (platform == BroadcastPlatform.twitch) {
        if (data.title.trim().isEmpty) {
          return 'Enter a title for Twitch';
        }
        if (data.category.trim().isEmpty) {
          return 'Select a category for Twitch';
        }
      }

      if (platform == BroadcastPlatform.kick && !hasStoredKickStreamId) {

        final streamId = data.kickStreamId?.trim() ?? '';

        if (streamId.isEmpty) {

          return 'Enter a Stream ID for Kick';

        }

      }

    }

    return null;

  }



  Future<bool> submitGoLiveSetup(

    Map<BroadcastPlatform, GoLivePlatformSetup> setup,

  ) async {

    final validationError = validateGoLiveSetup(setup);

    if (validationError != null) {

      errorMessage.value = validationError;

      return false;

    }



    errorMessage.value = null;



    final kickData = setup[BroadcastPlatform.kick];

    if (kickData != null && !hasStoredKickStreamId) {

      final streamId = kickData.kickStreamId?.trim() ?? '';

      if (streamId.isNotEmpty) {

        try {

          await _publishService.saveKickManualConfig(

            streamKey: streamId,

            streamId: streamId,

          );

          await saveKickStreamIdLocally(streamId);

        } catch (e) {

          errorMessage.value = _humanizeError(e);

          return false;

        }

      }

    }



    selectedPlatforms

      ..clear()

      ..addAll(setup.keys);



    await startBroadcast();

    return isStreaming.value;

  }



  @override

  void onClose() {

    WidgetsBinding.instance.removeObserver(this);

    unawaited(_disposeLiveController());

    unawaited(WakelockPlus.disable());

    unawaited(BroadcastPipPlatform.setBroadcastActive(false));

    super.onClose();

  }



  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    final controller = liveController;

    if (controller == null || !controller.isInitialized) return;



    if (state == AppLifecycleState.inactive ||

        state == AppLifecycleState.paused) {

      if (isStreaming.value) {

        unawaited(BroadcastPipPlatform.enterPipIfSupported());

      }

      return;

    }



    if (state == AppLifecycleState.resumed && !isStreaming.value) {

      unawaited(controller.startPreview());

    }

  }



  Future<void> ensureInitialized() async {

    if (isReady.value || isInitializing.value) return;

    isInitializing.value = true;

    errorMessage.value = null;

    try {

      await _requestPermissions();

      await _ensureLiveController();

      isReady.value = true;

    } catch (e) {

      errorMessage.value = _humanizeError(e);

      isReady.value = false;

    } finally {

      isInitializing.value = false;

    }

  }



  Future<void> _requestPermissions() async {

    final statuses = await [

      Permission.camera,

      Permission.microphone,

    ].request();

    final camera = statuses[Permission.camera];

    final mic = statuses[Permission.microphone];

    if (camera != PermissionStatus.granted) {

      throw Exception('Camera permission is required to go live');

    }

    if (mic != PermissionStatus.granted) {

      throw Exception('Microphone permission is required to go live');

    }

  }



  Future<void> _ensureLiveController() async {

    if (liveController != null && liveController!.isInitialized) return;



    final controller = ApiVideoLiveStreamController(

      initialAudioConfig: AudioConfig(

        bitrate: 128000,

        sampleRate: SampleRate.kHz_44_1,

        channel: Channel.stereo,

      ),

      initialVideoConfig: VideoConfig(
        bitrate: 2500000,
        resolution: Resolution.RESOLUTION_720,
        fps: 30,
      ),

      onConnectionSuccess: _onConnectionSuccess,

      onConnectionFailed: _onConnectionFailed,

      onDisconnection: _onDisconnection,

      onError: _onLiveError,

    );



    liveController = controller;

    await controller.initialize();

  }



  void _onConnectionSuccess() {
    if (kDebugMode) debugPrint('[RTMP] connection success');
    isConnecting.value = false;
    isStreaming.value = true;
    errorMessage.value = null;
    unawaited(WakelockPlus.enable());
    unawaited(BroadcastPipPlatform.setBroadcastActive(true));
    _finishConnectionWait(true);
  }

  void _onConnectionFailed(String message) {
    if (kDebugMode) {
      debugPrint('[RTMP] connection failed: ${message.isEmpty ? 'unknown' : message}');
    }
    isConnecting.value = false;
    _finishConnectionWait(false);
    if (!_isStoppingIntentionally) {
      isStreaming.value = false;
      errorMessage.value = message.isEmpty ? 'Connection failed' : message;
      unawaited(WakelockPlus.disable());
      unawaited(BroadcastPipPlatform.setBroadcastActive(false));
    }
  }

  void _onDisconnection() {
    isConnecting.value = false;
    _finishConnectionWait(false);
    if (_isStoppingIntentionally || _isPreviewHandoff) return;
    isStreaming.value = false;
    showFloatingPip.value = false;
    unawaited(WakelockPlus.disable());
    unawaited(BroadcastPipPlatform.setBroadcastActive(false));
  }

  void _onLiveError(Exception error) {
    _finishConnectionWait(false);
    if (_isStoppingIntentionally || _isPreviewHandoff) return;
    errorMessage.value = error.toString();
    isConnecting.value = false;
    isStreaming.value = false;
    unawaited(WakelockPlus.disable());
    unawaited(BroadcastPipPlatform.setBroadcastActive(false));
  }

  Completer<bool> _beginConnectionWait() {
    final pending = _rtmpConnectionCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.complete(false);
    }
    final waiter = Completer<bool>();
    _rtmpConnectionCompleter = waiter;
    return waiter;
  }

  void _finishConnectionWait(bool connected) {
    final waiter = _rtmpConnectionCompleter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(connected);
    }
  }

  void _cancelConnectionWait() {
    _finishConnectionWait(false);
    _rtmpConnectionCompleter = null;
  }

  Future<bool> _waitForRtmpConnectionWithPolling(
    ApiVideoLiveStreamController controller,
    Completer<bool> waiter, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (waiter.isCompleted) {
        return waiter.future;
      }
      try {
        if (await controller.isStreaming) {
          if (kDebugMode) debugPrint('[RTMP] native isStreaming=true');
          if (!waiter.isCompleted) {
            _finishConnectionWait(true);
          }
          if (!isStreaming.value) {
            _onConnectionSuccess();
          }
          return true;
        }
      } catch (_) {}
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      final slice = remaining < const Duration(milliseconds: 400)
          ? remaining
          : const Duration(milliseconds: 400);
      await Future<void>.delayed(slice);
    }

    if (!waiter.isCompleted) {
      _finishConnectionWait(false);
    }
    if (kDebugMode) debugPrint('[RTMP] connection polling timed out');
    return false;
  }

  Future<void> toggleBroadcast() async {

    if (isStreaming.value || isConnecting.value) {

      await stopBroadcast();

    } else {

      await startBroadcast();

    }

  }



  Future<void> startBroadcast() async {
    if (!isReady.value) {
      await ensureInitialized();
      if (!isReady.value) return;
    }

    if (selectedPlatforms.isEmpty) {
      errorMessage.value = 'Turn on at least one platform';
      return;
    }

    final controller = liveController;
    if (controller == null) {
      errorMessage.value = 'Broadcast not ready';
      return;
    }

    isConnecting.value = true;
    errorMessage.value = null;
    _isStoppingIntentionally = false;

    try {
      final activeIngest = await _resolveActiveIngest();
      if (activeIngest == null || !activeIngest.hasRtmpCredentials) {
        errorMessage.value =
            'Missing RTMP credentials. Check platform connections and Kick stream key.';
        isConnecting.value = false;
        return;
      }

      final connected = await _connectToIngest(activeIngest, controller);
      if (!connected) {
        errorMessage.value ??=
            'Could not connect to ${activeIngest.platform} ingest server';
        isConnecting.value = false;
        isStreaming.value = false;
        await WakelockPlus.disable();
        await BroadcastPipPlatform.setBroadcastActive(false);
      }
    } catch (e) {
      _cancelConnectionWait();
      isConnecting.value = false;
      isStreaming.value = false;
      errorMessage.value = _humanizeError(e);
      await WakelockPlus.disable();
      await BroadcastPipPlatform.setBroadcastActive(false);
    }
  }

  Future<PlatformPublishConfig?> _resolveActiveIngest() async {
    final selectedKeys = selectedPlatforms.map((p) => p.key).toList();

    _publishBundle = await _publishService.fetchAllPublishConfigs(
      platforms: selectedKeys,
    );

    final ingest = _publishBundle?.resolveIngestForPlatforms(selectedKeys);
    if (ingest == null) return null;

    if (ingest.platform == 'youtube' && kDebugMode) {
      debugPrint(
        '[RTMP] YouTube broadcastId=${ingest.broadcastId ?? 'n/a'} '
        'streamId=${ingest.youtubeStreamId ?? 'n/a'}',
      );
    }

    return ingest;
  }

  Future<bool> _connectToIngest(
    PlatformPublishConfig ingest,
    ApiVideoLiveStreamController controller,
  ) async {
    final fullUrls = ingest.fullRtmpPublishUrls;
    if (fullUrls.isEmpty) return false;

    for (var i = 0; i < fullUrls.length; i++) {
      final fullUrl = fullUrls[i];
      if (kDebugMode) {
        final host = Uri.tryParse(fullUrl.replaceFirst('rtmp://', 'http://'))?.host;
        debugPrint(
          '[RTMP] ${ingest.platform} ingest attempt ${i + 1}/${fullUrls.length}: '
          'host=$host keyLen=${ingest.streamKey.length}',
        );
      }

      final connectionWaiter = _beginConnectionWait();
      try {
        await controller.startStreaming(
          streamKey: ingest.streamKey,
          url: ingest.ingestServerUrls[i],
          fullUrl: fullUrl,
        );
        if (kDebugMode) {
          debugPrint('[RTMP] startStreaming invoked, waiting for RTMP publish...');
        }
      } catch (e) {
        _cancelConnectionWait();
        if (kDebugMode) {
          debugPrint('[RTMP] startStreaming error: $e');
        }
        continue;
      }

      final connected = await _waitForRtmpConnectionWithPolling(
        controller,
        connectionWaiter,
      );
      if (connected) {
        if (kDebugMode) debugPrint('[RTMP] publishing on attempt ${i + 1}');
        return true;
      }

      if (kDebugMode) {
        debugPrint('[RTMP] attempt ${i + 1} failed, trying next ingest if any');
      }

      _isStoppingIntentionally = true;
      try {
        await controller.stopStreaming();
      } catch (_) {}
      _isStoppingIntentionally = false;
    }

    return false;
  }

  Future<void> stopBroadcast() async {
    final controller = liveController;
    if (controller == null) return;
    _isStoppingIntentionally = true;
    _cancelConnectionWait();

    try {

      await controller.stopStreaming();

    } catch (_) {}

    isStreaming.value = false;

    isConnecting.value = false;

    showFloatingPip.value = false;

    _isStoppingIntentionally = false;

    await WakelockPlus.disable();

    await BroadcastPipPlatform.setBroadcastActive(false);

  }



  Future<void> switchCamera() async {

    await liveController?.switchCamera();

  }



  Future<void> toggleMicrophone() async {

    final controller = liveController;

    if (controller == null) return;

    await controller.toggleMute();

    isMicMuted.value = await controller.isMuted;

  }



  void onEnterGoLiveScreen() {

    isOnGoLiveScreen.value = true;

    if (showFloatingPip.value) {

      SchedulerBinding.instance.addPostFrameCallback((_) {

        if (isOnGoLiveScreen.value) {

          showFloatingPip.value = false;

        }

      });

    }

  }



  void onLeaveGoLiveScreen({required bool keepBroadcasting}) {

    if (keepBroadcasting && isStreaming.value && liveController != null) {

      _isPreviewHandoff = true;

      showFloatingPip.value = true;

      SchedulerBinding.instance.addPostFrameCallback((_) {

        isOnGoLiveScreen.value = false;

        Future<void>.delayed(const Duration(milliseconds: 400), () {

          _isPreviewHandoff = false;

        });

      });

    } else {

      isOnGoLiveScreen.value = false;

    }

  }



  void hideFloatingPip() {

    showFloatingPip.value = false;

  }



  void revealFloatingPipIfNeeded() {

    if (hasActiveBroadcast && !isOnGoLiveScreen.value) {

      showFloatingPip.value = true;

    }

  }



  void updatePipPosition(double x, double y) {

    pipOffsetX.value = x;

    pipOffsetY.value = y;

  }



  Future<void> _disposeLiveController() async {

    final controller = liveController;

    liveController = null;

    isReady.value = false;

    isStreaming.value = false;

    if (controller != null) {

      try {

        await controller.dispose();

      } catch (_) {}

    }

  }



  String _humanizeError(Object e) {

    if (e is DioException) {

      final data = e.response?.data;

      if (data is Map) {

        final msg = data['message'] ?? data['error'];

        if (msg != null && msg.toString().trim().isNotEmpty) {

          return msg.toString();

        }

      }

      return e.message ?? 'Network error';

    }

    return e.toString().replaceFirst('Exception: ', '');

  }

}

