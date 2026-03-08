import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/authz_service.dart';
import '../services/user_service.dart';

const String _systemAdminRoleCode = 'system_admin';

enum _ModuleSwitchDecision { saveAndSwitch, discardAndSwitch, cancel }

class _PermissionGroup {
  const _PermissionGroup({required this.groupCode, required this.items});

  final String groupCode;
  final List<PermissionCatalogItem> items;
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
  DateTime? _lastSavedAt;

  List<RoleItem> _roles = const [];
  List<String> _moduleCodes = const [];
  String? _selectedModuleCode;
  List<PermissionCatalogItem> _permissions = const [];

  final Map<String, bool> _readonlyByRole = {};
  final Map<String, Set<String>> _originGrantedByRole = {};
  final Map<String, Set<String>> _draftGrantedByRole = {};

  Map<String, Set<String>>? _lastSavedBeforeSnapshot;
  String? _lastSavedSnapshotModuleCode;

  String _resourceTypeFilter = 'all';
  RolePermissionMatrixUpdateResult? _previewResult;

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

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Map<String, Set<String>> _cloneGrantedMap(Map<String, Set<String>> source) {
    return source.map((key, value) => MapEntry(key, {...value}));
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    return a.containsAll(b);
  }

  bool _hasDirtyChangesForRole(String roleCode) {
    final origin = _originGrantedByRole[roleCode] ?? const <String>{};
    final draft = _draftGrantedByRole[roleCode] ?? const <String>{};
    return !_setEquals(origin, draft);
  }

  bool get _hasDirtyChanges {
    for (final role in _roles) {
      if (_hasDirtyChangesForRole(role.code)) {
        return true;
      }
    }
    return false;
  }

  int get _dirtyRoleCount {
    var count = 0;
    for (final role in _roles) {
      if (_hasDirtyChangesForRole(role.code)) {
        count += 1;
      }
    }
    return count;
  }

  bool get _canRollbackLastSave {
    return _lastSavedBeforeSnapshot != null &&
        _selectedModuleCode != null &&
        _selectedModuleCode == _lastSavedSnapshotModuleCode;
  }

  bool _isRoleReadonly(String roleCode) {
    return _readonlyByRole[roleCode] ?? false;
  }

  String _groupCodeOfPermission(PermissionCatalogItem permission) {
    final parts = permission.permissionCode.split('.');
    if (parts.isEmpty) {
      return permission.permissionCode;
    }
    if (parts.first == 'page') {
      if (parts.length >= 2) {
        return '${parts[0]}.${parts[1]}';
      }
      return parts.first;
    }
    if (parts.length >= 2) {
      return '${parts[0]}.${parts[1]}';
    }
    return parts.first;
  }

  String _groupLabel(String groupCode) {
    if (groupCode.startsWith('page.')) {
      return '页面分组：$groupCode';
    }
    return '业务分组：$groupCode';
  }

  List<PermissionCatalogItem> _filteredPermissions() {
    final keyword = _searchController.text.trim().toLowerCase();
    return _permissions.where((permission) {
      if (_resourceTypeFilter != 'all' &&
          permission.resourceType != _resourceTypeFilter) {
        return false;
      }
      if (keyword.isEmpty) {
        return true;
      }
      return permission.permissionName.toLowerCase().contains(keyword) ||
          permission.permissionCode.toLowerCase().contains(keyword);
    }).toList();
  }

  List<_PermissionGroup> _groupedPermissions() {
    final grouped = <String, List<PermissionCatalogItem>>{};
    for (final permission in _filteredPermissions()) {
      final groupCode = _groupCodeOfPermission(permission);
      grouped.putIfAbsent(groupCode, () => []).add(permission);
    }
    final groups = grouped.entries
        .map(
          (entry) => _PermissionGroup(
            groupCode: entry.key,
            items: entry.value.toList()
              ..sort((a, b) => a.permissionCode.compareTo(b.permissionCode)),
          ),
        )
        .toList();
    groups.sort((a, b) => a.groupCode.compareTo(b.groupCode));
    return groups;
  }

