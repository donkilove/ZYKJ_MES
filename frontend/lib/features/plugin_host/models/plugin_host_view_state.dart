const Object _pluginHostUnset = Object();

enum PluginHostPhase { idle, starting, running, failed }

class PluginHostViewState {
  const PluginHostViewState({
    this.phase = PluginHostPhase.idle,
    this.focusedPluginId,
    this.statusTitle = '选择一个插件以打开工作区',
    this.statusMessage = '',
    this.errorMessage,
  });

  final PluginHostPhase phase;
  final String? focusedPluginId;
  final String statusTitle;
  final String statusMessage;
  final String? errorMessage;

  PluginHostViewState copyWith({
    PluginHostPhase? phase,
    Object? focusedPluginId = _pluginHostUnset,
    String? statusTitle,
    String? statusMessage,
    Object? errorMessage = _pluginHostUnset,
  }) {
    return PluginHostViewState(
      phase: phase ?? this.phase,
      focusedPluginId: identical(focusedPluginId, _pluginHostUnset)
          ? this.focusedPluginId
          : focusedPluginId as String?,
      statusTitle: statusTitle ?? this.statusTitle,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: identical(errorMessage, _pluginHostUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
