import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

class PluginHostWebviewPanel extends StatefulWidget {
  const PluginHostWebviewPanel({super.key, required this.entryUrl});

  final Uri entryUrl;

  @override
  State<PluginHostWebviewPanel> createState() => _PluginHostWebviewPanelState();
}

class _PluginHostWebviewPanelState extends State<PluginHostWebviewPanel> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_initializeWebview());
  }

  @override
  void didUpdateWidget(covariant PluginHostWebviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryUrl == widget.entryUrl) {
      return;
    }
    unawaited(_controller.loadRequest(widget.entryUrl));
  }

  Future<void> _initializeWebview() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(Colors.transparent);
    await _controller.loadRequest(widget.entryUrl);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RepaintBoundary(child: WebViewWidget(controller: _controller)),
    );
  }
}
