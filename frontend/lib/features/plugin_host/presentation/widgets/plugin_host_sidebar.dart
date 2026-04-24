import 'package:flutter/material.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';

class PluginHostSidebar extends StatelessWidget {
  const PluginHostSidebar({super.key, required this.controller});

  final PluginHostController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '插件中心',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : controller.plugins.isEmpty
                ? const Center(child: Text('未发现插件，请检查插件目录。'))
                : ListView.builder(
                    itemCount: controller.plugins.length,
                    itemBuilder: (context, index) {
                      final item = controller.plugins[index];
                      final manifest = item.manifest;
                      final pluginId = manifest?.id;
                      return ListTile(
                        selected: pluginId != null &&
                            pluginId == controller.selectedPluginId,
                        leading: const Icon(Icons.extension_rounded),
                        title: Text(manifest?.name ?? '无效插件'),
                        subtitle: Text(manifest?.version ?? 'manifest 无效'),
                        onTap: pluginId == null
                            ? null
                            : () => controller.selectPlugin(pluginId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
