import 'package:flutter/material.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_host_view_state.dart';
import 'package:mes_client/features/plugin_host/models/plugin_session.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';

class PluginHostController extends ChangeNotifier {
  PluginHostController({
    required PluginCatalogService catalogService,
    required PluginProcessService processService,
    required PluginRuntimeLocator runtimeLocator,
  }) : _catalogService = catalogService,
       _processService = processService,
       _runtimeLocator = runtimeLocator;

  final PluginCatalogService _catalogService;
  final PluginProcessService _processService;
  final PluginRuntimeLocator _runtimeLocator;

  List<PluginCatalogItem> _plugins = const [];
  bool _loading = false;
  String? _selectedPluginId;
  final Map<String, PluginSession> _sessions = <String, PluginSession>{};
  PluginHostViewState _viewState = const PluginHostViewState();
  int _openSequence = 0;

  List<PluginCatalogItem> get plugins => _plugins;
  bool get loading => _loading;
  String? get selectedPluginId => _selectedPluginId;
  PluginHostViewState get viewState => _viewState;
  PluginSession? get activeSession => _selectedPluginId == null
      ? null
      : _sessions[_selectedPluginId];

  PluginCatalogItem? get selectedPlugin {
    for (final plugin in _plugins) {
      if (plugin.manifest?.id == _selectedPluginId) {
        return plugin;
      }
    }
    return null;
  }

  Future<void> loadCatalog() async {
    _loading = true;
    notifyListeners();
    _plugins = await _catalogService.scan();
    _loading = false;
    notifyListeners();
  }

  void selectPlugin(String pluginId) {
    if (_selectedPluginId == pluginId) {
      return;
    }
    _selectedPluginId = pluginId;
    notifyListeners();
  }

  void debugInjectSession(PluginSession session) {
    _sessions[session.pluginId] = session;
    _selectedPluginId = session.pluginId;
    _viewState = _viewState.copyWith(
      phase: PluginHostPhase.running,
      focusedPluginId: session.pluginId,
      statusTitle: '${_displayNameFor(session.pluginId)}运行中',
      statusMessage: '插件页面已就绪。',
      errorMessage: null,
    );
    notifyListeners();
  }

  void debugInjectRunningSession(PluginSession session) {
    debugInjectSession(session);
  }

  Future<void> openPlugin(String pluginId) async {
    final running = _sessions[pluginId];
    if (running != null) {
      _selectedPluginId = pluginId;
      _viewState = _viewState.copyWith(
        phase: PluginHostPhase.running,
        focusedPluginId: pluginId,
        statusTitle: '${_displayNameFor(pluginId)}运行中',
        statusMessage: '插件页面已就绪。',
        errorMessage: null,
      );
      notifyListeners();
      return;
    }

    final currentSequence = ++_openSequence;
    _selectedPluginId = pluginId;
    _viewState = _viewState.copyWith(
      phase: PluginHostPhase.starting,
      focusedPluginId: pluginId,
      statusTitle: '正在启动${_displayNameFor(pluginId)}',
      statusMessage: '宿主正在拉起插件进程并等待页面就绪',
      errorMessage: null,
    );
    notifyListeners();

    final plugin = _plugins.where((item) => item.manifest?.id == pluginId).firstOrNull;
    if (plugin == null || plugin.manifest == null) {
      _viewState = _viewState.copyWith(
        phase: PluginHostPhase.failed,
        focusedPluginId: pluginId,
        statusTitle: '${_displayNameFor(pluginId)}启动失败',
        statusMessage: '宿主未找到可用插件清单。',
        errorMessage: 'plugin manifest missing',
      );
      notifyListeners();
      return;
    }

    final pythonExecutable = _runtimeLocator.resolvePythonExecutable();
    final runtimeRoot = pythonExecutable.substring(
      0,
      pythonExecutable.length - r'\python.exe'.length,
    );

    try {
      final started = await _processService.start(
        plugin: plugin,
        pythonExecutable: pythonExecutable,
        runtimeRoot: runtimeRoot,
      );
      if (currentSequence != _openSequence) {
        return;
      }
      _sessions[pluginId] = started;
      _viewState = _viewState.copyWith(
        phase: PluginHostPhase.running,
        focusedPluginId: pluginId,
        statusTitle: '${_displayNameFor(pluginId)}运行中',
        statusMessage: '插件页面已就绪。',
        errorMessage: null,
      );
    } catch (error) {
      if (currentSequence != _openSequence) {
        return;
      }
      _viewState = _viewState.copyWith(
        phase: PluginHostPhase.failed,
        focusedPluginId: pluginId,
        statusTitle: '${_displayNameFor(pluginId)}启动失败',
        statusMessage: '宿主未能完成插件启动。',
        errorMessage: error.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> closePlugin(String pluginId) async {
    _openSequence += 1;
    final session = _sessions.remove(pluginId);
    if (session != null) {
      await _processService.stop(session);
    }
    if (_selectedPluginId == pluginId) {
      _selectedPluginId = null;
      _viewState = const PluginHostViewState();
    }
    notifyListeners();
  }

  Future<void> restartPlugin(String pluginId) async {
    final existingSession = _sessions[pluginId];
    if (existingSession == null) {
      return;
    }
    await _processService.stop(existingSession);
    final plugin = _plugins.where((item) => item.manifest?.id == pluginId).firstOrNull;
    if (plugin == null || plugin.manifest == null) {
      _sessions.remove(pluginId);
      if (_selectedPluginId == pluginId) {
        _selectedPluginId = null;
      }
      notifyListeners();
      return;
    }
    final pythonExecutable = _runtimeLocator.resolvePythonExecutable();
    final runtimeRoot = pythonExecutable.substring(
      0,
      pythonExecutable.length - r'\python.exe'.length,
    );
    final restarted = await _processService.start(
      plugin: plugin,
      pythonExecutable: pythonExecutable,
      runtimeRoot: runtimeRoot,
    );
    _sessions[pluginId] = restarted;
    _selectedPluginId = pluginId;
    _viewState = _viewState.copyWith(
      phase: PluginHostPhase.running,
      focusedPluginId: pluginId,
      statusTitle: '${_displayNameFor(pluginId)}运行中',
      statusMessage: '插件页面已就绪。',
      errorMessage: null,
    );
    notifyListeners();
  }

  String _displayNameFor(String pluginId) {
    final plugin = _plugins.where((item) => item.manifest?.id == pluginId).firstOrNull;
    return plugin?.manifest?.name ?? pluginId;
  }
}
