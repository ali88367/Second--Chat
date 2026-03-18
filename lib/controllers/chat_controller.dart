import 'package:get/get.dart';

import '../api/app_api.dart';
import '../core/socket/chat_socket_service.dart';
import '../core/utils/platform_token_provider.dart';
import '../data/models/chat_message.dart';
import '../data/models/streaming_overview.dart';
import '../data/services/chat_service.dart';
import '../data/services/streaming_service.dart';

class ChatController extends GetxController {
  ChatController({
    AppApi? api,
    PlatformTokenProvider? tokenProvider,
    ChatSocketService? socketService,
  }) : _api = api ?? AppApi.create(),
       _tokenProvider = tokenProvider ?? PlatformTokenProvider(),
       _socket =
           socketService ?? Get.put(ChatSocketService(), permanent: true) {
    _streaming = StreamingService(_api.client.dio);
    _chat = ChatService(_api.client.dio);
  }

  final AppApi _api;
  final PlatformTokenProvider _tokenProvider;
  final ChatSocketService _socket;
  late final StreamingService _streaming;
  late final ChatService _chat;

  final RxString platform = 'twitch'.obs;

  final RxnString watchUrl = RxnString();
  final RxBool isLive = false.obs;
  final Rxn<StreamingOverview> overview = Rxn<StreamingOverview>();
  final RxMap<String, int> platformViewerCounts = <String, int>{}.obs;
  final RxMap<String, bool> platformLive = <String, bool>{}.obs;
  final RxMap<String, String?> platformEmbedUrls = <String, String?>{}.obs;

  RxList<ChatMessage> get messages => _socket.messages;
  RxInt get viewerCount => _socket.viewerCount;
  RxBool get isConnected => _socket.isConnected;

  final RxInt scrollTick = 0.obs; // UI can observe this to auto-scroll.

  String? _accessToken;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _accessToken = await _tokenProvider.getAccessToken(platform.value);
      if (_accessToken == null || _accessToken!.isEmpty) return;

      final history = await _chat.loadHistory(
        platform: platform.value,
        accessToken: _accessToken!,
      );
      if (history.isNotEmpty) {
        messages.assignAll(history);
        _bumpScroll();
      }

      await refreshOverviewForPlatform(platform.value);

      final ov = overview.value;
      final socketUrl = ov?.chatSocketUrl;
      final socketPath = ov?.chatSocketPath;
      if (socketUrl != null &&
          socketUrl.trim().isNotEmpty &&
          socketPath != null &&
          socketPath.trim().isNotEmpty) {
        await _socket.connect(
          baseUrl: socketUrl.trim(),
          path: socketPath.trim(),
          accessToken: _accessToken!,
        );
      }

      // Keep live/viewer state in sync with realtime events.
      ever<Map<String, int>>(_socket.viewerCountsByPlatform, (m) {
        if (m.isNotEmpty) platformViewerCounts.assignAll(m);
      });
      ever<Map<String, bool>>(_socket.liveByPlatform, (m) {
        if (m.isNotEmpty) platformLive.assignAll(m);
      });

      ever<List<ChatMessage>>(messages, (_) {
        _bumpScroll();
      });
    } catch (_) {}
  }

  Future<void> refreshOverviewForPlatform(String p) async {
    try {
      final token = _accessToken ?? await _tokenProvider.getAccessToken(p);
      if (token == null || token.isEmpty) return;
      final ov = await _streaming.fetchOverview(platform: p, accessToken: token);
      if (ov == null) return;
      overview.value = ov;
      // selected platform state
      platform.value = p;
      isLive.value = ov.live;
      watchUrl.value = ov.watchUrl;
      // multi-platform state
      if (ov.viewerCountsByPlatform.isNotEmpty) {
        platformViewerCounts.assignAll(ov.viewerCountsByPlatform);
      }
      if (ov.liveByPlatform.isNotEmpty) {
        platformLive.assignAll(ov.liveByPlatform);
      } else {
        platformLive[p.toLowerCase()] = ov.live;
      }
      if (ov.embedUrlByPlatform.isNotEmpty) {
        platformEmbedUrls.assignAll(ov.embedUrlByPlatform);
      } else {
        platformEmbedUrls[p.toLowerCase()] = ov.watchUrl;
      }
    } catch (_) {}
  }

  bool isPlatformLive(String p) {
    return platformLive[p.toLowerCase()] == true;
  }

  String? urlForPlatform(String p) {
    return platformEmbedUrls[p.toLowerCase()];
  }

  Future<void> sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty) return;
    final token =
        _accessToken ?? await _tokenProvider.getAccessToken(platform.value);
    if (token == null || token.isEmpty) return;

    await _chat.sendMessage(
      platform: platform.value,
      accessToken: token,
      message: msg,
    );
    _bumpScroll();
  }

  void _bumpScroll() {
    // Cheap observable tick for UI that can't easily diff RxList changes.
    scrollTick.value++;
  }

  @override
  void onClose() {
    try {
      _socket.disconnect();
    } catch (_) {}
    super.onClose();
  }
}
