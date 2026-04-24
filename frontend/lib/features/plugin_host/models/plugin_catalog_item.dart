import 'dart:io';

import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';

enum PluginCatalogItemStatus { ready, invalid }

class PluginCatalogItem {
  const PluginCatalogItem({
    required this.directory,
    required this.status,
    this.manifest,
    this.errorMessage,
  });

  final Directory directory;
  final PluginManifest? manifest;
  final PluginCatalogItemStatus status;
  final String? errorMessage;
}
