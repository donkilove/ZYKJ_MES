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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(widget.entryUrl);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
