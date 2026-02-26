import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/page_visibility_models.dart';
import '../services/api_exception.dart';
import '../services/page_visibility_service.dart';

class PageVisibilityConfigPage extends StatefulWidget {
  const PageVisibilityConfigPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.onConfigSaved,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final VoidCallback? onConfigSaved;

  @override
  State<PageVisibilityConfigPage> createState() =>
      _PageVisibilityConfigPageState();
}

class _PageVisibilityConfigPageState extends State<PageVisibilityConfigPage> {
  late final PageVisibilityService _service;

  bool _loading = false;
  bool _saving = false;
  bool _catalogFallback = false;
  String _message = '';

  List<PageCatalogItem> _catalog = const [];
  List<String> _roleCodes = const [];
  Map<String, String> _roleNames = const {};
  final Map<String, bool> _values = {};
  final Map<String, bool> _editable = {};

  @override
  void initState() {
    super.initState();
    _service = PageVisibilityService(widget.session);
    _loadData();
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  String _key(String roleCode, String pageCode) => '$roleCode|$pageCode';

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _message = '';
      _catalogFallback = false;
    });

    List<PageCatalogItem> catalog = const [];
    try {
      catalog = await _service.listPageCatalog();
    } catch (_) {
      catalog = fallbackPageCatalog;
      _catalogFallback = true;
    }

    try {
      final configItems = await _service.getVisibilityConfig();
      if (!mounted) {
        return;
      }

      final roleNames = <String, String>{};
      final roleCodes = <String>[];
      final values = <String, bool>{};
      final editable = <String, bool>{};

      for (final item in configItems) {
        roleNames[item.roleCode] = item.roleName;
        if (!roleCodes.contains(item.roleCode)) {
          roleCodes.add(item.roleCode);
        }
        final key = _key(item.roleCode, item.pageCode);
        values[key] = item.isVisible;
        editable[key] = item.editable;
      }

      setState(() {
        _catalog = [...catalog]..sort((a, b) => a.sortOrder - b.sortOrder);
        _roleCodes = roleCodes;
        _roleNames = roleNames;
        _values
          ..clear()
          ..addAll(values);
        _editable
          ..clear()
          ..addAll(editable);
        if (_catalogFallback) {
          _message = '后端页面目录不可达，已使用本地目录兜底。';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载页面可见性配置失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final updates = <PageVisibilityConfigUpdateItem>[];
    for (final roleCode in _roleCodes) {
      for (final page in _catalog) {
        final key = _key(roleCode, page.code);
        if (!(_editable[key] ?? !page.alwaysVisible)) {
          continue;
        }
        updates.add(
          PageVisibilityConfigUpdateItem(
            roleCode: roleCode,
            pageCode: page.code,
            isVisible: _values[key] ?? false,
          ),
        );
      }
    }

    setState(() {
      _saving = true;
      _message = '';
    });

    try {
      final updatedCount = await _service.updateVisibilityConfig(items: updates);
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '保存成功，已更新 $updatedCount 项配置。';
      });
      widget.onConfigSaved?.call();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '保存失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '页面可见性配置',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadData,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_loading || _saving) ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('保存配置'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _message.startsWith('保存成功')
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _catalog.isEmpty
                    ? const Center(child: Text('暂无可配置页面'))
                    : ListView.builder(
                        itemCount: _catalog.length,
                        itemBuilder: (context, index) {
                          final page = _catalog[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${page.name} (${page.code})',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    page.parentCode == null
                                        ? '类型：侧边栏页面'
                                        : '类型：Tab 页面（父级：${page.parentCode}）',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  ..._roleCodes.map((roleCode) {
                                    final key = _key(roleCode, page.code);
                                    final canEdit =
                                        _editable[key] ?? !page.alwaysVisible;
                                    final value = _values[key] ?? false;
                                    final title = _roleNames[roleCode] ?? roleCode;
                                    return SwitchListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(title),
                                      subtitle: Text(roleCode),
                                      value: value,
                                      onChanged: canEdit
                                          ? (checked) {
                                              setState(() {
                                                _values[key] = checked;
                                              });
                                            }
                                          : null,
                                    );
                                  }),
                                  if (page.alwaysVisible)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        '首页固定可见，不可关闭。',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
