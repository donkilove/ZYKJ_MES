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
    required this.capabilityCodes,
  });

  final bool moduleEnabled;
  final Set<String> capabilityCodes;

  _RoleDraft copyWith({bool? moduleEnabled, Set<String>? capabilityCodes}) {
    return _RoleDraft(
      moduleEnabled: moduleEnabled ?? this.moduleEnabled,
      capabilityCodes: capabilityCodes ?? this.capabilityCodes,
    );
  }
}

class FunctionPermissionConfigPage extends StatefulWidget {
  const FunctionPermissionConfigPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.onPermissionsChanged,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final Future<void> Function()? onPermissionsChanged;

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
  bool _showAdvanced = false;
  String _message = '';

  List<RoleItem> _roles = const [];
  List<String> _moduleCodes = const [];
  String? _selectedModuleCode;
  String? _selectedRoleCode;

  final Map<String, CapabilityPackCatalogResult> _catalogByModule = {};
  final Map<String, _RoleDraft> _originByRole = {};
  final Map<String, _RoleDraft> _draftByRole = {};
  final Map<String, bool> _readonlyByRole = {};
  final Map<String, Set<String>> _effectiveCapabilitiesByRole = {};
  final Map<String, PermissionExplainResult> _explainByRole = {};

  CapabilityPackPreviewResult? _activePreview;
  bool _showPreview = false;
  bool _activePreviewIsSaved = false;
  final Map<String, CapabilityPackPreviewResult> _lastSavedByModule = {};
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
    final fallback = _moduleNameFallbackZh[moduleCode];
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    if (fromCatalog != null && fromCatalog.isNotEmpty) {
      return fromCatalog;
    }
    return moduleCode;
  }

  CapabilityPackCatalogResult? get _catalog {
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
          capabilityCodes: {...value.capabilityCodes},
        ),
      ),
    );
  }

  bool _draftEquals(_RoleDraft a, _RoleDraft b) {
    if (a.moduleEnabled != b.moduleEnabled) {
      return false;
    }
    if (a.capabilityCodes.length != b.capabilityCodes.length ||
        !a.capabilityCodes.containsAll(b.capabilityCodes)) {
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
      final bootstrap = await _authzService.loadCapabilityPackCatalog(
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
    final catalog = await _authzService.loadCapabilityPackCatalog(
      moduleCode: moduleCode,
    );
    _catalogByModule[catalog.moduleCode] = catalog;

    final effectiveRoles = roles ?? _roles;
    final configs = await Future.wait(
      effectiveRoles.map(
        (role) => _authzService.loadCapabilityPackRoleConfig(
          roleCode: role.code,
          moduleCode: catalog.moduleCode,
        ),
      ),
    );
    final explains = await Future.wait(
      effectiveRoles.map(
        (role) => _authzService.loadCapabilityPackEffective(
          roleCode: role.code,
          moduleCode: catalog.moduleCode,
        ),
      ),
    );

    final originByRole = <String, _RoleDraft>{};
    final draftByRole = <String, _RoleDraft>{};
    final readonlyByRole = <String, bool>{};
    final effectiveByRole = <String, Set<String>>{};
    final explainByRole = <String, PermissionExplainResult>{};
    for (final config in configs) {
      final draft = _RoleDraft(
        moduleEnabled: config.moduleEnabled,
        capabilityCodes: config.grantedCapabilityCodes.toSet(),
      );
      originByRole[config.roleCode] = draft;
      draftByRole[config.roleCode] = _RoleDraft(
        moduleEnabled: draft.moduleEnabled,
        capabilityCodes: {...draft.capabilityCodes},
      );
      readonlyByRole[config.roleCode] = config.readonly;
      effectiveByRole[config.roleCode] = config.effectiveCapabilityCodes
          .toSet();
    }
    for (final explain in explains) {
      explainByRole[explain.roleCode] = explain;
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
      _effectiveCapabilitiesByRole
        ..clear()
        ..addAll(effectiveByRole);
      _explainByRole
        ..clear()
        ..addAll(explainByRole);
      _showPreview = false;
      _activePreview = null;
      _activePreviewIsSaved = false;
      _showAdvanced = false;
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

  List<CapabilityPackRoleDraftItem> _roleDraftItems() {
    final items = <CapabilityPackRoleDraftItem>[];
    for (final role in _roles) {
      final draft = _draftByRole[role.code];
      if (draft == null) {
        continue;
      }
      items.add(
        CapabilityPackRoleDraftItem(
          roleCode: role.code,
          moduleEnabled: draft.moduleEnabled,
          capabilityCodes: draft.capabilityCodes.toList()..sort(),
        ),
      );
    }
    return items;
  }

  Future<CapabilityPackPreviewResult?> _preview({
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
      final preview = await _authzService.previewCapabilityPacks(
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
    if (_saving || !_hasDirty || moduleCode == null) {
      return;
    }
    final moduleRevision = _catalogByModule[moduleCode]?.moduleRevision ?? 0;
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
      final dirtyRoleItems = <CapabilityPackRoleDraftItem>[];
      for (final role in _roles) {
        if (!_hasDirtyRole(role.code)) {
          continue;
        }
        final draft = _draftByRole[role.code];
        if (draft == null) {
          continue;
        }
        dirtyRoleItems.add(
          CapabilityPackRoleDraftItem(
            roleCode: role.code,
            moduleEnabled: draft.moduleEnabled,
            capabilityCodes: draft.capabilityCodes.toList()..sort(),
          ),
        );
      }

      final savedPreview = await _authzService.applyCapabilityPacks(
        moduleCode: moduleCode,
        roleItems: dirtyRoleItems,
        expectedRevision: moduleRevision,
        remark: '能力包权限配置保存',
      );

      await _loadModuleData(
        moduleCode,
        roles: _roles,
        moduleCodes: _moduleCodes,
      );
      await widget.onPermissionsChanged?.call();
      if (!mounted) {
        return;
      }
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
    final moduleRevision = _catalogByModule[moduleCode]?.moduleRevision ?? 0;
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      final rollbackRoleItems = <CapabilityPackRoleDraftItem>[];
      for (final role in _roles) {
        final target = snapshot[role.code];
        if (target == null) {
          continue;
        }
        rollbackRoleItems.add(
          CapabilityPackRoleDraftItem(
            roleCode: role.code,
            moduleEnabled: target.moduleEnabled,
            capabilityCodes: target.capabilityCodes.toList()..sort(),
          ),
        );
      }
      await _authzService.applyCapabilityPacks(
        moduleCode: moduleCode,
        roleItems: rollbackRoleItems,
        expectedRevision: moduleRevision,
        remark: '能力包权限配置回退',
      );
      await _loadModuleData(
        moduleCode,
        roles: _roles,
        moduleCodes: _moduleCodes,
      );
      await widget.onPermissionsChanged?.call();
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

  void _applyRoleTemplate({
    required RoleItem role,
    required _RoleDraft draft,
    required CapabilityPackCatalogResult catalog,
  }) {
    final templateItems = catalog.roleTemplates
        .where((item) => item.roleCode == role.code)
        .toList();
    if (templateItems.isEmpty) {
      return;
    }
    final template = templateItems.first;
    final validCodes = catalog.capabilityPacks
        .map((item) => item.capabilityCode)
        .toSet();
    final templateCodes = template.capabilityCodes.toSet().intersection(
      validCodes,
    );
    setState(() {
      _draftByRole[role.code] = draft.copyWith(
        moduleEnabled: templateCodes.isNotEmpty ? true : draft.moduleEnabled,
        capabilityCodes: templateCodes,
      );
      _message = '已套用岗位模板：${role.name}（${templateCodes.length} 项）';
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
                '${item.roleName}：能力变更 ${item.addedCapabilityCodes.length + item.removedCapabilityCodes.length}，自动补依赖 ${item.autoLinkedDependencies.length}',
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
                          draft.capabilityCodes.length;
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

  Widget _buildCapabilityCard({
    required RoleItem role,
    required _RoleDraft draft,
    required bool readonly,
    required CapabilityPackCatalogResult catalog,
    required List<CapabilityPackItem> capabilityPacks,
  }) {
    final capabilityNameByCode = {
      for (final item in catalog.capabilityPacks)
        item.capabilityCode: item.capabilityName,
    };
    final explainItems = _explainByRole[role.code]?.capabilityItems ?? const [];
    final explainByCode = {
      for (final item in explainItems) item.capabilityCode: item,
    };
    final effectiveCodes =
        _effectiveCapabilitiesByRole[role.code] ?? const <String>{};

    final grouped = <String, List<CapabilityPackItem>>{};
    for (final item in capabilityPacks) {
      grouped
          .putIfAbsent(item.groupName, () => <CapabilityPackItem>[])
          .add(item);
    }
    final groupNames = grouped.keys.toList()..sort();
    for (final key in groupNames) {
      grouped[key]!.sort(
        (a, b) => a.capabilityName.compareTo(b.capabilityName),
      );
    }

    String statusOf(
      CapabilityPackItem capability,
      bool checked,
      PermissionExplainCapabilityItem? explainItem,
    ) {
      if (!checked) {
        return '未开启';
      }
      if (!draft.moduleEnabled) {
        return '已配置但不可用（模块入口关闭）';
      }
      if (effectiveCodes.contains(capability.capabilityCode) ||
          (explainItem?.available ?? false)) {
        return '可用';
      }
      if (explainItem != null && explainItem.reasonMessages.isNotEmpty) {
        return explainItem.reasonMessages.join('；');
      }
      return '已配置但不可用';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '能力包（${capabilityPacks.length}）',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: draft.moduleEnabled,
                onChanged: readonly || _saving
                    ? null
                    : (value) => setState(() {
                        _draftByRole[role.code] = draft.copyWith(
                          moduleEnabled: value,
                        );
                      }),
              ),
              Text(
                draft.moduleEnabled ? '模块已开启' : '模块已关闭',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (readonly)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('系统管理员固定全权限（只读展示）', style: TextStyle(fontSize: 12)),
            ),
          ...groupNames.map((groupName) {
            final items = grouped[groupName] ?? const <CapabilityPackItem>[];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text('$groupName（${items.length}）'),
                children: items.map((capability) {
                  final checked = draft.capabilityCodes.contains(
                    capability.capabilityCode,
                  );
                  final explainItem = explainByCode[capability.capabilityCode];
                  final dependencies = capability.dependencyCapabilityCodes
                      .map((code) => capabilityNameByCode[code] ?? code)
                      .toList();
                  return SwitchListTile(
                    dense: true,
                    title: Text(capability.capabilityName),
                    subtitle: Text(
                      '${statusOf(capability, checked, explainItem)}\n'
                      '入口：${capability.pageName}'
                      '${dependencies.isEmpty ? '' : '\n依赖：${dependencies.join('、')}'}'
                      '${capability.description == null || capability.description!.isEmpty ? '' : '\n说明：${capability.description}'}',
                    ),
                    value: checked,
                    onChanged: readonly || _saving
                        ? null
                        : (value) => setState(() {
                            final next = {...draft.capabilityCodes};
                            if (value) {
                              next.add(capability.capabilityCode);
                            } else {
                              next.remove(capability.capabilityCode);
                            }
                            _draftByRole[role.code] = draft.copyWith(
                              capabilityCodes: next,
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

  Widget _buildAdvancedPanel({
    required RoleItem role,
    required _RoleDraft draft,
    required CapabilityPackCatalogResult catalog,
  }) {
    final explain = _explainByRole[role.code];
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: _showAdvanced,
        onExpansionChanged: (value) => setState(() => _showAdvanced = value),
        title: const Text('高级模式（排障）'),
        subtitle: const Text('默认隐藏，仅用于排查显示和可操作性问题'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('角色：${role.name}（${role.code}）'),
                Text('模块：${_moduleLabel(catalog.moduleCode)}'),
                Text('模块开关：${draft.moduleEnabled ? '开启' : '关闭'}'),
                const SizedBox(height: 8),
                Text('草稿能力码（${draft.capabilityCodes.length}）：'),
                SelectableText(
                  (draft.capabilityCodes.toList()..sort()).join('\n'),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前生效能力码（${explain?.effectiveCapabilityCodes.length ?? 0}）：',
                ),
                SelectableText(
                  (explain?.effectiveCapabilityCodes ?? const <String>[]).join(
                    '\n',
                  ),
                ),
              ],
            ),
          ),
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
    final draft = _draftByRole[role.code];
    if (draft == null) {
      return const Center(child: Text('角色草稿异常'));
    }
    final readonly = _isReadonly(role.code);

    final keyword = _searchController.text.trim().toLowerCase();
    final capabilityPacks =
        catalog.capabilityPacks.where((item) {
          if (keyword.isEmpty) {
            return true;
          }
          return item.capabilityName.toLowerCase().contains(keyword) ||
              item.capabilityCode.toLowerCase().contains(keyword) ||
              item.groupName.toLowerCase().contains(keyword) ||
              item.pageName.toLowerCase().contains(keyword);
        }).toList()..sort((a, b) {
          final g = a.groupName.compareTo(b.groupName);
          if (g != 0) {
            return g;
          }
          return a.capabilityName.compareTo(b.capabilityName);
        });

    final roleTemplate = catalog.roleTemplates
        .where((item) => item.roleCode == role.code)
        .toList();
    final hasTemplate = roleTemplate.isNotEmpty;

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
                        width: 260,
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
                        width: 340,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: '搜索能力包名称 / 分组 / code',
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
                                if (saved == null) {
                                  return;
                                }
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
                      OutlinedButton.icon(
                        onPressed: _saving || readonly || !hasTemplate
                            ? null
                            : () => _applyRoleTemplate(
                                role: role,
                                draft: draft,
                                catalog: catalog,
                              ),
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('套用岗位模板'),
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
                      Expanded(
                        child: _buildCapabilityCard(
                          role: role,
                          draft: draft,
                          readonly: readonly,
                          catalog: catalog,
                          capabilityPacks: capabilityPacks,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: _buildAdvancedPanel(
                          role: role,
                          draft: draft,
                          catalog: catalog,
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(width: 340, child: _buildRoleSelectorCard(role)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildCapabilityCard(
                              role: role,
                              draft: draft,
                              readonly: readonly,
                              catalog: catalog,
                              capabilityPacks: capabilityPacks,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 220,
                            child: _buildAdvancedPanel(
                              role: role,
                              draft: draft,
                              catalog: catalog,
                            ),
                          ),
                        ],
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
