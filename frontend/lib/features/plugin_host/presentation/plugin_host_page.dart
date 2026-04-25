import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/presentation/widgets/plugin_host_sidebar.dart';
import 'package:mes_client/features/plugin_host/presentation/widgets/plugin_host_workspace.dart';

class PluginHostPage extends StatefulWidget {
  const PluginHostPage({
    super.key,
    required this.controller,
    required this.webviewBuilder,
  });

  final PluginHostController controller;
  final Widget Function(Uri entryUrl) webviewBuilder;

  @override
  State<PluginHostPage> createState() => _PluginHostPageState();
}

class _PluginHostPageState extends State<PluginHostPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.loadCatalog());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Row(
          children: [
            SizedBox(
              width: 300,
              child: PluginHostSidebar(controller: widget.controller),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: PluginHostWorkspace(
                controller: widget.controller,
                webviewBuilder: widget.webviewBuilder,
              ),
            ),
          ],
        );
      },
    );
  }
}
