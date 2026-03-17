import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Renders the live stream using the Flutter video_player in the same height
/// container as the previous stream image. When [url] is null or empty,
/// shows a black placeholder.
class StreamVideoPlayer extends StatefulWidget {
  const StreamVideoPlayer({
    super.key,
    required this.url,
    required this.height,
  });

  final String url;
  final double height;

  @override
  State<StreamVideoPlayer> createState() => _StreamVideoPlayerState();
}

class _StreamVideoPlayerState extends State<StreamVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ownsController = true;

  @override
  void initState() {
    super.initState();
    if (widget.url.trim().isNotEmpty) {
      _initController(widget.url);
    }
  }

  Future<void> _initController(String url) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ownsController = true;
      });
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _controller = null);
    }
  }

  @override
  void didUpdateWidget(StreamVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      if (widget.url.trim().isEmpty) {
        _controller?.dispose();
        _controller = null;
      } else {
        _controller?.dispose();
        _initController(widget.url);
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Icon(Icons.videocam_off, color: Colors.white38, size: 48),
        ),
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return SizedBox(
        height: widget.height,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    return Container(
      height: widget.height,
      width: double.infinity,
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
