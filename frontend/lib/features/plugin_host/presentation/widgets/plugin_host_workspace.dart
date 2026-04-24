import 'package:flutter/material.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/presentation/widgets/plugin_host_webview_panel.dart';

class PluginHostWorkspace extends StatelessWidget {
  const PluginHostWorkspace({
    super.key,
    required this.controller,
    this.webviewBuilder,
  });

  final PluginHostController controller;
  final Widget Function(Uri entryUrl)? webviewBuilder;

  @override
  Widget build(BuildContext context) {
    final activeSession = controller.activeSession;
    if (activeSession != null) {
      final content =
          webviewBuilder?.call(activeSession.entryUrl) ??
          PluginHostWebviewPanel(entryUrl: activeSession.entryUrl);
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activeSession.pluginId,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        controller.restartPlugin(activeSession.pluginId);
                      },
                      child: const Text('重启插件'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        controller.closePlugin(activeSession.pluginId);
                      },
                      child: const Text('关闭插件'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    final selectedPlugin = controller.selectedPlugin;
    if (selectedPlugin == null) {
      return const Center(child: Text('选择一个插件以打开工作区'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedPlugin.manifest?.name ?? '未知插件',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text('版本：${selectedPlugin.manifest?.version ?? '-'}'),
              const SizedBox(height: 12),
              const Text('第一阶段工作区已接入，后续在这里承载插件会话与内嵌页面。'),
            ],
          ),
        ),
      ),
    );
  }
}
