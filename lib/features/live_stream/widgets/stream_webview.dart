import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders the live stream in the same container as the stream images.
/// When [url] is null or empty, shows a black placeholder.
class StreamWebView extends StatefulWidget {
  const StreamWebView({
    super.key,
    required this.url,
    required this.height,
  });

  final String url;
  final double height;

  @override
  State<StreamWebView> createState() => _StreamWebViewState();
}

class _StreamWebViewState extends State<StreamWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {},
        ),
      );
    if (widget.url.trim().isNotEmpty) {
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  void didUpdateWidget(StreamWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url && widget.url.trim().isNotEmpty) {
      _controller.loadRequest(Uri.parse(widget.url));
    }
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
    return SizedBox(
      height: widget.height,
      child: WebViewWidget(controller: _controller),
    );
  }
}
