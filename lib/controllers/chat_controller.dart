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

      final ov = await _streaming.fetchOverview(
        platform: platform.value,
        accessToken: _accessToken!,
      );
      if (ov != null) {
        overview.value = ov;
        isLive.value = ov.live;
        watchUrl.value = ov.watchUrl;
        if (ov.viewerCountsByPlatform.isNotEmpty) {
          platformViewerCounts.assignAll(ov.viewerCountsByPlatform);
        } else if (ov.viewerCount != null) {
          platformViewerCounts[ov.platform.toLowerCase()] = ov.viewerCount!;
        }
      }

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

      ever<List<ChatMessage>>(messages, (_) {
        _bumpScroll();
      });
    } catch (_) {}
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
