import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../controllers/chat_controller.dart';
import 'stream_embed_url_utils.dart';
import 'stream_webview.dart';

/// One platform’s embed: keeps the last non-empty embed URL across tab switches and
/// brief `platformLive` / map gaps so [StreamWebView] is not sent `''` (idle) unless
/// the platform is **explicitly** offline (`platformLive[key] == false`).
class _LiveStreamPlatformSlot extends StatefulWidget {
  const _LiveStreamPlatformSlot({
    required this.platformKey,
    required this.height,
    required this.muted,
    required this.streamViewKey,
  });

  final String platformKey;
  final double height;
  final bool muted;
  final Key streamViewKey;

  @override
  State<_LiveStreamPlatformSlot> createState() => _LiveStreamPlatformSlotState();
}

class _LiveStreamPlatformSlotState extends State<_LiveStreamPlatformSlot> {
  String _latchedEmbedUrl = '';

  @override
  Widget build(BuildContext context) {
    final chatCtrl = Get.find<ChatController>();
    return Obx(() {
      final liveExpected = chatCtrl.isPlatformLive(widget.platformKey);
      final fresh = chatCtrl.urlForPlatform(widget.platformKey)?.trim() ?? '';
      final hardOff = chatCtrl.isPlatformExplicitlyOffline(widget.platformKey);

      if (!liveExpected) {
        _latchedEmbedUrl = '';
      } else if (fresh.isNotEmpty) {
        if (_latchedEmbedUrl.isEmpty ||
            !streamEmbedUrlsCanonicallyEqual(fresh, _latchedEmbedUrl)) {
          _latchedEmbedUrl = fresh;
        }
      } else if (hardOff) {
        _latchedEmbedUrl = '';
      }

      // Always keep WebView mounted: no embed URL when offline; idle shell only.
      final webUrl = liveExpected ? _latchedEmbedUrl : '';
      return RepaintBoundary(
        child: StreamWebView(
          key: widget.streamViewKey,
          url: webUrl,
          height: widget.height,
          muted: widget.muted,
          streamExpectedLive: liveExpected,
        ),
      );
    });
  }
}

/// Single-preview mode: only rebuilds when [ChatController.platform] changes,
/// not on every global stream/socket update.
class LiveStreamSingleEmbedStack extends StatelessWidget {
  const LiveStreamSingleEmbedStack({
    super.key,
    required this.streamPreviewHeight,
  });

  final double streamPreviewHeight;

  static const _platforms = <String>['twitch', 'kick', 'youtube'];

  static int _embedIndex(String raw) {
    final p = raw.toLowerCase().trim();
    final i = _platforms.indexOf(p);
    return i >= 0 ? i : 0;
  }

  @override
  Widget build(BuildContext context) {
    final chatCtrl = Get.find<ChatController>();
    return Obx(() {
      final selected = chatCtrl.platform.value.toLowerCase().trim();
      final index = _embedIndex(selected);
      return IndexedStack(
        index: index,
        sizing: StackFit.expand,
        children: [
          for (var i = 0; i < _platforms.length; i++)
            IgnorePointer(
              ignoring: i != index,
              child: _LiveStreamPlatformSlot(
                platformKey: _platforms[i],
                height: streamPreviewHeight,
                muted: i != index,
                streamViewKey: ValueKey('stream_single_${_platforms[i]}'),
              ),
            ),
        ],
      );
    });
  }
}

/// Multi-preview tiles; each tile has its own narrow [Obx].
class LiveStreamMultiEmbedGrid extends StatelessWidget {
  const LiveStreamMultiEmbedGrid({
    super.key,
    required this.streamPreviewHeight,
  });

  final double streamPreviewHeight;

  static const _platforms = <String>['twitch', 'kick', 'youtube'];

  @override
  Widget build(BuildContext context) {
    final tileGap = 8.w;
    const topFlex = 56;
    const bottomFlex = 44;

    Widget tile({
      required String platform,
      required BorderRadius radius,
      required double height,
    }) {
      return ClipRRect(
        borderRadius: radius,
        child: _LiveStreamPlatformSlot(
          platformKey: platform,
          height: height,
          muted: false,
          streamViewKey: ValueKey('stream_$platform'),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: topFlex,
          child: Row(
            children: [
              Expanded(
                child: tile(
                  platform: _platforms[0],
                  radius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                  ),
                  height: streamPreviewHeight,
                ),
              ),
              SizedBox(width: tileGap),
              Expanded(
                child: tile(
                  platform: _platforms[1],
                  radius: BorderRadius.only(
                    topRight: Radius.circular(16.r),
                  ),
                  height: streamPreviewHeight,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tileGap),
        Expanded(
          flex: bottomFlex,
          child: tile(
            platform: _platforms[2],
            radius: BorderRadius.only(
              bottomLeft: Radius.circular(16.r),
              bottomRight: Radius.circular(16.r),
            ),
            height: streamPreviewHeight,
          ),
        ),
      ],
    );
  }
}
