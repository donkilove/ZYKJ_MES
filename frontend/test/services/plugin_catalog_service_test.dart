import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('scan 会读取合法 manifest 并返回 ready 状态', () async {
    final root = await Directory.systemTemp.createTemp('mes_plugin_scan_');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final pluginDir = Directory(p.join(root.path, 'serial_assistant'))
      ..createSync(recursive: true);
    await File(p.join(pluginDir.path, 'manifest.json')).writeAsString(
      jsonEncode({
        'id': 'serial_assistant',
        'name': '串口助手',
        'version': '0.1.0',
        'entry': {'type': 'python', 'script': 'launcher.py'},
        'ui': {'type': 'web', 'mode': 'embedded'},
        'runtime': {'python': '3.14', 'arch': 'win_amd64'},
        'dependencies': {
          'mode': 'plugin_local',
          'paths': ['vendor', 'app'],
        },
        'permissions': ['serial'],
        'lifecycle': {
          'startup_timeout_sec': 15,
          'heartbeat_interval_sec': 5,
        },
      }),
    );

    final service = PluginCatalogService(
      pluginRootResolver: () async => root.path,
    );

    final items = await service.scan();

    expect(items, hasLength(1));
    expect(items.single.manifest?.id, 'serial_assistant');
    expect(items.single.status, PluginCatalogItemStatus.ready);
  });

  test('scan 遇到缺失 script 的 manifest 时返回 invalid 状态', () async {
    final root = await Directory.systemTemp.createTemp('mes_plugin_invalid_');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final pluginDir = Directory(p.join(root.path, 'broken_plugin'))
      ..createSync(recursive: true);
    await File(p.join(pluginDir.path, 'manifest.json')).writeAsString(
      jsonEncode({
        'id': 'broken_plugin',
        'name': '损坏插件',
        'version': '0.1.0',
        'entry': {'type': 'python'},
        'ui': {'type': 'web', 'mode': 'embedded'},
        'runtime': {'python': '3.14', 'arch': 'win_amd64'},
        'dependencies': {
          'mode': 'plugin_local',
          'paths': <String>[],
        },
        'permissions': <String>[],
        'lifecycle': {
          'startup_timeout_sec': 15,
          'heartbeat_interval_sec': 5,
        },
      }),
    );

    final service = PluginCatalogService(
      pluginRootResolver: () async => root.path,
    );

    final items = await service.scan();

    expect(items, hasLength(1));
    expect(items.single.status, PluginCatalogItemStatus.invalid);
    expect(items.single.errorMessage, contains('entry.script'));
  });
}
