import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/plugin_host/models/plugin_session.dart';
import 'package:mes_client/features/plugin_host/models/plugin_host_view_state.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';

class PluginHostWorkspace extends StatefulWidget {
  const PluginHostWorkspace({
    super.key,
    required this.controller,
    required this.webviewBuilder,
  });

  final PluginHostController controller;
  final Widget Function(Uri entryUrl) webviewBuilder;

  @override
  State<PluginHostWorkspace> createState() => _PluginHostWorkspaceState();
}

class _PluginHostWorkspaceState extends State<PluginHostWorkspace> {
  String? _cachedSessionKey;
  Widget? _cachedWebview;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final viewState = controller.viewState;
    final isFullscreen = controller.isFullscreenActive;
    if (viewState.phase == PluginHostPhase.starting) {
      _clearCachedWebview();
      return _PluginHostStatusPanel(
        title: viewState.statusTitle,
        message: viewState.statusMessage,
        actions: [
          TextButton(
            onPressed: () {
              final pluginId = viewState.focusedPluginId;
              if (pluginId != null) {
                controller.closePlugin(pluginId);
              }
            },
            child: const Text('取消启动'),
          ),
        ],
      );
    }

    if (viewState.phase == PluginHostPhase.failed) {
      _clearCachedWebview();
      return _PluginHostStatusPanel(
        title: viewState.statusTitle,
        message: viewState.errorMessage ?? viewState.statusMessage,
        actions: [
          TextButton(
            onPressed: () {
              final pluginId = viewState.focusedPluginId;
              if (pluginId != null) {
                controller.openPlugin(pluginId);
              }
            },
            child: const Text('重试'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              final pluginId = viewState.focusedPluginId;
              if (pluginId != null) {
                controller.closePlugin(pluginId);
              }
            },
            child: const Text('关闭插件'),
          ),
        ],
      );
    }

    final activeSession = controller.activeSession;
    if (activeSession != null) {
      final content = _resolveWebview(activeSession);
      final workspaceBackground = Theme.of(context).scaffoldBackgroundColor;
      final toolbar = Padding(
        padding: EdgeInsets.fromLTRB(
          isFullscreen ? 12 : 16,
          12,
          isFullscreen ? 12 : 16,
          12,
        ),
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
              onPressed: controller.toggleFullscreen,
              child: Text(isFullscreen ? '退出全屏' : '全屏'),
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
      );
      final contentPane = ColoredBox(
        color: workspaceBackground,
        child: RepaintBoundary(child: content),
      );
      if (isFullscreen) {
        return Column(
          children: [
            toolbar,
            const Divider(height: 1),
            Expanded(child: contentPane),
          ],
        );
      }
      return Padding(
        padding: const EdgeInsets.all(16),
        child: MesSectionCard(
          title: '插件运行中',
          subtitle: activeSession.pluginId,
          expandChild: true,
          child: Column(
            children: [
              toolbar,
              const Divider(height: 1),
              Expanded(child: contentPane),
            ],
          ),
        ),
      );
    }

    _clearCachedWebview();
    final selectedPlugin = controller.selectedPlugin;
    if (selectedPlugin == null) {
      return const Center(
        child: MesEmptyState(
          title: '未选择插件',
          description: '请先从左侧列表中选择一个插件。',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: MesSectionCard(
        title: selectedPlugin.manifest?.name ?? '未知插件',
        subtitle: '第一阶段工作区已接入，后续在这里承载插件会话与内嵌页面。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本：${selectedPlugin.manifest?.version ?? '-'}'),
          ],
        ),
      ),
    );
  }

  Widget _resolveWebview(PluginSession activeSession) {
    final sessionKey =
        '${activeSession.pluginId}:${activeSession.pid}:${activeSession.entryUrl}';
    if (_cachedSessionKey == sessionKey && _cachedWebview != null) {
      return _cachedWebview!;
    }

    _cachedSessionKey = sessionKey;
    _cachedWebview = KeyedSubtree(
      key: ValueKey('plugin-host-webview-$sessionKey'),
      child: widget.webviewBuilder(activeSession.entryUrl),
    );
    return _cachedWebview!;
  }

  void _clearCachedWebview() {
    _cachedSessionKey = null;
    _cachedWebview = null;
  }
}

class _PluginHostStatusPanel extends StatelessWidget {
  const _PluginHostStatusPanel({
    required this.title,
    required this.message,
    this.actions = const <Widget>[],
  });

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: MesSectionCard(
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