  Map<String, String?> _parentByCode() {
    final validCodes = _permissions.map((item) => item.permissionCode).toSet();
    final parentByCode = <String, String?>{};
    for (final permission in _permissions) {
      final parent = permission.parentPermissionCode;
      parentByCode[permission.permissionCode] =
          parent != null && validCodes.contains(parent) ? parent : null;
    }
    return parentByCode;
  }

  Map<String, List<String>> _childrenByParent() {
    final children = <String, List<String>>{};
    final parentByCode = _parentByCode();
    for (final entry in parentByCode.entries) {
      final parent = entry.value;
      if (parent == null) {
        continue;
      }
      children.putIfAbsent(parent, () => []).add(entry.key);
    }
    return children;
  }

  Set<String> _collectAncestors(String permissionCode) {
    final parentByCode = _parentByCode();
    final ancestors = <String>{};
    var current = parentByCode[permissionCode];
    while (current != null && !ancestors.contains(current)) {
      ancestors.add(current);
      current = parentByCode[current];
    }
    return ancestors;
  }

  Set<String> _collectDescendants(String permissionCode) {
    final childrenMap = _childrenByParent();
    final descendants = <String>{};
    final queue = <String>[permissionCode];
    var index = 0;
    while (index < queue.length) {
      final code = queue[index];
      index += 1;
      for (final child in childrenMap[code] ?? const <String>[]) {
        if (descendants.add(child)) {
          queue.add(child);
        }
      }
    }
    return descendants;
  }

