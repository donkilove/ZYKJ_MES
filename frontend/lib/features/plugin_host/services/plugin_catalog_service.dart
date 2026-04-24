import 'dart:convert';
import 'dart:io';

import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';
import 'package:path/path.dart' as p;

class PluginCatalogService {
  PluginCatalogService({required this.pluginRootResolver});

  final Future<String> Function() pluginRootResolver;

  Future<List<PluginCatalogItem>> scan() async {
    final pluginRootPath = await pluginRootResolver();
    final pluginRoot = Directory(pluginRootPath);
    if (!await pluginRoot.exists()) {
      return const <PluginCatalogItem>[];
    }

    final items = <PluginCatalogItem>[];
    await for (final entity in pluginRoot.list()) {
      if (entity is! Directory) {
        continue;
      }
      final manifestFile = File(p.join(entity.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        continue;
      }

      try {
        final raw = await manifestFile.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final manifest = PluginManifest.fromJson(json);
        items.add(
          PluginCatalogItem(
            directory: entity,
            manifest: manifest,
            status: PluginCatalogItemStatus.ready,
          ),
        );
      } catch (error) {
        items.add(
          PluginCatalogItem(
            directory: entity,
            status: PluginCatalogItemStatus.invalid,
            errorMessage: error.toString(),
          ),
        );
      }
    }

    items.sort((left, right) {
      final leftName = left.manifest?.name ?? left.directory.path;
      final rightName = right.manifest?.name ?? right.directory.path;
      return leftName.compareTo(rightName);
    });
    return items;
  }
}
