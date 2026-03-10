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

class _ConfirmActionResult {
  const _ConfirmActionResult({
    required this.confirmed,
    required this.remark,
  });

  final bool confirmed;
  final String? remark;
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
  final Map<String, CapabilityPackChangeLogListResult> _historyByModule = {};

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

  String _actionErrorMessage(String action, Object error) {
    if (error is ApiException) {
      if (error.statusCode == 409) {
        return '$action失败：当前模块 revision 已变化，请刷新后重试。';
      }
      return '$action失败：${error.message}';
    }
    return '$action失败：${error.toString()}';
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

  Map<String, String> _capabilityNameByCode(String? moduleCode) {
    final catalog = moduleCode == null ? null : _catalogByModule[moduleCode];
    if (catalog == null) {
      return const {};
    }
    return {
      for (final item in catalog.capabilityPacks)
        item.capabilityCode: item.capabilityName,
    };
  }

  String _capabilityLabel(String code, String? moduleCode) {
    return _capabilityNameByCode(moduleCode)[code] ?? code;
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

    final confirmResult = await _showPreviewConfirmDialog(
      title: '确认保存',
      description: '将按当前草稿覆盖所选模块权限。请确认本次能力变更，并可补充审计备注。',
      confirmLabel: '确认保存',
      preview: preview,
      initialRemark: '能力包权限配置保存',
    );
    if (confirmResult?.confirmed != true) {
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
        remark: confirmResult?.remark,
      );

      await _loadModuleData(
        moduleCode,
        roles: _roles,
        moduleCodes: _moduleCodes,
      );
      _historyByModule.remove(moduleCode);
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
      _historyByModule.remove(moduleCode);
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
        _message = _actionErrorMessage('恢复上次保存前草稿', error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<CapabilityPackChangeLogListResult?> _loadHistory(
    String moduleCode, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = _historyByModule[moduleCode];
      if (cached != null) {
        return cached;
      }
    }
    try {
      final history = await _authzService.loadCapabilityPackHistory(
        moduleCode: moduleCode,
        limit: 20,
      );
      _historyByModule[moduleCode] = history;
      return history;
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return null;
      }
      if (mounted) {
        setState(() {
          _message = '加载变更历史失败：${_errorMessage(error)}';
        });
      }
      return null;
    }
  }

  String _formatChangeLogSubtitle(CapabilityPackChangeLogItem item) {
    final operator = item.operatorUsername?.trim().isNotEmpty == true
        ? item.operatorUsername!
        : '未知操作者';
    final remark = item.remark?.trim();
    final label = item.changeType == 'rollback' ? '回滚' : '保存';
    final parts = <String>[
      label,
      operator,
      '变更角色 ${item.changedRoleCount} 个',
      '+${item.addedCapabilityCount}',
      '-${item.removedCapabilityCount}',
      item.createdAt.toLocal().toString().replaceFirst('.000', ''),
    ];
    if (remark != null && remark.isNotEmpty) {
      parts.add(remark);
    }
    return parts.join(' | ');
  }

  Widget _buildCapabilityCodeChips(
    List<String> codes, {
    required String moduleCode,
    required String emptyLabel,
    Color? backgroundColor,
  }) {
    if (codes.isEmpty) {
      return Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall);
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: codes
          .map(
            (code) => Chip(
              label: Text(_capabilityLabel(code, moduleCode)),
              visualDensity: VisualDensity.compact,
              backgroundColor: backgroundColor,
            ),
          )
          .toList(),
    );
  }

