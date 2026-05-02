import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/user/presentation/widgets/function_permission_action_dialogs.dart';
import 'package:mes_client/features/user/presentation/widgets/function_permission_config_page_header.dart';
import 'package:mes_client/features/user/services/user_service.dart';

const Map<String, String> _moduleNameFallbackZh = {
  'user': '用户管理',
  'product': '产品管理',
  'equipment': '设备管理',
  'craft': '工艺管理',
  'quality': '质量管理',
  'production': '生产管理',
  'message': '消息中心',
};

const List<String> _allowedModuleCodes = [
  'user',
  'product',
  'craft',
  'quality',
  'production',
  'equipment',
  'message',
];

const String _systemModuleCode = 'system';
const String _systemAdminRoleCode = 'system_admin';
const String _systemRolePermissionManageCapability =
    'feature.system.role_permissions.manage';
const Set<String> _hiddenCapabilityCodes = {
  'feature.system.role_permissions.manage',
  'feature.user.login_session.force_offline',
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
    this.authzService,
    this.userService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final Future<void> Function()? onPermissionsChanged;
  final AuthzService? authzService;
  final UserService? userService;

  @override
  State<FunctionPermissionConfigPage> createState() =>
      _FunctionPermissionConfigPageState();
}

class _FunctionPermissionConfigPageState
    extends State<FunctionPermissionConfigPage> {
  late final AuthzService _authzService;
  late final UserService _userService;

  bool _loading = false;
  bool _saving = false;
  String _message = '';

  List<RoleItem> _roles = const [];
  List<String> _moduleCodes = const [];
  String? _selectedModuleCode;
  String? _selectedRoleCode;

  final Map<String, CapabilityPackCatalogResult> _catalogByModule = {};
  final Map<String, _RoleDraft> _originByRole = {};
  final Map<String, _RoleDraft> _draftByRole = {};
  final Map<String, bool> _readonlyByRole = {};

  @override
  void initState() {
    super.initState();
    _authzService = widget.authzService ?? AuthzService(widget.session);
    _userService = widget.userService ?? UserService(widget.session);
    _loadInitialData();
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

  String _actionErrorMessage(String action, Object error) {
    if (error is ApiException) {
      if (error.statusCode == 409) {
        return '$action失败：当前模块版本已变化，请刷新后重试。';
      }
      return '$action失败：${error.message}';
    }
    return '$action失败：${error.toString()}';
  }

  String _moduleLabel(String moduleCode) {
    final fromCatalog = _catalogByModule[moduleCode]?.moduleName.trim();
    if (fromCatalog != null && fromCatalog.isNotEmpty) {
      return fromCatalog;
    }
    return _moduleNameFallbackZh[moduleCode] ?? moduleCode;
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

  bool _isSystemPermissionGuardRole(String roleCode) {
    return _selectedModuleCode == _systemModuleCode &&
        roleCode == _systemAdminRoleCode;
  }

  bool _isLockedCapability(String roleCode, String capabilityCode) {
    return _isSystemPermissionGuardRole(roleCode) &&
        capabilityCode == _systemRolePermissionManageCapability;
  }

  bool _draftEquals(_RoleDraft a, _RoleDraft b) {
    if (a.moduleEnabled != b.moduleEnabled) {
      return false;
    }
    if (a.capabilityCodes.length != b.capabilityCodes.length) {
      return false;
    }
    return a.capabilityCodes.containsAll(b.capabilityCodes);
  }

  bool _hasDirtyRole(String roleCode) {
    final origin = _originByRole[roleCode];
    final draft = _draftByRole[roleCode];
    if (origin == null || draft == null) {
      return false;
    }
    return !_draftEquals(origin, draft);
  }

  List<String> _filterAllowedModuleCodes(List<String> moduleCodes) {
    final moduleCodeSet = moduleCodes.toSet();
    return _allowedModuleCodes
        .where((moduleCode) => moduleCodeSet.contains(moduleCode))
        .toList();
  }

  bool get _hasDirty {
    for (final role in _roles) {
      if (_hasDirtyRole(role.code)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final roleResult = await _userService.listAllRoles();
      final roles = roleResult.items.toList()..sort((a, b) => a.id - b.id);
      if (roles.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _roles = const [];
          _moduleCodes = const [];
          _selectedRoleCode = null;
          _selectedModuleCode = null;
          _message = '暂无可配置角色。';
        });
        return;
      }

      final bootstrap = await _authzService.loadCapabilityPackCatalog(
        moduleCode: _selectedModuleCode ?? 'user',
      );
      _catalogByModule[bootstrap.moduleCode] = bootstrap;
      final modules = _filterAllowedModuleCodes(bootstrap.moduleCodes);
      if (modules.isEmpty) {
        throw StateError('未查询到可配置模块');
      }

      final initialModule = modules.contains('user')
          ? 'user'
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
    final effectiveRoles = roles ?? _roles;
    if (effectiveRoles.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _roles = const [];
        _moduleCodes = const [];
        _selectedRoleCode = null;
        _selectedModuleCode = null;
        _originByRole.clear();
        _draftByRole.clear();
        _readonlyByRole.clear();
        _message = '暂无可配置角色。';
      });
      return;
    }

    final catalog = await _authzService.loadCapabilityPackCatalog(
      moduleCode: moduleCode,
    );
    _catalogByModule[catalog.moduleCode] = catalog;
    final effectiveModuleCodes = _filterAllowedModuleCodes(
      (moduleCodes ?? catalog.moduleCodes).toList(),
    );
    if (effectiveModuleCodes.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _roles = effectiveRoles;
        _moduleCodes = const [];
        _selectedModuleCode = null;
        _selectedRoleCode = effectiveRoles.first.code;
        _originByRole.clear();
        _draftByRole.clear();
        _readonlyByRole.clear();
        _message = '暂无可配置模块。';
      });
      return;
    }

    final selectedModuleCode = effectiveModuleCodes.contains(catalog.moduleCode)
        ? catalog.moduleCode
        : effectiveModuleCodes.first;
    if (selectedModuleCode != catalog.moduleCode) {
      await _loadModuleData(
        selectedModuleCode,
        roles: effectiveRoles,
        moduleCodes: effectiveModuleCodes,
      );
      return;
    }

    final configs = await Future.wait(
      effectiveRoles.map(
        (role) => _authzService.loadCapabilityPackRoleConfig(
          roleCode: role.code,
          moduleCode: catalog.moduleCode,
        ),
      ),
    );

    final originByRole = <String, _RoleDraft>{};
    final draftByRole = <String, _RoleDraft>{};
    final readonlyByRole = <String, bool>{};
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
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _roles = effectiveRoles;
      _moduleCodes = effectiveModuleCodes;
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
      final discard = await showFunctionPermissionDiscardDialog(
        context: context,
      );
      if (!discard) {
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

  Future<void> _refreshCurrentModule() async {
    final moduleCode = _selectedModuleCode;
    if (moduleCode == null || _loading || _saving) {
      return;
    }
    if (_hasDirty) {
      final discard = await showFunctionPermissionDiscardDialog(
        context: context,
      );
      if (!discard) {
        return;
      }
    }

    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      await _loadModuleData(
        moduleCode,
        roles: _roles,
        moduleCodes: _moduleCodes,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '刷新页面失败：${_errorMessage(error)}';
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
    final moduleCode = _selectedModuleCode;
    if (_saving || !_hasDirty || moduleCode == null) {
      return;
    }

    final confirm = await showFunctionPermissionSaveDialog(context: context);
    if (!confirm) {
      return;
    }

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
    if (dirtyRoleItems.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      final moduleRevision = _catalogByModule[moduleCode]?.moduleRevision ?? 0;
      await _authzService.applyCapabilityPacks(
        moduleCode: moduleCode,
        roleItems: dirtyRoleItems,
        expectedRevision: moduleRevision,
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
        _message = '保存成功。';
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
        _message = _actionErrorMessage('保存', error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _setRoleModuleEnabled({
    required String roleCode,
    required _RoleDraft draft,
    required bool value,
  }) {
    if (_isSystemPermissionGuardRole(roleCode) && !value) {
      return;
    }
    setState(() {
      _draftByRole[roleCode] = draft.copyWith(
        moduleEnabled: value,
        capabilityCodes: value ? draft.capabilityCodes : <String>{},
      );
    });
  }

  void _setCapabilityChecked({
    required String roleCode,
    required _RoleDraft draft,
    required String capabilityCode,
    required bool value,
  }) {
    if (_isLockedCapability(roleCode, capabilityCode) && !value) {
      return;
    }
    final next = {...draft.capabilityCodes};
    if (value) {
      next.add(capabilityCode);
    } else {
      next.remove(capabilityCode);
    }
    setState(() {
      _draftByRole[roleCode] = draft.copyWith(
        moduleEnabled: value ? true : draft.moduleEnabled,
        capabilityCodes: next,
      );
    });
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
                final count = draft == null ? 0 : draft.capabilityCodes.length;
                return ListTile(
                  dense: true,
                  selected: selected,
                  onTap: () => setState(() => _selectedRoleCode = role.code),
                  title: Text(role.name),
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
    required List<CapabilityPackItem> capabilityPacks,
  }) {
    final grouped = <String, List<CapabilityPackItem>>{};
    for (final item in capabilityPacks) {
      grouped
          .putIfAbsent(item.groupName, () => <CapabilityPackItem>[])
          .add(item);
    }
    final groupNames = grouped.keys.toList()..sort();
    for (final groupName in groupNames) {
      grouped[groupName]!.sort(
        (a, b) => a.capabilityName.compareTo(b.capabilityName),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSystemPermissionGuardRole(role.code))
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '系统管理员的功能权限配置入口与保存能力为系统保底能力，不允许关闭。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
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
                          : (value) => _setRoleModuleEnabled(
                              roleCode: role.code,
                              draft: draft,
                              value: value,
                            ),
                    ),
                    Text(
                      draft.moduleEnabled ? '模块已开启' : '模块已关闭',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                if (readonly)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '当前角色为只读，权限项不可编辑。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: groupNames.map((groupName) {
                final items = grouped[groupName] ?? const <CapabilityPackItem>[];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text('$groupName（${items.length}）'),
                    children: items.map((capability) {
                      final checked = draft.capabilityCodes.contains(
                        capability.capabilityCode,
                      );
                      final description = capability.description;
                      final hasDescription =
                          description != null && description.trim().isNotEmpty;
                      final lockedCapability = _isLockedCapability(
                        role.code,
                        capability.capabilityCode,
                      );
                      return SwitchListTile(
                        dense: true,
                        title: Text(capability.capabilityName),
                        subtitle: Text(
                          hasDescription
                              ? '入口：${capability.pageName}\n说明：$description'
                              : '入口：${capability.pageName}',
                        ),
                        value: checked,
                        onChanged: readonly || _saving
                            ? null
                            : (value) => _setCapabilityChecked(
                                roleCode: role.code,
                                draft: draft,
                                capabilityCode: capability.capabilityCode,
                                value: value,
                              ),
                        secondary: lockedCapability
                            ? const Icon(Icons.lock_outline, size: 18)
                            : null,
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
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
                        child: Text(_moduleLabel(code)),
                      ),
                    )
                    .toList(),
                onChanged: _saving ? null : _switchModule,
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              container: true,
              label: '功能权限配置保存按钮',
              button: true,
              child: FilledButton.icon(
                onPressed: _saving || !_hasDirty ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? '保存中...' : '保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MesLoadingState(label: '权限配置加载中...');
    }

    final catalog = _catalog;
    if (catalog == null) {
      return Center(child: Text(_message.isEmpty ? '暂无数据' : _message));
    }
    if (_roles.isEmpty) {
      return const Center(child: Text('暂无可配置角色'));
    }
    final role = _selectedRole;
    if (role == null) {
      return const Center(child: Text('暂无可配置角色'));
    }
    final draft = _draftByRole[role.code];
    if (draft == null) {
      return const Center(child: Text('角色草稿异常'));
    }
    final readonly = _isReadonly(role.code);

    final capabilityPacks =
        [
          ...catalog.capabilityPacks.where(
            (item) => !_hiddenCapabilityCodes.contains(item.capabilityCode),
          ),
        ]..sort((a, b) {
          final groupCompare = a.groupName.compareTo(b.groupName);
          if (groupCompare != 0) {
            return groupCompare;
          }
          return a.capabilityName.compareTo(b.capabilityName);
        });

    return Semantics(
      container: true,
      label: '功能权限配置主区域',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FunctionPermissionConfigPageHeader(
              loading: _loading,
              onRefresh: _refreshCurrentModule,
            ),
            const SizedBox(height: 12),
            _buildFilterCard(),
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
                            capabilityPacks: capabilityPacks,
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(
                        width: 340,
                        child: _buildRoleSelectorCard(role),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCapabilityCard(
                          role: role,
                          draft: draft,
                          readonly: readonly,
                          capabilityPacks: capabilityPacks,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
