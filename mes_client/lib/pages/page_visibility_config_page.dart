import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/page_visibility_models.dart';
import '../services/api_exception.dart';
import '../services/page_visibility_service.dart';

enum _SaveStatus { idle, dirty, saving, success, error }

class _TreeGroup {
  const _TreeGroup({required this.parent, required this.children});

  final PageCatalogItem parent;
  final List<PageCatalogItem> children;
}

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
  static const Duration _debounceDuration = Duration(seconds: 1);

  late final PageVisibilityService _service;

  bool _loading = false;
  bool _catalogFallback = false;
  String _message = '';

  List<PageCatalogItem> _catalog = const [];
  List<_TreeGroup> _groups = const [];
  List<String> _roleCodes = const [];
  Map<String, String> _roleNames = const {};

  final Map<String, bool> _draftValues = {};
  final Map<String, bool> _editable = {};
  final Set<String> _dirtyKeys = {};

  String? _selectedPageCode;
  final Set<String> _expandedParentCodes = {};

  Timer? _saveTimer;
  bool _saving = false;
  bool _saveQueued = false;
  DateTime? _lastSavedAt;
  String? _saveError;
  _SaveStatus _saveStatus = _SaveStatus.idle;

  @override
  void initState() {
    super.initState();
    _service = PageVisibilityService(widget.session);
    _loadData();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
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

  List<String>? _parseKey(String compositeKey) {
    final index = compositeKey.indexOf('|');
    if (index <= 0 || index >= compositeKey.length - 1) {
      return null;
    }
    final roleCode = compositeKey.substring(0, index);
    final pageCode = compositeKey.substring(index + 1);
    return [roleCode, pageCode];
  }

  PageCatalogItem? _findPageByCode(String? pageCode) {
    if (pageCode == null) {
      return null;
    }
    for (final page in _catalog) {
      if (page.code == pageCode) {
        return page;
      }
    }
    return null;
  }

  List<PageCatalogItem> _childrenOfParent(String parentCode) {
    for (final group in _groups) {
      if (group.parent.code == parentCode) {
        return group.children;
      }
    }
    return const [];
  }

  bool _isParentPage(PageCatalogItem page) => page.pageType == 'sidebar';

  bool _isChildBlockedByParent(String roleCode, PageCatalogItem page) {
    if (page.parentCode == null) {
      return false;
    }
    final parentVisible =
        _draftValues[_key(roleCode, page.parentCode!)] ?? false;
    return !parentVisible;
  }

  List<_TreeGroup> _buildTreeGroups(List<PageCatalogItem> catalog) {
    final sortedCatalog = [...catalog]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final parents = sortedCatalog.where((page) => page.pageType == 'sidebar');
    final tabs = sortedCatalog.where((page) => page.pageType == 'tab');

    final childrenByParent = <String, List<PageCatalogItem>>{};
    for (final tab in tabs) {
      final parentCode = tab.parentCode;
      if (parentCode == null) {
        continue;
      }
      childrenByParent.putIfAbsent(parentCode, () => []).add(tab);
    }

    final groups = <_TreeGroup>[];
    final consumedCodes = <String>{};

    for (final parent in parents) {
      final children = <PageCatalogItem>[
        ...(childrenByParent[parent.code] ?? const <PageCatalogItem>[]),
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      groups.add(_TreeGroup(parent: parent, children: children));
      consumedCodes.add(parent.code);
      consumedCodes.addAll(children.map((item) => item.code));
    }

    for (final page in sortedCatalog) {
      if (consumedCodes.contains(page.code)) {
        continue;
      }
      groups.add(_TreeGroup(parent: page, children: const []));
    }

    return groups;
  }

  Set<String> _applyParentChildConstraint({
    required Map<String, bool> values,
    required Map<String, bool> editable,
    required List<String> roleCodes,
    required List<_TreeGroup> groups,
  }) {
    final changed = <String>{};

    for (final roleCode in roleCodes) {
      for (final group in groups) {
        final parentKey = _key(roleCode, group.parent.code);
        final parentVisible = values[parentKey] ?? false;
        if (parentVisible) {
          continue;
        }

        for (final child in group.children) {
          final childKey = _key(roleCode, child.code);
          final canEdit = editable[childKey] ?? !child.alwaysVisible;
          if (!canEdit) {
            continue;
          }
          if ((values[childKey] ?? false) != false) {
            values[childKey] = false;
            changed.add(childKey);
          }
        }
      }
    }

    return changed;
  }

  Future<void> _loadData() async {
    _saveTimer?.cancel();

    setState(() {
      _loading = true;
      _message = '';
      _saveError = null;
      _catalogFallback = false;
      _saveQueued = false;
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

      final sortedCatalog = [...catalog]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final groups = _buildTreeGroups(sortedCatalog);

      final roleCodes = <String>[];
      final roleNames = <String, String>{};
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

      final changedByConstraint = _applyParentChildConstraint(
        values: values,
        editable: editable,
        roleCodes: roleCodes,
        groups: groups,
      );

      String? selectedPageCode = _selectedPageCode;
      final selectedExists = sortedCatalog.any(
        (page) => page.code == selectedPageCode,
      );
      if (!selectedExists) {
        selectedPageCode = groups.isNotEmpty
            ? groups.first.parent.code
            : (sortedCatalog.isNotEmpty ? sortedCatalog.first.code : null);
      }

      final expandedParentCodes = <String>{..._expandedParentCodes};
      if (selectedPageCode != null) {
        final selectedPage = sortedCatalog.firstWhere(
          (page) => page.code == selectedPageCode,
          orElse: () => sortedCatalog.first,
        );
        expandedParentCodes.add(selectedPage.parentCode ?? selectedPage.code);
      }

      setState(() {
        _catalog = sortedCatalog;
        _groups = groups;
        _roleCodes = roleCodes;
        _roleNames = roleNames;

        _draftValues
          ..clear()
          ..addAll(values);
        _editable
          ..clear()
          ..addAll(editable);

        _dirtyKeys
          ..clear()
          ..addAll(changedByConstraint);

        _selectedPageCode = selectedPageCode;

        _expandedParentCodes
          ..clear()
          ..addAll(expandedParentCodes);

        _saveStatus = _dirtyKeys.isNotEmpty
            ? _SaveStatus.dirty
            : _SaveStatus.idle;
        _saveError = null;
        _message = _catalogFallback ? '后端页面目录不可达，已使用本地目录兜底。' : '';
      });

      if (changedByConstraint.isNotEmpty) {
        _scheduleAutoSave();
      }
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

  void _scheduleAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounceDuration, () {
      _flushDirty();
    });
  }

  Future<void> _flushDirty() async {
    if (_dirtyKeys.isEmpty) {
      if (mounted && _saveStatus == _SaveStatus.dirty) {
        setState(() {
          _saveStatus = _SaveStatus.success;
        });
      }
      return;
    }

    if (_saving) {
      _saveQueued = true;
      return;
    }

    final dirtySnapshot = <String>{..._dirtyKeys};
    final submittedKeys = <String>{};
    final updates = <PageVisibilityConfigUpdateItem>[];

    for (final dirtyKey in dirtySnapshot) {
      final parsed = _parseKey(dirtyKey);
      if (parsed == null) {
        submittedKeys.add(dirtyKey);
        continue;
      }

      final roleCode = parsed[0];
      final pageCode = parsed[1];
      final page = _findPageByCode(pageCode);
      if (page == null) {
        submittedKeys.add(dirtyKey);
        continue;
      }

      final canEdit = _editable[dirtyKey] ?? !page.alwaysVisible;
      if (!canEdit) {
        submittedKeys.add(dirtyKey);
        continue;
      }

      updates.add(
        PageVisibilityConfigUpdateItem(
          roleCode: roleCode,
          pageCode: pageCode,
          isVisible: _draftValues[dirtyKey] ?? false,
        ),
      );
      submittedKeys.add(dirtyKey);
    }

    if (updates.isEmpty) {
      if (mounted) {
        setState(() {
          _dirtyKeys.removeAll(submittedKeys);
          _saveStatus = _dirtyKeys.isEmpty
              ? _SaveStatus.success
              : _SaveStatus.dirty;
          _saveError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _saving = true;
        _saveStatus = _SaveStatus.saving;
        _saveError = null;
      });
    }

    try {
      await _service.updateVisibilityConfig(items: updates);
      if (!mounted) {
        return;
      }
      setState(() {
        _dirtyKeys.removeAll(submittedKeys);
        _lastSavedAt = DateTime.now();
        _saveStatus = _dirtyKeys.isEmpty
            ? _SaveStatus.success
            : _SaveStatus.dirty;
        _saveError = null;
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
        _saveStatus = _SaveStatus.error;
        _saveError = '保存失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
      if (_saveQueued) {
        _saveQueued = false;
        _flushDirty();
      }
    }
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    await _flushDirty();
  }

  Future<void> _handleRefresh() async {
    if (_dirtyKeys.isNotEmpty) {
      await _saveNow();
      if (_dirtyKeys.isNotEmpty) {
        return;
      }
    }
    await _loadData();
  }

  void _applyParentOffToChildren({
    required String roleCode,
    required PageCatalogItem parent,
  }) {
    final children = _childrenOfParent(parent.code);
    for (final child in children) {
      final childKey = _key(roleCode, child.code);
      final canEdit = _editable[childKey] ?? !child.alwaysVisible;
      if (!canEdit) {
        continue;
      }
      if ((_draftValues[childKey] ?? false) != false) {
        _draftValues[childKey] = false;
        _dirtyKeys.add(childKey);
      }
    }
  }

  void _onSwitchChanged({
    required String roleCode,
    required PageCatalogItem page,
    required bool value,
  }) {
    final pageKey = _key(roleCode, page.code);
    final canEdit = _editable[pageKey] ?? !page.alwaysVisible;
    if (!canEdit) {
      return;
    }
    if (_isChildBlockedByParent(roleCode, page)) {
      return;
    }

    final oldValue = _draftValues[pageKey] ?? false;
    if (oldValue == value) {
      return;
    }

    setState(() {
      _draftValues[pageKey] = value;
      _dirtyKeys.add(pageKey);
      _saveStatus = _SaveStatus.dirty;
      _saveError = null;

      if (_isParentPage(page) && !value) {
        _applyParentOffToChildren(roleCode: roleCode, parent: page);
      }
    });

    _scheduleAutoSave();
  }

  String _saveStatusText() {
    switch (_saveStatus) {
      case _SaveStatus.idle:
        return '未修改';
      case _SaveStatus.dirty:
        return '有未保存改动';
      case _SaveStatus.saving:
        return '保存中';
      case _SaveStatus.success:
        return '已保存';
      case _SaveStatus.error:
        return '保存失败';
    }
  }

  Color _saveStatusColor(ThemeData theme) {
    switch (_saveStatus) {
      case _SaveStatus.idle:
        return theme.colorScheme.outline;
      case _SaveStatus.dirty:
        return Colors.orange;
      case _SaveStatus.saving:
        return theme.colorScheme.primary;
      case _SaveStatus.success:
        return Colors.green;
      case _SaveStatus.error:
        return theme.colorScheme.error;
    }
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  Widget _buildTopOverview(ThemeData theme) {
    final totalParents = _groups
        .where((group) => group.parent.pageType == 'sidebar')
        .length;
    final totalChildren = _groups.fold<int>(
      0,
      (count, group) => count + group.children.length,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '页面可见性配置',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('总页面：$totalParents'),
                      Text('分页面：$totalChildren'),
                      Text('角色：${_roleCodes.length}'),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: _saveStatusColor(theme).withValues(alpha: 0.15),
              ),
              child: Text(
                _saveStatusText(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _saveStatusColor(theme),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: '刷新',
              onPressed: _loading ? null : _handleRefresh,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: (_loading || _saving || _dirtyKeys.isEmpty)
                  ? null
                  : _saveNow,
              icon: const Icon(Icons.save),
              label: const Text('立即保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreePanel(ThemeData theme) {
    if (_groups.isEmpty) {
      return const Center(child: Text('暂无可配置页面'));
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView(
        children: _groups.map((group) {
          final parent = group.parent;
          final isSelectedParent = _selectedPageCode == parent.code;
          final isExpanded = _expandedParentCodes.contains(parent.code);

          return Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('group-${parent.code}'),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedParentCodes.add(parent.code);
                  } else {
                    _expandedParentCodes.remove(parent.code);
                  }
                  _selectedPageCode = parent.code;
                });
              },
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      parent.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isSelectedParent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelectedParent
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Text('${group.children.length}'),
                  ),
                ],
              ),
              subtitle: Text(parent.code),
              children: group.children.map((child) {
                final selected = _selectedPageCode == child.code;
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 28, right: 12),
                  leading: const Icon(Icons.subdirectory_arrow_right),
                  title: Text(child.name),
                  subtitle: Text(child.code),
                  selected: selected,
                  onTap: () {
                    setState(() {
                      _selectedPageCode = child.code;
                      _expandedParentCodes.add(parent.code);
                    });
                  },
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoleSwitches(ThemeData theme, PageCatalogItem page) {
    if (_roleCodes.isEmpty) {
      return const Center(child: Text('暂无角色数据'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _roleCodes.length,
      separatorBuilder: (_, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final roleCode = _roleCodes[index];
        final title = _roleNames[roleCode] ?? roleCode;
        final pageKey = _key(roleCode, page.code);
        final value = _draftValues[pageKey] ?? false;
        final canEdit =
            (_editable[pageKey] ?? !page.alwaysVisible) && !page.alwaysVisible;
        final blockedByParent = _isChildBlockedByParent(roleCode, page);
        final enabled = canEdit && !blockedByParent;

        String subtitle = roleCode;
        if (page.alwaysVisible) {
          subtitle = '$subtitle · 首页固定可见';
        } else if (blockedByParent) {
          subtitle = '$subtitle · 父页面未开启，当前不可配置';
        }

        return SwitchListTile(
          dense: true,
          title: Text(title),
          subtitle: Text(subtitle),
          value: page.alwaysVisible ? true : value,
          onChanged: enabled
              ? (checked) {
                  _onSwitchChanged(
                    roleCode: roleCode,
                    page: page,
                    value: checked,
                  );
                }
              : null,
        );
      },
    );
  }

  Widget _buildConfigPanel(ThemeData theme) {
    final selectedPage = _findPageByCode(_selectedPageCode);
    if (selectedPage == null) {
      return const Card(child: Center(child: Text('请选择一个页面进行配置')));
    }

    final pageTypeLabel = selectedPage.pageType == 'sidebar' ? '总页面' : '分页面';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedPage.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text('页面编码：${selectedPage.code}'),
                  Text('页面类型：$pageTypeLabel'),
                  if (selectedPage.parentCode != null)
                    Text('所属总页面：${selectedPage.parentCode}'),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _buildRoleSwitches(theme, selectedPage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiddleWorkspace(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              SizedBox(height: 280, child: _buildTreePanel(theme)),
              const SizedBox(height: 12),
              Expanded(child: _buildConfigPanel(theme)),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 340, child: _buildTreePanel(theme)),
            const SizedBox(width: 12),
            Expanded(child: _buildConfigPanel(theme)),
          ],
        );
      },
    );
  }

  Widget _buildBottomOverview(ThemeData theme) {
    final lastSavedText = _lastSavedAt == null
        ? '尚未保存'
        : _formatTime(_lastSavedAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text('最后成功保存：$lastSavedText'),
                Text('待保存改动：${_dirtyKeys.length}'),
                if (_catalogFallback)
                  Text(
                    '目录来源：本地兜底',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
              ],
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _saveError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _saveNow,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ],
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _message,
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopOverview(theme),
          const SizedBox(height: 12),
          Expanded(child: _buildMiddleWorkspace(theme)),
          const SizedBox(height: 12),
          _buildBottomOverview(theme),
        ],
      ),
    );
  }
}