  Widget _buildRoleResultPanel(
    CapabilityPackRoleUpdateResult item, {
    required String moduleCode,
  }) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.roleName} · 变更 ${item.updatedCount}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text('新增能力'),
            const SizedBox(height: 4),
            _buildCapabilityCodeChips(
              item.addedCapabilityCodes,
              moduleCode: moduleCode,
              emptyLabel: '无新增能力',
              backgroundColor: const Color(0xFFE8F5E9),
            ),
            const SizedBox(height: 8),
            Text('移除能力'),
            const SizedBox(height: 4),
            _buildCapabilityCodeChips(
              item.removedCapabilityCodes,
              moduleCode: moduleCode,
              emptyLabel: '无移除能力',
              backgroundColor: const Color(0xFFFFEBEE),
            ),
            const SizedBox(height: 8),
            Text('自动补依赖'),
            const SizedBox(height: 4),
            _buildCapabilityCodeChips(
              item.autoLinkedDependencies,
              moduleCode: moduleCode,
              emptyLabel: '无自动补依赖',
              backgroundColor: const Color(0xFFFFF8E1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewDetails(CapabilityPackPreviewResult preview) {
    final changedItems = preview.roleResults
        .where(
          (item) =>
              item.addedCapabilityCodes.isNotEmpty ||
              item.removedCapabilityCodes.isNotEmpty ||
              item.autoLinkedDependencies.isNotEmpty ||
              item.updatedCount > 0,
        )
        .toList();
    if (changedItems.isEmpty) {
      return const Text('本次不会产生任何能力变更。');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: changedItems
          .map(
            (item) => _buildRoleResultPanel(
              item,
              moduleCode: preview.moduleCode,
            ),
          )
          .toList(),
    );
  }

  Future<_ConfirmActionResult?> _showPreviewConfirmDialog({
    required String title,
    required String description,
    required String confirmLabel,
    required CapabilityPackPreviewResult preview,
    String? initialRemark,
  }) async {
    final controller = TextEditingController(text: initialRemark ?? '');
    try {
      return await showDialog<_ConfirmActionResult>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(description),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: '审计备注（可选）',
                      border: OutlineInputBorder(),
                      hintText: '例如：回收旧配置、补齐生产模块能力包',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildPreviewDetails(preview),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                const _ConfirmActionResult(confirmed: false, remark: null),
              ),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _ConfirmActionResult(
                  confirmed: true,
                  remark: controller.text.trim().isEmpty
                      ? null
                      : controller.text.trim(),
                ),
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showHistoryDialog() async {
    final moduleCode = _selectedModuleCode;
    if (moduleCode == null || _saving) {
      return;
    }
    final history = await _loadHistory(moduleCode, force: true);
    if (!mounted || history == null) {
      return;
    }
    final selected = await showDialog<CapabilityPackChangeLogItem>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('变更历史 - ${_moduleLabel(moduleCode)}'),
          content: SizedBox(
            width: 820,
            child: history.items.isEmpty
                ? const Text('当前模块暂无历史记录。')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.items.length,
                    separatorBuilder: (context, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = history.items[index];
                      final rollbackLabel = item.isCurrentRevision
                          ? '当前版本'
                          : item.isNoop
                          ? '无需回滚'
                          : '预览回滚';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'revision ${item.moduleRevision}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      Chip(
                                        label: Text(
                                          item.changeType == 'rollback'
                                              ? '回滚'
                                              : '保存',
                                        ),
                                      ),
                                      if (item.isCurrentRevision)
                                        const Chip(label: Text('当前 revision')),
                                      if (item.rollbackOfRevision != null)
                                        Chip(
                                          label: Text(
                                            '来源 revision ${item.rollbackOfRevision}',
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_formatChangeLogSubtitle(item)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text('变更角色 ${item.changedRoleCount}'),
                                  ),
                                  Chip(
                                    label: Text('新增 ${item.addedCapabilityCount}'),
                                  ),
                                  Chip(
                                    label: Text('移除 ${item.removedCapabilityCount}'),
                                  ),
                                  Chip(
                                    label: Text(
                                      '依赖 ${item.autoLinkedDependencyCount}',
                                    ),
                                  ),
                                ],
                              ),
                              if (item.roleResults.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...item.roleResults
                                    .where((entry) => entry.updatedCount > 0)
                                    .take(3)
                                    .map(
                                      (entry) => Text(
                                        '${entry.roleName}: +${entry.addedCapabilityCodes.length} / -${entry.removedCapabilityCodes.length} / 依赖${entry.autoLinkedDependencies.length}',
                                      ),
                                    ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: item.canRollback
                                      ? () => Navigator.of(context).pop(item)
                                      : null,
                                  child: Text(rollbackLabel),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
      _message = '';
    });
    late final CapabilityPackPreviewResult rollbackPreview;
    try {
      rollbackPreview = await _authzService.previewRollbackCapabilityPacks(
        moduleCode: moduleCode,
        changeLogId: selected.changeLogId,
      );
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        setState(() {
          _message = _actionErrorMessage('加载回滚预览', error);
          _saving = false;
        });
      }
      return;
    }
    if (!mounted) {
      return;
    }
    if (mounted) {
      setState(() {
        _saving = false;
      });
    }
    final confirmResult = await _showPreviewConfirmDialog(
      title: '确认服务端回滚',
      description: '将模块回滚到 revision ${selected.moduleRevision}。确认后会生成新的审计记录。',
      confirmLabel: '确认回滚',
      preview: rollbackPreview,
      initialRemark: '回滚到 revision ${selected.moduleRevision}',
    );
    if (confirmResult?.confirmed != true || !mounted) {
      setState(() {
        _activePreview = rollbackPreview;
        _showPreview = true;
        _activePreviewIsSaved = false;
      });
      return;
    }
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      final currentRevision = _catalogByModule[moduleCode]?.moduleRevision ?? 0;
      final rolledBack = await _authzService.rollbackCapabilityPacks(
        moduleCode: moduleCode,
        changeLogId: selected.changeLogId,
        expectedRevision: currentRevision,
        remark: confirmResult?.remark,
      );
      await _loadModuleData(
        moduleCode,
        roles: _roles,
        moduleCodes: _moduleCodes,
      );
      await _loadHistory(moduleCode, force: true);
      await widget.onPermissionsChanged?.call();
      if (!mounted) {
        return;
      }
      setState(() {
        _lastSavedByModule[moduleCode] = rolledBack;
        _message = '已回滚到 revision ${selected.moduleRevision}。';
      });
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = _actionErrorMessage('服务端回滚', error);
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
            _buildPreviewDetails(preview),
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
                          capabilityCodes: value
                              ? draft.capabilityCodes
                              : <String>{},
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
                              moduleEnabled: value ? true : draft.moduleEnabled,
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
                      Chip(label: Text('当前 revision ${catalog.moduleRevision}')),
                      OutlinedButton.icon(
                        onPressed: _saving || _previewing ? null : _preview,
                        icon: const Icon(Icons.visibility),
                        label: Text(_previewing ? '预览中...' : '生效预览'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _showHistoryDialog,
                        icon: const Icon(Icons.history_toggle_off),
                        label: const Text('查看变更历史'),
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
                        label: const Text('放弃未保存变更'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving || !_canRollbackLastSave
                            ? null
                            : _rollbackLastSave,
                        icon: const Icon(Icons.restore),
                        label: const Text('恢复上次保存前草稿'),
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
