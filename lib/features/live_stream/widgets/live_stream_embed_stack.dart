import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../controllers/chat_controller.dart';
import '../../../core/localization/l10n.dart';
import 'stream_embed_url_utils.dart';
import 'stream_webview.dart';

/// One platform's embed: keeps the last non-empty embed URL across tab switches and
/// brief `platformLive` / map gaps so [StreamWebView] is not sent `''` (idle) unless
/// the platform is **explicitly** offline (`platformLive[key] == false`).
class _LiveStreamPlatformSlot extends StatefulWidget {
  const _LiveStreamPlatformSlot({
    required this.platformKey,
    required this.height,
    required this.muted,
    required this.globalMuted,
    required this.streamViewKey,
    required this.cacheScope,
    this.onStreamReady,

    /// When true, sizes the embed from [LayoutBuilder] max width/height (fills tile/stack).
    this.fillConstraints = false,
    this.useEagerGestureArena = true,
    this.suppressNativeFullscreen = false,
  });

  final String platformKey;
  final double height;
  final bool muted;
  final bool globalMuted;
  final Key streamViewKey;
  final String cacheScope;
  final void Function(String platformKey, String runningUrl)? onStreamReady;
  final bool fillConstraints;
  final bool useEagerGestureArena;
  final bool suppressNativeFullscreen;

  @override
  State<_LiveStreamPlatformSlot> createState() =>
      _LiveStreamPlatformSlotState();
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
          Icon(Icons.videocam_off, color: Colors.white38, size: 28.sp),
          SizedBox(height: 5.h),
          Text(
            context.l10n.noStreamAtTheMoment,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13.sp),
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

      Widget embed(double w, double h) {
        final platform = widget.platformKey.toLowerCase().trim();
        final cacheKey =
            platform == 'kick' ? '${widget.cacheScope}_$platform' : platform;
        return StreamWebView(
          key: ValueKey('${widget.streamViewKey}_$_sessionNonce'),
          url: webUrl,
          width: w,
          height: h,
          cacheKey: cacheKey,
          onStreamReady: (runningUrl) {
            widget.onStreamReady?.call(widget.platformKey, runningUrl);
          },
          muted: widget.muted || widget.globalMuted,
          streamExpectedLive: liveExpected,
          useEagerGestureArena: widget.useEagerGestureArena,
          suppressNativeFullscreen: widget.suppressNativeFullscreen,
        );
      }

      if (widget.fillConstraints) {
        return RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              if (w <= 0 || h <= 0) {
                return const ColoredBox(color: Colors.black);
              }
              return embed(w, h);
            },
          ),
        );
      }

      return RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, c) {
            final w =
                c.maxWidth.isFinite && c.maxWidth > 0
                    ? c.maxWidth
                    : MediaQuery.sizeOf(context).width;
            return embed(w, widget.height);
          },
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

  void _openPlatformFullscreenRoute(
    BuildContext context,
    String platformKey,
    String runningUrl,
  ) {
    if (!context.mounted) return;
    final url = runningUrl.trim();
    if (url.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => _FullScreenStreamWebViewPage(
              platformKey: platformKey,
              url: url,
              onStreamReady: onStreamReady,
            ),
      ),
    );
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
            Builder(
              builder: (context) {
                final platform = _platforms[i];
                final slot = _LiveStreamPlatformSlot(
                  platformKey: platform,
                  height: streamPreviewHeight,
                  muted: i != index,
                  globalMuted: globalMuted,
                  streamViewKey: ValueKey('stream_single_$platform'),
                  cacheScope: 'single',
                  onStreamReady: onStreamReady,
                  fillConstraints: true,
                  useEagerGestureArena: true,
                  suppressNativeFullscreen: platform == 'twitch',
                );
                final child =
                    (platform != 'twitch' && platform != 'kick')
                        ? slot
                        : Obx(() {
                          final url =
                              chatCtrl.urlForPlatform(platform)?.trim() ?? '';
                          final canOpen =
                              chatCtrl.isPlatformLive(platform) &&
                              url.isNotEmpty &&
                              chatCtrl.isPlatformStreamEmbedReadyForChat(
                                platform,
                              );
                          return Stack(
                            fit: StackFit.expand,
                            clipBehavior: Clip.hardEdge,
                            children: [
                              slot,
                              if (canOpen && i == index)
                                Positioned(
                                  bottom: 8.h,
                                  right: 8.w,
                                  child: PointerInterceptor(
                                    child: Material(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20.r),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap:
                                            () => _openPlatformFullscreenRoute(
                                              context,
                                              platform,
                                              url,
                                            ),
                                        child: Padding(
                                          padding: EdgeInsets.all(8.w),
                                          child: Icon(
                                            Icons.fullscreen,
                                            color: Colors.white,
                                            size: 22.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        });
                return IgnorePointer(ignoring: i != index, child: child);
              },
            ),
        ],
      );
    });
  }
}

