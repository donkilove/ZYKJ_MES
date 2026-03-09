import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/authz_service.dart';
import '../services/user_service.dart';

const Map<String, String> _moduleNameFallbackZh = {
  'system': '系统管理',
  'user': '用户管理',
  'product': '产品管理',
  'equipment': '设备管理',
  'craft': '工艺管理',
  'quality': '质量管理',
  'production': '生产管理',
};

class _RoleDraft {
  const _RoleDraft({
    required this.moduleEnabled,
    required this.pagePermissionCodes,
    required this.featurePermissionCodes,
  });

  final bool moduleEnabled;
  final Set<String> pagePermissionCodes;
  final Set<String> featurePermissionCodes;

  _RoleDraft copyWith({
    bool? moduleEnabled,
    Set<String>? pagePermissionCodes,
    Set<String>? featurePermissionCodes,
  }) {
    return _RoleDraft(
      moduleEnabled: moduleEnabled ?? this.moduleEnabled,
      pagePermissionCodes: pagePermissionCodes ?? this.pagePermissionCodes,
      featurePermissionCodes:
          featurePermissionCodes ?? this.featurePermissionCodes,
    );
  }
}

class FunctionPermissionConfigPage extends StatefulWidget {
  const FunctionPermissionConfigPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<FunctionPermissionConfigPage> createState() =>
      _FunctionPermissionConfigPageState();
}

