import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/authz_service.dart';
import '../services/user_service.dart';

class _PermissionGroup {
  const _PermissionGroup({
    required this.resourceType,
    required this.items,
  });

  final String resourceType;
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
  static const String _moduleCode = 'production';

  late final AuthzService _authzService;
  late final UserService _userService;

  bool _loading = false;
  bool _saving = false;
  String _message = '';
  DateTime? _lastSavedAt;

  List<RoleItem> _roles = const [];
  List<PermissionCatalogItem> _permissions = const [];

  final Map<String, Set<String>> _originGrantedByRole = {};
  final Map<String, Set<String>> _draftGrantedByRole = {};

  @override
  void initState() {
    super.initState();
    _authzService = AuthzService(widget.session);
    _userService = UserService(widget.session);
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

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  String _resourceTypeLabel(String resourceType) {
    switch (resourceType) {
      case 'page':
        return '页面权限';
      case 'action':
        return '动作权限';
      default:
        return resourceType;
    }
  }

  List<_PermissionGroup> _groupedPermissions() {
    final grouped = <String, List<PermissionCatalogItem>>{};
    for (final permission in _permissions) {
      grouped.putIfAbsent(permission.resourceType, () => []).add(permission);
    }
    final groups = grouped.entries
        .map(
          (entry) => _PermissionGroup(
            resourceType: entry.key,
            items: entry.value.toList()
              ..sort((a, b) => a.permissionCode.compareTo(b.permissionCode)),
          ),
        )
        .toList();
    groups.sort((a, b) => a.resourceType.compareTo(b.resourceType));
    return groups;
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final roleResult = await _userService.listRoles();
      final permissions = await _authzService.listPermissionCatalog(
        moduleCode: _moduleCode,
      );
      final roles = roleResult.items.toList()..sort((a, b) => a.id.compareTo(b.id));

      final grantedByRole = <String, Set<String>>{};
      for (final role in roles) {
        final result = await _authzService.getRolePermissions(
          roleCode: role.code,
          moduleCode: _moduleCode,
        );
        grantedByRole[role.code] = result.items
            .where((item) => item.granted)
            .map((item) => item.permissionCode)
            .toSet();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _roles = roles;
        _permissions = permissions;
        _originGrantedByRole
          ..clear()
          ..addAll(grantedByRole.map((key, value) => MapEntry(key, {...value})));
        _draftGrantedByRole
          ..clear()
          ..addAll(grantedByRole.map((key, value) => MapEntry(key, {...value})));
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

  bool _hasDirtyChangesForRole(String roleCode) {
    final origin = _originGrantedByRole[roleCode] ?? const <String>{};
    final draft = _draftGrantedByRole[roleCode] ?? const <String>{};
    if (origin.length != draft.length) {
      return true;
    }
    return !origin.containsAll(draft);
  }

  bool get _hasDirtyChanges {
    for (final role in _roles) {
      if (_hasDirtyChangesForRole(role.code)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveChanges() async {
    if (_saving || !_hasDirtyChanges) {
      return;
    }
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      for (final role in _roles) {
        if (!_hasDirtyChangesForRole(role.code)) {
          continue;
        }
        final draft = (_draftGrantedByRole[role.code] ?? const <String>{})
            .toList()
          ..sort();
        await _authzService.updateRolePermissions(
          roleCode: role.code,
          moduleCode: _moduleCode,
          grantedPermissionCodes: draft,
          remark: '前端权限矩阵保存',
        );
        _originGrantedByRole[role.code] = {...draft};
      }

      _lastSavedAt = DateTime.now();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '权限配置已保存';
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

  void _togglePermission({
    required String roleCode,
    required String permissionCode,
    required bool enabled,
  }) {
    setState(() {
      final current = {...(_draftGrantedByRole[roleCode] ?? <String>{})};
      if (enabled) {
        current.add(permissionCode);
      } else {
        current.remove(permissionCode);
      }
      _draftGrantedByRole[roleCode] = current;
    });
  }

  void _setAllForRole(String roleCode, bool granted) {
    setState(() {
      if (granted) {
        _draftGrantedByRole[roleCode] =
            _permissions.map((item) => item.permissionCode).toSet();
      } else {
        _draftGrantedByRole[roleCode] = <String>{};
      }
    });
  }

  void _setGroupForRole({
    required String roleCode,
    required _PermissionGroup group,
    required bool granted,
  }) {
    setState(() {
      final current = {...(_draftGrantedByRole[roleCode] ?? <String>{})};
      if (granted) {
        for (final item in group.items) {
          current.add(item.permissionCode);
        }
      } else {
        for (final item in group.items) {
          current.remove(item.permissionCode);
        }
      }
      _draftGrantedByRole[roleCode] = current;
    });
  }

  Widget _buildRolePermissionPane(RoleItem role) {
    final granted = _draftGrantedByRole[role.code] ?? const <String>{};
    final groups = _groupedPermissions();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('角色：${role.name} (${role.code})'),
              const Spacer(),
              Text('已授权 ${granted.length}/${_permissions.length}'),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _saving ? null : () => _setAllForRole(role.code, true),
                child: const Text('全选'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _saving ? null : () => _setAllForRole(role.code, false),
                child: const Text('清空'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('当前模块无可配置权限'))
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
                        initiallyExpanded: group.resourceType == 'page',
                        title: Text(
                          '${_resourceTypeLabel(group.resourceType)} '
                          '($groupGrantedCount/${group.items.length})',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _saving
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
                          return SwitchListTile(
                            dense: true,
                            title: Text(item.permissionName),
                            subtitle: Text(item.permissionCode),
                            value: checked,
                            onChanged: _saving
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
    if (_roles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_message.isEmpty ? '未加载到角色数据' : _message),
        ),
      );
    }

    final statusText = _lastSavedAt == null
        ? '未保存'
        : '上次保存：${_formatTime(_lastSavedAt!)}';

    return DefaultTabController(
      length: _roles.length,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '功能权限配置（生产模块）',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _saving ? null : _loadData,
                  icon: const Icon(Icons.refresh),
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
            Text(statusText),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _message,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
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