/// Multi-preview tiles; each slot's [_LiveStreamPlatformSlot] uses [Obx] for live/url.
/// Twitch only: bottom-right in-app fullscreen (embed controls remain available).
/// Kick/YouTube: fullscreen only via the embed's own UI.
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

  void _openPlatformFullscreenRoute(
    BuildContext context,
    String platformKey,
    String runningUrl,
  ) {
    if (!context.mounted) return;
    final url = runningUrl.trim();
    if (url.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => _FullScreenStreamWebViewPage(
              platformKey: platformKey,
              url: url,
              onStreamReady: onStreamReady,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tileGap = 8.w;
    const topFlex = 56;
    const bottomFlex = 44;

    Widget tile({required String platform, required BorderRadius radius}) {
      final slot = _LiveStreamPlatformSlot(
        platformKey: platform,
        height: 1,
        muted: false,
        globalMuted: globalMuted,
        streamViewKey: ValueKey('stream_$platform'),
        cacheScope: 'multi',
        onStreamReady: onStreamReady,
        fillConstraints: true,
        useEagerGestureArena: true,
        suppressNativeFullscreen: platform == 'twitch',
      );

      if (platform != 'twitch') {
        if (platform != 'kick') {
          return ClipRRect(
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: slot,
          );
        }
        return ClipRRect(
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Obx(() {
            final chatCtrl = Get.find<ChatController>();
            final url = chatCtrl.urlForPlatform('kick')?.trim() ?? '';
            final canOpen =
                chatCtrl.isPlatformLive('kick') &&
                url.isNotEmpty &&
                chatCtrl.isPlatformStreamEmbedReadyForChat('kick');
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                slot,
                if (canOpen)
                  Positioned(
                    bottom: 8.h,
                    right: 8.w,
                    child: PointerInterceptor(
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20.r),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap:
                              () => _openPlatformFullscreenRoute(
                                context,
                                'kick',
                                url,
                              ),
                          child: Padding(
                            padding: EdgeInsets.all(8.w),
                            child: Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 22.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        );
      }

      return ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Obx(() {
          final chatCtrl = Get.find<ChatController>();
          final url = chatCtrl.urlForPlatform('twitch')?.trim() ?? '';
          final canOpen =
              chatCtrl.isPlatformLive('twitch') &&
              url.isNotEmpty &&
              chatCtrl.isPlatformStreamEmbedReadyForChat('twitch');
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              slot,
              if (canOpen)
                Positioned(
                  bottom: 8.h,
                  right: 8.w,
                  child: PointerInterceptor(
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20.r),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap:
                            () => _openPlatformFullscreenRoute(
                              context,
                              'twitch',
                              url,
                            ),
                        child: Padding(
                          padding: EdgeInsets.all(8.w),
                          child: Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 22.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
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
                  radius: BorderRadius.only(topLeft: Radius.circular(16.r)),
                ),
              ),
              SizedBox(width: tileGap),
              Expanded(
                child: tile(
                  platform: _platforms[1],
                  radius: BorderRadius.only(topRight: Radius.circular(16.r)),
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
          ),
        ),
      ],
    );
  }
}

class _FullScreenStreamWebViewPage extends StatefulWidget {
  const _FullScreenStreamWebViewPage({
    required this.platformKey,
    required this.url,
    this.onStreamReady,
  });

  final String platformKey;
  final String url;
  final void Function(String platformKey, String runningUrl)? onStreamReady;

  @override
  State<_FullScreenStreamWebViewPage> createState() =>
      _FullScreenStreamWebViewPageState();
}

class _FullScreenStreamWebViewPageState
    extends State<_FullScreenStreamWebViewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return StreamWebView(
                    url: widget.url,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    cacheKey: 'fullscreen_${widget.platformKey}',
                    muted: false,
                    streamExpectedLive: true,
                    suppressNativeFullscreen: true,
                    onStreamReady: (runningUrl) {
                      widget.onStreamReady?.call(
                        widget.platformKey,
                        runningUrl,
                      );
                    },
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                minimum: const EdgeInsets.all(8),
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
            ),
          ],
        ),
      ),
    );
  }
}
