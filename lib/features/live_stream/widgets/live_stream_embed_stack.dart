import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../controllers/chat_controller.dart';
import '../../../core/localization/l10n.dart';
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
    required this.globalMuted,
    required this.streamViewKey,
    this.onStreamReady,
  });

  final String platformKey;
  final double height;
  final bool muted;
  final bool globalMuted;
  final Key streamViewKey;
  final void Function(String platformKey, String runningUrl)? onStreamReady;

  @override
  State<_LiveStreamPlatformSlot> createState() => _LiveStreamPlatformSlotState();
}

class _LiveStreamPlatformSlotState extends State<_LiveStreamPlatformSlot> {
  String _latchedEmbedUrl = '';
  int _sessionNonce = 0;

  Widget _buildNoStreamState(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off,
            color: Colors.white38,
            size: 28.sp,
          ),
          SizedBox(height: 5.h),
          Text(
            context.l10n.noStreamAtTheMoment,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatCtrl = Get.find<ChatController>();
    return Obx(() {
      final liveExpected = chatCtrl.isPlatformLive(widget.platformKey);
      final fresh = chatCtrl.urlForPlatform(widget.platformKey)?.trim() ?? '';
      final hardOff = chatCtrl.isPlatformExplicitlyOffline(widget.platformKey);

      if (fresh.isNotEmpty) {
        if (_latchedEmbedUrl.isEmpty ||
            !streamEmbedUrlsCanonicallyEqual(fresh, _latchedEmbedUrl)) {
          _latchedEmbedUrl = fresh;
        }
      } else if (hardOff && !liveExpected) {
        _latchedEmbedUrl = '';
      }

      if (!liveExpected) {
        // Explicit offline state: dispose active webview session immediately.
        if (_latchedEmbedUrl.isNotEmpty) {
          _latchedEmbedUrl = '';
          _sessionNonce++;
        }
        return RepaintBoundary(child: _buildNoStreamState(context));
      }

      // Live state: keep last good URL latched; initialize webview once per live session.
      final webUrl = _latchedEmbedUrl;
      return RepaintBoundary(
        child: StreamWebView(
          key: ValueKey('${widget.streamViewKey}_$_sessionNonce'),
          url: webUrl,
          height: widget.height,
          cacheKey: widget.platformKey,
          onStreamReady: (runningUrl) {
            widget.onStreamReady?.call(widget.platformKey, runningUrl);
          },
          muted: widget.muted || widget.globalMuted,
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
    this.globalMuted = false,
    this.onStreamReady,
  });

  final double streamPreviewHeight;
  final bool globalMuted;
  final void Function(String platformKey, String runningUrl)? onStreamReady;

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
                globalMuted: globalMuted,
                streamViewKey: ValueKey('stream_single_${_platforms[i]}'),
                onStreamReady: onStreamReady,
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
    this.globalMuted = false,
    this.onStreamReady,
  });

  final double streamPreviewHeight;
  final bool globalMuted;
  final void Function(String platformKey, String runningUrl)? onStreamReady;

  static const _platforms = <String>['twitch', 'kick', 'youtube'];

  @override
  Widget build(BuildContext context) {
    final tileGap = 8.w;
    const topFlex = 56;
    const bottomFlex = 44;
    final chatCtrl = Get.find<ChatController>();

    Widget tile({
      required String platform,
      required BorderRadius radius,
      required double height,
    }) {
      return Obx(() {
        final runningUrl = chatCtrl.urlForPlatform(platform)?.trim() ?? '';
        final canOpenFullscreen =
            chatCtrl.isPlatformLive(platform) && runningUrl.isNotEmpty;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canOpenFullscreen
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _FullScreenStreamWebViewPage(
                        platformKey: platform,
                        url: runningUrl,
                        onStreamReady: onStreamReady,
                      ),
                    ),
                  );
                }
              : null,
          child: ClipRRect(
            borderRadius: radius,
            child: AbsorbPointer(
              // Multi-preview tiles should not consume web gestures directly.
              absorbing: true,
              child: _LiveStreamPlatformSlot(
                platformKey: platform,
                height: height,
                muted: false,
                globalMuted: globalMuted,
                streamViewKey: ValueKey('stream_$platform'),
                onStreamReady: onStreamReady,
              ),
            ),
          ),
        );
      });
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

class _FullScreenStreamWebViewPage extends StatelessWidget {
  const _FullScreenStreamWebViewPage({
    required this.platformKey,
    required this.url,
    this.onStreamReady,
  });

  final String platformKey;
  final String url;
  final void Function(String platformKey, String runningUrl)? onStreamReady;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return StreamWebView(
                  url: url,
                  height: constraints.maxHeight,
                  cacheKey: 'fullscreen_$platformKey',
                  muted: false,
                  streamExpectedLive: true,
                  onStreamReady: (runningUrl) {
                    onStreamReady?.call(platformKey, runningUrl);
                  },
                );
              },
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
