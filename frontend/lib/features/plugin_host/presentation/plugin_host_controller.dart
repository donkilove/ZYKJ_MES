import 'package:flutter/material.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
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

  List<PluginCatalogItem> get plugins => _plugins;
  bool get loading => _loading;
  String? get selectedPluginId => _selectedPluginId;
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
    notifyListeners();
  }

  Future<void> closePlugin(String pluginId) async {
    final session = _sessions.remove(pluginId);
    if (session != null) {
      await _processService.stop(session);
    }
    if (_selectedPluginId == pluginId) {
      _selectedPluginId = null;
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
    notifyListeners();
  }
}
