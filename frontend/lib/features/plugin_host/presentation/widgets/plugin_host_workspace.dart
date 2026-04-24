import 'package:flutter/material.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';

class PluginHostWorkspace extends StatelessWidget {
  const PluginHostWorkspace({super.key, required this.controller});

  final PluginHostController controller;

  @override
  Widget build(BuildContext context) {
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