  void _showLinkageHint({
    required List<String> autoGranted,
    required List<String> autoRevoked,
  }) {
    if (!mounted || (autoGranted.isEmpty && autoRevoked.isEmpty)) {
      return;
    }
    final parts = <String>[];
    if (autoGranted.isNotEmpty) {
      parts.add('自动补齐父权限 ${autoGranted.join(', ')}');
    }
    if (autoRevoked.isNotEmpty) {
      parts.add('自动移除子权限 ${autoRevoked.join(', ')}');
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(parts.join('；'))));
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _message = '';
      _previewResult = null;
    });
    try {
      final roleResult = await _userService.listRoles();
      final roles = roleResult.items.toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      final allPermissions = await _authzService.listPermissionCatalog();
      final moduleCodes =
          allPermissions
              .map((item) => item.moduleCode.trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (moduleCodes.isEmpty) {
        throw StateError('权限目录中未找到可配置模块');
      }

      final initialModuleCode =
          _selectedModuleCode != null &&
              moduleCodes.contains(_selectedModuleCode)
          ? _selectedModuleCode!
          : (moduleCodes.contains('production')
                ? 'production'
                : moduleCodes.first);

      await _loadMatrixForModule(
        initialModuleCode,
        roles: roles,
        fallbackModuleCodes: moduleCodes,
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
        _message = '加载功能权限配置失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMatrixForModule(
    String moduleCode, {
    List<RoleItem>? roles,
    List<String>? fallbackModuleCodes,
  }) async {
    final matrix = await _authzService.loadRolePermissionMatrix(
      moduleCode: moduleCode,
    );
    final effectiveRoles = roles ?? _roles;
    final roleItemsByCode = <String, RolePermissionMatrixItem>{
      for (final item in matrix.roleItems) item.roleCode: item,
    };

    final originByRole = <String, Set<String>>{};
    final draftByRole = <String, Set<String>>{};
    final readonlyByRole = <String, bool>{};
    for (final role in effectiveRoles) {
      final roleItem = roleItemsByCode[role.code];
      final granted = roleItem?.grantedPermissionCodes ?? const <String>[];
      final readonly =
          roleItem?.readonly ?? (role.code == _systemAdminRoleCode);
      originByRole[role.code] = granted.toSet();
      draftByRole[role.code] = granted.toSet();
      readonlyByRole[role.code] = readonly;
    }

    if (!mounted) {
      return;
    }
    final matrixModules = matrix.moduleCodes.toList()..sort();
    final fallbackModules = fallbackModuleCodes != null
        ? (fallbackModuleCodes.toList()..sort())
        : <String>[moduleCode];

    setState(() {
      _roles = effectiveRoles;
      _permissions = matrix.permissions.toList()
        ..sort((a, b) => a.permissionCode.compareTo(b.permissionCode));
      _moduleCodes = matrix.moduleCodes.isNotEmpty
          ? matrixModules
          : fallbackModules;
      _selectedModuleCode = matrix.moduleCode;
      _readonlyByRole
        ..clear()
        ..addAll(readonlyByRole);
      _originGrantedByRole
        ..clear()
        ..addAll(originByRole);
      _draftGrantedByRole
        ..clear()
        ..addAll(draftByRole);
      _previewResult = null;
      _message = '';
    });
  }

  Future<_ModuleSwitchDecision?> _showModuleSwitchDialog() {
    return showDialog<_ModuleSwitchDecision>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('切换模块'),
          content: const Text('当前有未保存改动，切换模块前请先处理。'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_ModuleSwitchDecision.cancel),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_ModuleSwitchDecision.discardAndSwitch),
              child: const Text('放弃改动并切换'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_ModuleSwitchDecision.saveAndSwitch),
              child: const Text('保存并切换'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleModuleChange(String? moduleCode) async {
    if (moduleCode == null ||
        moduleCode == _selectedModuleCode ||
        _loading ||
        _saving) {
      return;
    }

    if (_hasDirtyChanges) {
      final decision = await _showModuleSwitchDialog();
      if (!mounted ||
          decision == null ||
          decision == _ModuleSwitchDecision.cancel) {
        return;
      }
      if (decision == _ModuleSwitchDecision.saveAndSwitch) {
        final saved = await _saveChanges();
        if (!saved) {
          return;
        }
      } else {
        _resetUnsavedChanges(showMessage: false);
      }
    }

    setState(() {
      _loading = true;
      _message = '';
      _previewResult = null;
    });
    try {
      await _loadMatrixForModule(moduleCode);
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

  void _resetUnsavedChanges({bool showMessage = true}) {
    setState(() {
      _draftGrantedByRole
        ..clear()
        ..addAll(_cloneGrantedMap(_originGrantedByRole));
      _previewResult = null;
      if (showMessage) {
        _message = '已回退未保存改动';
      }
    });
  }

  Map<String, List<String>> _buildDraftPayload() {
    final payload = <String, List<String>>{};
    for (final role in _roles) {
      final granted =
          (_draftGrantedByRole[role.code] ?? const <String>{}).toList()..sort();
      payload[role.code] = granted;
    }
    return payload;
  }

  Future<RolePermissionMatrixUpdateResult?> _requestPreview() async {
    final moduleCode = _selectedModuleCode;
    if (moduleCode == null) {
      return null;
    }
    setState(() {
      _previewing = true;
      _message = '';
    });
    try {
      final preview = await _authzService.updateRolePermissionMatrix(
        moduleCode: moduleCode,
        grantedByRoleCode: _buildDraftPayload(),
        dryRun: true,
        remark: '前端权限预览',
      );
      if (!mounted) {
        return null;
      }
      setState(() {
        _previewResult = preview;
      });
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
        _message = '生成生效预览失败：${_errorMessage(error)}';
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

  Future<bool?> _showSaveConfirmDialog(
    RolePermissionMatrixUpdateResult preview,
  ) async {
    final changedResults = preview.roleResults
        .where(
          (item) =>
              item.addedPermissionCodes.isNotEmpty ||
              item.removedPermissionCodes.isNotEmpty ||
              item.autoGrantedPermissionCodes.isNotEmpty ||
              item.autoRevokedPermissionCodes.isNotEmpty,
        )
        .toList();

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认保存权限变更'),
          content: SizedBox(
            width: 680,
            child: changedResults.isEmpty
                ? const Text('当前改动不会产生差异结果，仍要保存吗？')
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: changedResults.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.roleName} (${item.roleCode})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '新增 ${item.addedPermissionCodes.length}，移除 ${item.removedPermissionCodes.length}',
                              ),
                              if (item.autoGrantedPermissionCodes.isNotEmpty)
                                Text(
                                  '自动补齐：${item.autoGrantedPermissionCodes.join(', ')}',
                                ),
                              if (item.autoRevokedPermissionCodes.isNotEmpty)
                                Text(
                                  '自动移除：${item.autoRevokedPermissionCodes.join(', ')}',
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
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
        );
      },
    );
  }

  void _applyRoleResults(List<RolePermissionMatrixRoleResult> roleResults) {
    for (final roleResult in roleResults) {
      _originGrantedByRole[roleResult.roleCode] = roleResult
          .afterPermissionCodes
          .toSet();
      _draftGrantedByRole[roleResult.roleCode] = roleResult.afterPermissionCodes
          .toSet();
      _readonlyByRole[roleResult.roleCode] = roleResult.readonly;
    }
  }

  Future<bool> _saveChanges() async {
    final moduleCode = _selectedModuleCode;
    if (_saving || !_hasDirtyChanges || moduleCode == null) {
      return false;
    }

    final snapshotBefore = _cloneGrantedMap(_originGrantedByRole);
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      final preview = await _authzService.updateRolePermissionMatrix(
        moduleCode: moduleCode,
        grantedByRoleCode: _buildDraftPayload(),
        dryRun: true,
        remark: '前端权限保存预检',
      );
      if (!mounted) {
        return false;
      }
      final confirmed = await _showSaveConfirmDialog(preview);
      if (!mounted || confirmed != true) {
        setState(() {
          _previewResult = preview;
          _message = '已取消保存';
        });
        return false;
      }

      final result = await _authzService.updateRolePermissionMatrix(
        moduleCode: moduleCode,
        grantedByRoleCode: _buildDraftPayload(),
        dryRun: false,
        remark: '前端权限矩阵保存',
      );

      if (!mounted) {
        return false;
      }
      setState(() {
        _applyRoleResults(result.roleResults);
        _lastSavedAt = DateTime.now();
        _lastSavedBeforeSnapshot = snapshotBefore;
        _lastSavedSnapshotModuleCode = moduleCode;
        _previewResult = result;
        _message = '权限配置已保存';
      });
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      setState(() {
        _message = '保存失败：${_errorMessage(error)}';
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _rollbackLastSave() async {
    if (!_canRollbackLastSave || _saving) {
      return;
    }
    final snapshot = _lastSavedBeforeSnapshot;
    final moduleCode = _selectedModuleCode;
    if (snapshot == null || moduleCode == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('回退上次保存'),
          content: const Text('将回退到本次会话中“上次保存前”的权限状态，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认回退'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    final payload = <String, List<String>>{};
    for (final role in _roles) {
      payload[role.code] = (snapshot[role.code] ?? const <String>{}).toList()
        ..sort();
    }

    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      final result = await _authzService.updateRolePermissionMatrix(
        moduleCode: moduleCode,
        grantedByRoleCode: payload,
        dryRun: false,
        remark: '前端权限回退上次保存',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyRoleResults(result.roleResults);
        _lastSavedAt = DateTime.now();
        _lastSavedBeforeSnapshot = null;
        _lastSavedSnapshotModuleCode = null;
        _previewResult = result;
        _message = '已回退到上次保存前状态';
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

  void _togglePermission({
    required String roleCode,
    required String permissionCode,
    required bool enabled,
  }) {
    if (_saving || _isRoleReadonly(roleCode)) {
      return;
    }
    final current = {...(_draftGrantedByRole[roleCode] ?? <String>{})};
    final autoGranted = <String>[];
    final autoRevoked = <String>[];
    if (enabled) {
      current.add(permissionCode);
      final ancestors = _collectAncestors(permissionCode).toList()..sort();
      for (final ancestor in ancestors) {
        if (current.add(ancestor)) {
          autoGranted.add(ancestor);
        }
      }
    } else {
      current.remove(permissionCode);
      final descendants = _collectDescendants(permissionCode).toList()..sort();
      for (final descendant in descendants) {
        if (current.remove(descendant)) {
          autoRevoked.add(descendant);
        }
      }
    }

    setState(() {
      _draftGrantedByRole[roleCode] = current;
      _previewResult = null;
    });
    _showLinkageHint(autoGranted: autoGranted, autoRevoked: autoRevoked);
  }

  void _setAllForRole(String roleCode, bool granted) {
    if (_saving || _isRoleReadonly(roleCode)) {
      return;
    }
    setState(() {
      _draftGrantedByRole[roleCode] = granted
          ? _permissions.map((item) => item.permissionCode).toSet()
          : <String>{};
      _previewResult = null;
    });
  }

  void _setGroupForRole({
    required String roleCode,
    required _PermissionGroup group,
    required bool granted,
  }) {
    if (_saving || _isRoleReadonly(roleCode)) {
      return;
    }
    final current = {...(_draftGrantedByRole[roleCode] ?? <String>{})};
    final autoGranted = <String>[];
    final autoRevoked = <String>[];

    if (granted) {
      for (final item in group.items) {
        current.add(item.permissionCode);
        final ancestors = _collectAncestors(item.permissionCode).toList()
          ..sort();
        for (final ancestor in ancestors) {
          if (current.add(ancestor)) {
            autoGranted.add(ancestor);
          }
        }
      }
    } else {
      for (final item in group.items) {
        current.remove(item.permissionCode);
        final descendants = _collectDescendants(item.permissionCode).toList()
          ..sort();
        for (final descendant in descendants) {
          if (current.remove(descendant)) {
            autoRevoked.add(descendant);
          }
        }
      }
    }

    setState(() {
      _draftGrantedByRole[roleCode] = current;
      _previewResult = null;
    });
    _showLinkageHint(autoGranted: autoGranted, autoRevoked: autoRevoked);
  }

  String _buildProductionCapabilitySummary(Set<String> permissionCodes) {
    final entries = <String, String>{
      '创建订单': 'production.orders.create',
      '编辑订单': 'production.orders.update',
      '删除订单': 'production.orders.delete',
      '结束订单': 'production.orders.complete',
      '并行模式设置': 'production.orders.pipeline_mode.update',
      '首件': 'production.execution.first_article',
      '报工': 'production.execution.end_production',
      '发起代班': 'production.assist_authorizations.create',
      '手工送修建单': 'production.repair_orders.create_manual',
      '数据导出': 'production.data.manual.export',
      '报废导出': 'production.scrap_statistics.export',
      '维修导出': 'production.repair_orders.export',
    };
    final flags = entries.entries.map((entry) {
      final enabled = permissionCodes.contains(entry.value);
      return '${entry.key}${enabled ? '✓' : '✗'}';
    }).toList();
    return flags.join(' / ');
  }

  Widget _buildPreviewPanel() {
    final preview = _previewResult;
    if (preview == null) {
      return const SizedBox.shrink();
    }
    final moduleCode = _selectedModuleCode ?? preview.moduleCode;
    final roleNameByCode = {for (final role in _roles) role.code: role.name};

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview.dryRun ? '生效预览（未保存）' : '最近保存结果',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('模块：$moduleCode'),
            const SizedBox(height: 10),
            ...preview.roleResults.map((roleResult) {
              final roleName =
                  roleNameByCode[roleResult.roleCode] ?? roleResult.roleName;
              final afterSet = roleResult.afterPermissionCodes.toSet();
              final pageCount = roleResult.afterPermissionCodes
                  .where((code) => code.startsWith('page.'))
                  .length;
              final actionCount =
                  roleResult.afterPermissionCodes.length - pageCount;
              final changedCount =
                  roleResult.addedPermissionCodes.length +
                  roleResult.removedPermissionCodes.length;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$roleName (${roleResult.roleCode})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '总权限 ${roleResult.afterPermissionCodes.length} | 页面 $pageCount | 动作 $actionCount | 变更 $changedCount',
                    ),
                    if (moduleCode == 'production')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _buildProductionCapabilitySummary(afterSet),
                        ),
                      ),
                    if (roleResult.autoGrantedPermissionCodes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '自动补齐：${roleResult.autoGrantedPermissionCodes.join(', ')}',
                        ),
                      ),
                    if (roleResult.autoRevokedPermissionCodes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '自动移除：${roleResult.autoRevokedPermissionCodes.join(', ')}',
                        ),
                      ),
                    if (roleResult.ignoredInput)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('系统管理员固定全权限，输入已忽略。'),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePermissionPane(RoleItem role) {
    final granted = _draftGrantedByRole[role.code] ?? const <String>{};
    final groups = _groupedPermissions();
    final readonly = _isRoleReadonly(role.code);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('角色：${role.name} (${role.code})'),
                  const SizedBox(width: 8),
                  if (readonly)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: const Text(
                        '系统管理员固定全权限（只读）',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  const Spacer(),
                  Text('已授权 ${granted.length}/${_permissions.length}'),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: readonly || _saving
                        ? null
                        : () => _setAllForRole(role.code, true),
                    child: const Text('全选'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: readonly || _saving
                        ? null
                        : () => _setAllForRole(role.code, false),
                    child: const Text('清空'),
                  ),
                ],
              ),
              if (readonly)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '提示：system_admin 始终拥有全部权限，该角色仅用于只读展示。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('当前筛选条件下无可配置权限'))
              : ListView(
                  children: groups.map((group) {
                    final groupGrantedCount = group.items
                        .where((item) => granted.contains(item.permissionCode))
                        .length;
                    final allGranted = groupGrantedCount == group.items.length;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: group.groupCode.startsWith('page.'),
                        title: Text(
                          '${_groupLabel(group.groupCode)} '
                          '($groupGrantedCount/${group.items.length})',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: readonly || _saving
                                  ? null
                                  : () => _setGroupForRole(
                                      roleCode: role.code,
                                      group: group,
                                      granted: !allGranted,
                                    ),
                              child: Text(allGranted ? '清空组' : '全选组'),
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                        children: group.items.map((item) {
                          final checked = granted.contains(item.permissionCode);
                          final subtitle = item.parentPermissionCode == null
                              ? item.permissionCode
                              : '${item.permissionCode}\n父权限：${item.parentPermissionCode}';
                          return SwitchListTile(
                            dense: true,
                            title: Text(item.permissionName),
                            subtitle: Text(subtitle),
                            value: checked,
                            onChanged: readonly || _saving
                                ? null
                                : (enabled) => _togglePermission(
                                    roleCode: role.code,
                                    permissionCode: item.permissionCode,
                                    enabled: enabled,
                                  ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_roles.isEmpty || _selectedModuleCode == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_message.isEmpty ? '未加载到角色或模块数据' : _message),
        ),
      );
    }

    final statusText = _lastSavedAt == null
        ? '尚未保存'
        : '上次保存：${_formatTime(_lastSavedAt!)}';

    return DefaultTabController(
      key: ValueKey(
        '$_selectedModuleCode|${_roles.map((item) => item.code).join('|')}',
      ),
      length: _roles.length,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '功能权限配置',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                  child: const Text('system_admin 固定全权限'),
                ),
                const Spacer(),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _selectedModuleCode,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: '模块',
                    ),
                    items: _moduleCodes
                        .map(
                          (code) => DropdownMenuItem<String>(
                            value: code,
                            child: Text(code),
                          ),
                        )
                        .toList(),
                    onChanged: _saving ? null : _handleModuleChange,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _saving
                      ? null
                      : () => _handleModuleChange(_selectedModuleCode),
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saving || _previewing ? null : _requestPreview,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(_previewing ? '预览中...' : '生效预览'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _saving || !_hasDirtyChanges
                      ? null
                      : () => _resetUnsavedChanges(showMessage: true),
                  child: const Text('回退未保存'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _saving || !_canRollbackLastSave
                      ? null
                      : _rollbackLastSave,
                  child: const Text('回退上次保存'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving || !_hasDirtyChanges ? null : _saveChanges,
                  icon: const Icon(Icons.save),
                  label: Text(_saving ? '保存中...' : '保存'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: '搜索权限名称或编码',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _resourceTypeFilter,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: '类型',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('全部类型')),
                      DropdownMenuItem(value: 'page', child: Text('页面权限')),
                      DropdownMenuItem(value: 'action', child: Text('动作权限')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _resourceTypeFilter = value;
                            });
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$statusText | 未保存角色：$_dirtyRoleCount'),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            _buildPreviewPanel(),
            const SizedBox(height: 12),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: TabBar(
                isScrollable: true,
                tabs: _roles.map((role) => Tab(text: role.name)).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: _roles.map(_buildRolePermissionPane).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