class _FunctionPermissionConfigPageState
    extends State<FunctionPermissionConfigPage> {
  late final AuthzService _authzService;
  late final UserService _userService;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  bool _previewing = false;
  String _message = '';

  List<RoleItem> _roles = const [];
  List<String> _moduleCodes = const [];
  String? _selectedModuleCode;
  String? _selectedRoleCode;

  final Map<String, PermissionHierarchyCatalogResult> _catalogByModule = {};
  final Map<String, _RoleDraft> _originByRole = {};
  final Map<String, _RoleDraft> _draftByRole = {};
  final Map<String, bool> _readonlyByRole = {};
  final Map<String, Set<String>> _effectivePagesByRole = {};
  final Map<String, Set<String>> _effectiveFeaturesByRole = {};

  PermissionHierarchyPreviewResult? _activePreview;
  bool _showPreview = false;
  bool _activePreviewIsSaved = false;
  final Map<String, PermissionHierarchyPreviewResult> _lastSavedByModule = {};
  Map<String, _RoleDraft>? _lastSavedBeforeSnapshot;
  String? _lastSavedSnapshotModuleCode;

  @override
  void initState() {
    super.initState();
    _authzService = AuthzService(widget.session);
    _userService = UserService(widget.session);
    _searchController.addListener(_onSearchChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
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

  String _moduleLabel(String moduleCode) {
    final fromCatalog = _catalogByModule[moduleCode]?.moduleName.trim();
    if (fromCatalog != null && fromCatalog.isNotEmpty) {
      return fromCatalog;
    }
    return _moduleNameFallbackZh[moduleCode] ?? moduleCode;
  }

  PermissionHierarchyCatalogResult? get _catalog {
    final moduleCode = _selectedModuleCode;
    if (moduleCode == null) {
      return null;
    }
    return _catalogByModule[moduleCode];
  }

  RoleItem? get _selectedRole {
    if (_roles.isEmpty) {
      return null;
    }
    final current = _selectedRoleCode;
    if (current == null) {
      return _roles.first;
    }
    for (final role in _roles) {
      if (role.code == current) {
        return role;
      }
    }
    return _roles.first;
  }

  bool _isReadonly(String roleCode) => _readonlyByRole[roleCode] ?? false;

  Map<String, _RoleDraft> _cloneDraftMap(Map<String, _RoleDraft> source) {
    return source.map(
      (key, value) => MapEntry(
        key,
        _RoleDraft(
          moduleEnabled: value.moduleEnabled,
          pagePermissionCodes: {...value.pagePermissionCodes},
          featurePermissionCodes: {...value.featurePermissionCodes},
        ),
      ),
    );
  }

  bool _draftEquals(_RoleDraft a, _RoleDraft b) {
    if (a.moduleEnabled != b.moduleEnabled) {
      return false;
    }
    if (a.pagePermissionCodes.length != b.pagePermissionCodes.length ||
        !a.pagePermissionCodes.containsAll(b.pagePermissionCodes)) {
      return false;
    }
    if (a.featurePermissionCodes.length != b.featurePermissionCodes.length ||
        !a.featurePermissionCodes.containsAll(b.featurePermissionCodes)) {
      return false;
    }
    return true;
  }

  bool _hasDirtyRole(String roleCode) {
    final origin = _originByRole[roleCode];
    final draft = _draftByRole[roleCode];
    if (origin == null || draft == null) {
      return false;
    }
    return !_draftEquals(origin, draft);
  }

  bool get _hasDirty {
    for (final role in _roles) {
      if (_hasDirtyRole(role.code)) {
        return true;
      }
    }
    return false;
  }

  bool get _canRollbackLastSave {
    return _lastSavedBeforeSnapshot != null &&
        _lastSavedSnapshotModuleCode != null &&
        _lastSavedSnapshotModuleCode == _selectedModuleCode;
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final roleResult = await _userService.listRoles();
      final roles = roleResult.items.toList()..sort((a, b) => a.id - b.id);
      if (roles.isEmpty) {
        throw StateError('未查询到角色');
      }
      final bootstrap = await _authzService.loadPermissionHierarchyCatalog(
        moduleCode: _selectedModuleCode ?? 'production',
      );
      _catalogByModule[bootstrap.moduleCode] = bootstrap;
      final modules = bootstrap.moduleCodes.toList()..sort();
      final initialModule = modules.contains('production')
          ? 'production'
          : modules.first;
      await _loadModuleData(initialModule, roles: roles, moduleCodes: modules);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载权限配置失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadModuleData(
    String moduleCode, {
    List<RoleItem>? roles,
    List<String>? moduleCodes,
  }) async {
    final catalog = await _authzService.loadPermissionHierarchyCatalog(
      moduleCode: moduleCode,
    );
    _catalogByModule[catalog.moduleCode] = catalog;

    final effectiveRoles = roles ?? _roles;
    final configs = await Future.wait(
      effectiveRoles.map(
        (role) => _authzService.loadPermissionHierarchyRoleConfig(
          roleCode: role.code,
          moduleCode: catalog.moduleCode,
        ),
      ),
    );

    final originByRole = <String, _RoleDraft>{};
    final draftByRole = <String, _RoleDraft>{};
    final readonlyByRole = <String, bool>{};
    final effectivePagesByRole = <String, Set<String>>{};
    final effectiveFeaturesByRole = <String, Set<String>>{};
    for (final config in configs) {
      final draft = _RoleDraft(
        moduleEnabled: config.moduleEnabled,
        pagePermissionCodes: config.grantedPagePermissionCodes.toSet(),
        featurePermissionCodes: config.grantedFeaturePermissionCodes.toSet(),
      );
      originByRole[config.roleCode] = draft;
      draftByRole[config.roleCode] = _RoleDraft(
        moduleEnabled: draft.moduleEnabled,
        pagePermissionCodes: {...draft.pagePermissionCodes},
        featurePermissionCodes: {...draft.featurePermissionCodes},
      );
      readonlyByRole[config.roleCode] = config.readonly;
      effectivePagesByRole[config.roleCode] = config
          .effectivePagePermissionCodes
          .toSet();
      effectiveFeaturesByRole[config.roleCode] = config
          .effectiveFeaturePermissionCodes
          .toSet();
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _roles = effectiveRoles;
      _moduleCodes = (moduleCodes ?? catalog.moduleCodes)..sort();
      _selectedModuleCode = catalog.moduleCode;
      _selectedRoleCode =
          _selectedRoleCode != null &&
              effectiveRoles.any((item) => item.code == _selectedRoleCode)
          ? _selectedRoleCode
          : effectiveRoles.first.code;
      _originByRole
        ..clear()
        ..addAll(originByRole);
      _draftByRole
        ..clear()
        ..addAll(draftByRole);
      _readonlyByRole
        ..clear()
        ..addAll(readonlyByRole);
      _effectivePagesByRole
        ..clear()
        ..addAll(effectivePagesByRole);
      _effectiveFeaturesByRole
        ..clear()
        ..addAll(effectiveFeaturesByRole);
      _showPreview = false;
      _activePreview = null;
      _activePreviewIsSaved = false;
      _message = '';
    });
  }

  Future<void> _switchModule(String? moduleCode) async {
    if (moduleCode == null ||
        moduleCode == _selectedModuleCode ||
        _loading ||
        _saving) {
      return;
    }
    if (_hasDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('切换模块'),
            content: const Text('当前有未保存改动，是否放弃并切换？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('放弃并切换'),
              ),
            ],
          );
        },
      );
      if (discard != true) {
        return;
      }
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      await _loadModuleData(moduleCode);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '切换模块失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<PermissionHierarchyRoleDraftItem> _roleDraftItems() {
    final items = <PermissionHierarchyRoleDraftItem>[];
    for (final role in _roles) {
      final draft = _draftByRole[role.code];
      if (draft == null) {
        continue;
      }
      items.add(
        PermissionHierarchyRoleDraftItem(
          roleCode: role.code,
          moduleEnabled: draft.moduleEnabled,
          pagePermissionCodes: draft.pagePermissionCodes.toList()..sort(),
          featurePermissionCodes: draft.featurePermissionCodes.toList()..sort(),
        ),
      );
    }
    return items;
  }

  Future<PermissionHierarchyPreviewResult?> _preview({
    bool activatePanel = true,
  }) async {
    final moduleCode = _selectedModuleCode;
    if (moduleCode == null) {
      return null;
    }
    setState(() {
      _previewing = true;
      _message = '';
    });
    try {
      final preview = await _authzService.previewPermissionHierarchy(
        moduleCode: moduleCode,
        roleItems: _roleDraftItems(),
      );
      if (!mounted) {
        return null;
      }
      if (activatePanel) {
        setState(() {
          _activePreview = preview;
          _showPreview = true;
          _activePreviewIsSaved = false;
        });
      }
      return preview;
    } catch (error) {
      if (!mounted) {
        return null;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return null;
      }
      setState(() {
        _message = '生效预览失败：${_errorMessage(error)}';
      });
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _previewing = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final moduleCode = _selectedModuleCode;
    final catalog = _catalog;
    if (_saving || !_hasDirty || moduleCode == null || catalog == null) {
      return;
    }
    final preview = await _preview(activatePanel: false);
    if (preview == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认保存'),
        content: const Text('将按当前草稿覆盖所选模块权限，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认保存'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      setState(() {
        _activePreview = preview;
        _showPreview = true;
        _activePreviewIsSaved = false;
      });
      return;
    }
    setState(() {
      _saving = true;
      _message = '';
    });
    final snapshot = _cloneDraftMap(_originByRole);
    try {
      final results = <PermissionHierarchyRoleUpdateResult>[];
      for (final role in _roles) {
        final draft = _draftByRole[role.code];
        if (draft == null) {
          continue;
        }
        final result = await _authzService.updatePermissionHierarchyRoleConfig(
          roleCode: role.code,
          moduleCode: moduleCode,
          moduleEnabled: draft.moduleEnabled,
          pagePermissionCodes: draft.pagePermissionCodes.toList()..sort(),
          featurePermissionCodes: draft.featurePermissionCodes.toList()..sort(),
          dryRun: false,
          remark: '功能权限分层保存',
        );
        results.add(result);
      }

      for (final result in results) {
        final after = result.afterPermissionCodes.toSet();
        final pageCodes = catalog.pages
            .map((item) => item.permissionCode)
            .toSet();
        final featureCodes = catalog.features
            .map((item) => item.permissionCode)
            .toSet();
        final next = _RoleDraft(
          moduleEnabled: after.contains(catalog.modulePermissionCode),
          pagePermissionCodes: after.intersection(pageCodes),
          featurePermissionCodes: after.intersection(featureCodes),
        );
        _originByRole[result.roleCode] = next;
        _draftByRole[result.roleCode] = _RoleDraft(
          moduleEnabled: next.moduleEnabled,
          pagePermissionCodes: {...next.pagePermissionCodes},
          featurePermissionCodes: {...next.featurePermissionCodes},
        );
        _effectivePagesByRole[result.roleCode] = result
            .effectivePagePermissionCodes
            .toSet();
        _effectiveFeaturesByRole[result.roleCode] = result
            .effectiveFeaturePermissionCodes
            .toSet();
      }

      final savedPreview = PermissionHierarchyPreviewResult(
        moduleCode: moduleCode,
        roleResults: results,
      );
      setState(() {
        _lastSavedBeforeSnapshot = snapshot;
        _lastSavedSnapshotModuleCode = moduleCode;
        _lastSavedByModule[moduleCode] = savedPreview;
        _showPreview = false;
        _activePreview = null;
        _activePreviewIsSaved = false;
        _message = '保存成功，可通过顶部“查看最近保存结果”查看详情。';
      });
    } catch (error) {
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

  Future<void> _rollbackLastSave() async {
    final moduleCode = _selectedModuleCode;
    final snapshot = _lastSavedBeforeSnapshot;
    if (!_canRollbackLastSave || moduleCode == null || snapshot == null) {
      return;
    }
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      for (final role in _roles) {
        final target = snapshot[role.code];
        if (target == null) {
          continue;
        }
        await _authzService.updatePermissionHierarchyRoleConfig(
          roleCode: role.code,
          moduleCode: moduleCode,
          moduleEnabled: target.moduleEnabled,
          pagePermissionCodes: target.pagePermissionCodes.toList()..sort(),
          featurePermissionCodes: target.featurePermissionCodes.toList()
            ..sort(),
          dryRun: false,
          remark: '功能权限分层回退',
        );
      }
      await _loadModuleData(moduleCode);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastSavedBeforeSnapshot = null;
        _lastSavedSnapshotModuleCode = null;
        _message = '已回退到上次保存前状态。';
      });
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '回退失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _resetUnsaved() {
    setState(() {
      _draftByRole
        ..clear()
        ..addAll(_cloneDraftMap(_originByRole));
      _showPreview = false;
      _activePreview = null;
      _activePreviewIsSaved = false;
    });
  }

  Widget _buildPreviewCard() {
    final preview = _activePreview;
    if (!_showPreview || preview == null) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _activePreviewIsSaved ? '最近保存结果' : '生效预览（未保存）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => setState(() => _showPreview = false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text('模块：${_moduleLabel(preview.moduleCode)}'),
            const SizedBox(height: 8),
            ...preview.roleResults.map(
              (item) => Text(
                '${item.roleName}：变更 ${item.addedPermissionCodes.length + item.removedPermissionCodes.length}，自动补依赖 ${item.autoLinkedDependencies.length}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelectorCard(RoleItem selectedRole) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              '角色',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _roles.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final role = _roles[index];
                final selected = role.code == selectedRole.code;
                final readonly = _isReadonly(role.code);
                final dirty = _hasDirtyRole(role.code);
                final draft = _draftByRole[role.code];
                final count = draft == null
                    ? 0
                    : (draft.moduleEnabled ? 1 : 0) +
                          draft.pagePermissionCodes.length +
                          draft.featurePermissionCodes.length;
                return ListTile(
                  dense: true,
                  selected: selected,
                  onTap: () => setState(() => _selectedRoleCode = role.code),
                  title: Text(role.name),
                  subtitle: Text(role.code),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$count 项'),
                      if (dirty)
                        Text(
                          '未保存',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      if (readonly)
                        const Text('只读', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleAndPagesCard({
    required RoleItem role,
    required _RoleDraft draft,
    required bool readonly,
    required List<PermissionHierarchyPageItem> pages,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '页面链路',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('模块总开关'),
            subtitle: Text(readonly ? '系统管理员固定全权限（只读）' : '关闭后保留下层配置，入口不可用'),
            value: draft.moduleEnabled,
            onChanged: readonly || _saving
                ? null
                : (value) => setState(
                    () => _draftByRole[role.code] = draft.copyWith(
                      moduleEnabled: value,
                    ),
                  ),
          ),
          const Divider(),
          Text(
            '页面开关（${pages.length}）',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ...pages.map((item) {
            final checked = draft.pagePermissionCodes.contains(
              item.permissionCode,
            );
            final effective =
                (_effectivePagesByRole[role.code] ?? const <String>{}).contains(
                  item.permissionCode,
                );
            return SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.pageName),
              subtitle: Text(
                checked ? (effective ? '当前可见' : '已配置但不可见') : '未开启',
              ),
              value: checked,
              onChanged: readonly || _saving
                  ? null
                  : (value) => setState(() {
                      final next = {...draft.pagePermissionCodes};
                      if (value) {
                        next.add(item.permissionCode);
                      } else {
                        next.remove(item.permissionCode);
                      }
                      _draftByRole[role.code] = draft.copyWith(
                        pagePermissionCodes: next,
                      );
                    }),
            );
          }),
        ],
      ),
    );
  }

  Map<String, List<PermissionHierarchyFeatureItem>> _groupFeaturesByPage(
    List<PermissionHierarchyFeatureItem> features,
  ) {
    final grouped = <String, List<PermissionHierarchyFeatureItem>>{};
    for (final item in features) {
      final key = item.pagePermissionCode ?? '__no_page__';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    for (final values in grouped.values) {
      values.sort((a, b) => a.permissionCode.compareTo(b.permissionCode));
    }
    return grouped;
  }

  Widget _buildFeaturesCard({
    required RoleItem role,
    required PermissionHierarchyCatalogResult catalog,
    required _RoleDraft draft,
    required bool readonly,
    required List<PermissionHierarchyFeatureItem> features,
  }) {
    final pageNameByPermission = {
      for (final page in catalog.pages) page.permissionCode: page.pageName,
    };
    final effectiveFeatures =
        _effectiveFeaturesByRole[role.code] ?? const <String>{};
    final grouped = _groupFeaturesByPage(features);

    String featureStatus(PermissionHierarchyFeatureItem item, bool checked) {
      final effective = effectiveFeatures.contains(item.permissionCode);
      final pageEnabled =
          item.pagePermissionCode == null ||
          draft.pagePermissionCodes.contains(item.pagePermissionCode);
      if (!checked) {
        return '未开启';
      }
      if (!draft.moduleEnabled) {
        return '已配置但不可用（模块未开启）';
      }
      if (!pageEnabled) {
        return '已配置但不可用（页面未开启）';
      }
      return effective ? '可用' : '已配置待生效';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '功能链开关（${features.length}）',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...grouped.entries.map((entry) {
            final pagePermissionCode = entry.key;
            final pageName =
                pageNameByPermission[pagePermissionCode] ?? '未绑定页面';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text('$pageName（${entry.value.length}）'),
                children: entry.value.map((item) {
                  final checked = draft.featurePermissionCodes.contains(
                    item.permissionCode,
                  );
                  return SwitchListTile(
                    dense: true,
                    title: Text(item.featureName),
                    subtitle: Text(
                      '${featureStatus(item, checked)}\n'
                      '依赖：${item.dependencyPermissionCodes.isEmpty ? '无' : item.dependencyPermissionCodes.join('、')}',
                    ),
                    value: checked,
                    onChanged: readonly || _saving
                        ? null
                        : (value) => setState(() {
                            final next = {...draft.featurePermissionCodes};
                            if (value) {
                              next.add(item.permissionCode);
                            } else {
                              next.remove(item.permissionCode);
                            }
                            _draftByRole[role.code] = draft.copyWith(
                              featurePermissionCodes: next,
                            );
                          }),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final catalog = _catalog;
    final role = _selectedRole;
    if (catalog == null || role == null) {
      return Center(child: Text(_message.isEmpty ? '暂无数据' : _message));
    }
    final draft = _draftByRole[role.code]!;
    final readonly = _isReadonly(role.code);
    final keyword = _searchController.text.trim().toLowerCase();
    final pages =
        catalog.pages
            .where(
              (item) =>
                  keyword.isEmpty ||
                  item.pageName.toLowerCase().contains(keyword) ||
                  item.permissionCode.toLowerCase().contains(keyword),
            )
            .toList()
          ..sort((a, b) => a.pageCode.compareTo(b.pageCode));
    final features =
        catalog.features
            .where(
              (item) =>
                  keyword.isEmpty ||
                  item.featureName.toLowerCase().contains(keyword) ||
                  item.permissionCode.toLowerCase().contains(keyword),
            )
            .toList()
          ..sort((a, b) => a.permissionCode.compareTo(b.permissionCode));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedModuleCode,
                          decoration: const InputDecoration(
                            labelText: '模块',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _moduleCodes
                              .map(
                                (code) => DropdownMenuItem<String>(
                                  value: code,
                                  child: Text('${_moduleLabel(code)}（$code）'),
                                ),
                              )
                              .toList(),
                          onChanged: _saving ? null : _switchModule,
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: '搜索页面/功能链',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving || _previewing ? null : _preview,
                        icon: const Icon(Icons.visibility),
                        label: Text(_previewing ? '预览中...' : '生效预览'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _saving ||
                                _lastSavedByModule[_selectedModuleCode] == null
                            ? null
                            : () {
                                final saved =
                                    _lastSavedByModule[_selectedModuleCode];
                                if (saved == null) return;
                                setState(() {
                                  _activePreview = saved;
                                  _showPreview = true;
                                  _activePreviewIsSaved = true;
                                });
                              },
                        icon: const Icon(Icons.history),
                        label: const Text('查看最近保存结果'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving || !_hasDirty ? null : _resetUnsaved,
                        icon: const Icon(Icons.undo),
                        label: const Text('回退未保存'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving || !_canRollbackLastSave
                            ? null
                            : _rollbackLastSave,
                        icon: const Icon(Icons.restore),
                        label: const Text('回退上次保存'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving || !_hasDirty ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(_saving ? '保存中...' : '保存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildPreviewCard(),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_message),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 1100) {
                  return Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: _buildRoleSelectorCard(role),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 320,
                        child: _buildModuleAndPagesCard(
                          role: role,
                          draft: draft,
                          readonly: readonly,
                          pages: pages,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildFeaturesCard(
                          role: role,
                          catalog: catalog,
                          draft: draft,
                          readonly: readonly,
                          features: features,
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(
                      width: 360,
                      child: Column(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildRoleSelectorCard(role),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            flex: 7,
                            child: _buildModuleAndPagesCard(
                              role: role,
                              draft: draft,
                              readonly: readonly,
                              pages: pages,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFeaturesCard(
                        role: role,
                        catalog: catalog,
                        draft: draft,
                        readonly: readonly,
                        features: features,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
