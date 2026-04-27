import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';

class PluginHostSidebar extends StatelessWidget {
  const PluginHostSidebar({super.key, required this.controller});

  final PluginHostController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MesSectionCard(
        title: '插件中心',
        subtitle: '选择插件并打开独立工作区。',
        expandChild: true,
        child: controller.loading
            ? const MesLoadingState(label: '插件加载中...')
            : controller.plugins.isEmpty
            ? const Center(
                child: MesEmptyState(
                  title: '未发现插件',
                  description: '请检查插件目录或安装状态。',
                ),
              )
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
                        : () {
                            controller.openPlugin(pluginId);
                          },
                  );
                },
              ),
      ),
    );
  }
}
