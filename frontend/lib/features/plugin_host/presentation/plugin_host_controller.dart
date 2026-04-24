import 'package:flutter/material.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
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

  List<PluginCatalogItem> get plugins => _plugins;
  bool get loading => _loading;
  String? get selectedPluginId => _selectedPluginId;

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
}
