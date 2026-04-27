import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/widgets/role_management_page_header.dart';
import 'package:mes_client/features/user/services/user_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';

class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canCreateRole,
    required this.canEditRole,
    required this.canToggleRole,
    required this.canDeleteRole,
    this.userService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canCreateRole;
  final bool canEditRole;
  final bool canToggleRole;
  final bool canDeleteRole;
  final UserService? userService;

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  static const int _pageSize = 10;
  static const String _roleTypeBuiltin = 'builtin';
  static const String _roleTypeCustom = 'custom';
  static const String _maintenanceRoleCode = 'maintenance_staff';

  late final UserService _userService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  int _page = 1;
  List<RoleItem> _items = const [];

  int get _totalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _pageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService(widget.session);
    _loadRoles();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  String _roleTypeLabel(String roleType) {
    return roleType == _roleTypeBuiltin ? '系统内置' : '自定义';
  }

  String _statusLabel(bool enabled) => enabled ? '启用' : '停用';

  Color _statusColor(BuildContext context, bool enabled) {
    return enabled ? Colors.green : Theme.of(context).colorScheme.error;
  }

  String _generateImplicitRoleCode(String roleName) {
    final normalizedName = roleName.trim().toLowerCase();
    final buffer = StringBuffer('custom_');
    for (final rune in normalizedName.runes) {
      final char = String.fromCharCode(rune);
      final isLowerAlpha = rune >= 97 && rune <= 122;
      final isDigit = rune >= 48 && rune <= 57;
      if (isLowerAlpha || isDigit) {
        buffer.write(char);
        continue;
      }
      buffer.write(rune.toRadixString(16));
    }
    buffer.write('_');
    buffer.write(DateTime.now().millisecondsSinceEpoch.toRadixString(36));
    final generated = buffer.toString();
    if (generated.length <= 48) {
      return generated;
    }
    return generated.substring(generated.length - 48);
  }

  bool _isBuiltinSemanticsRole(RoleItem role) {
    return role.isBuiltin || role.code == _maintenanceRoleCode;
  }

  Future<void> _loadRoles({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _userService.listRoles(
        page: targetPage,
        pageSize: _pageSize,
        keyword: _keywordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _pageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = resolvedPage;
      });
      if (resolvedPage != targetPage) {
        await _loadRoles(page: resolvedPage);
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
        _message = '加载角色列表失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showRoleDialog({RoleItem? role}) async {
    if (role == null && !widget.canCreateRole) {
      return;
    }
    if (role != null && !widget.canEditRole) {
      return;
    }
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: role?.name ?? '');
    var selectedRoleType = role?.roleType == _roleTypeBuiltin
        ? _roleTypeBuiltin
        : _roleTypeCustom;
    var selectedEnabled = role?.isEnabled ?? true;
    final canEditRoleType = role == null;
    final editingExistingRole = role != null;
    final hasBuiltinSemantics = role != null && _isBuiltinSemanticsRole(role);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return MesDialog(
              title: Text(role == null ? '新增角色' : '编辑角色'),
              width: 420,
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        readOnly: hasBuiltinSemantics,
                        decoration: const InputDecoration(labelText: '角色名称'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '角色名称不能为空';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRoleType,
                        decoration: const InputDecoration(labelText: '角色类型'),
                        items: [
                          const DropdownMenuItem(
                            value: _roleTypeCustom,
                            child: Text('自定义'),
                          ),
                          if (selectedRoleType == _roleTypeBuiltin)
                            const DropdownMenuItem(
                              value: _roleTypeBuiltin,
                              child: Text('系统内置'),
                            ),
                        ],
                        onChanged: canEditRoleType
                            ? (value) {
                                if (value == null) {
                                  return;
                                }
                                setDialogState(() {
                                  selectedRoleType = value;
                                });
                              }
                            : null,
                      ),
                      if (role == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '新增角色仅支持自定义角色，系统内置角色由系统预置。',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (!editingExistingRole)
                        DropdownButtonFormField<bool>(
                          initialValue: selectedEnabled,
                          decoration: const InputDecoration(labelText: '状态'),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('启用')),
                            DropdownMenuItem(value: false, child: Text('停用')),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              selectedEnabled = value;
                            });
                          },
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            hasBuiltinSemantics
                                ? '系统内置角色仅禁止改名、删除；如需变更启停，请使用列表中的启停按钮。'
                                : '当前状态：${_statusLabel(selectedEnabled)}，如需变更请使用列表中的启停按钮。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    try {
                      if (role == null) {
                        await _userService.createRole(
                          code: _generateImplicitRoleCode(nameController.text),
                          name: nameController.text.trim(),
                          roleType: selectedRoleType,
                          isEnabled: selectedEnabled,
                        );
                      } else {
                        await _userService.updateRole(
                          roleId: role.id,
                          name: nameController.text.trim(),
                          isEnabled: selectedEnabled,
                        );
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_errorMessage(error))),
                      );
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      await _loadRoles();
    }
  }

  Future<void> _toggleRole(RoleItem role) async {
    if (!widget.canToggleRole) {
      return;
    }
    try {
      if (role.isEnabled) {
        await _userService.disableRole(roleId: role.id);
      } else {
        await _userService.enableRole(roleId: role.id);
      }
      if (!mounted) {
        return;
      }
      await _loadRoles();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _deleteRole(RoleItem role) async {
    if (!widget.canDeleteRole || _isBuiltinSemanticsRole(role)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return MesDialog(
          title: const Text('删除角色'),
          width: 420,
          content: Text('确认删除角色“${role.name}”吗？删除后不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    try {
      await _userService.deleteRole(roleId: role.id);
      if (!mounted) {
        return;
      }
      await _loadRoles();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MesCrudPageScaffold(
      header: RoleManagementPageHeader(
        loading: _loading,
        onRefresh: () => _loadRoles(page: _page),
      ),
      filters: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                labelText: '关键词',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _loadRoles(page: 1),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => _loadRoles(page: 1),
            child: const Text('查询'),
          ),
          const SizedBox(width: 10),
          if (widget.canCreateRole)
            FilledButton(
              onPressed: () => _showRoleDialog(),
              child: const Text('新增角色'),
            ),
        ],
      ),
      banner: _message.isEmpty
          ? null
          : Text(
              _message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
      content: KeyedSubtree(
        key: const ValueKey('role-management-table-section'),
        child: CrudListTableSection(
          key: const ValueKey('roleListSection'),
          cardKey: const ValueKey('roleListCard'),
          loading: _loading,
          isEmpty: _items.isEmpty,
          emptyText: '暂无角色数据',
          enableUnifiedHeaderStyle: true,
          child: DataTable(
            columnSpacing: 20,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 84,
            columns: [
              UnifiedListTableHeaderStyle.column(context, '角色名称'),
              UnifiedListTableHeaderStyle.column(context, '角色说明'),
              UnifiedListTableHeaderStyle.column(context, '角色类型'),
              UnifiedListTableHeaderStyle.column(context, '关联用户数'),
              UnifiedListTableHeaderStyle.column(context, '状态'),
              UnifiedListTableHeaderStyle.column(context, '操作'),
            ],
            rows: _items.map((role) {
              final canToggle = widget.canToggleRole;
              final canDelete =
                  widget.canDeleteRole && !_isBuiltinSemanticsRole(role);
              return DataRow(
                cells: [
                  DataCell(Text(role.name)),
                  DataCell(
                    Text(
                      role.description?.trim().isNotEmpty == true
                          ? role.description!
                          : '-',
                    ),
                  ),
                  DataCell(Text(_roleTypeLabel(role.roleType))),
                  DataCell(Text('${role.userCount}')),
                  DataCell(
                    Text(
                      _statusLabel(role.isEnabled),
                      style: TextStyle(
                        color: _statusColor(context, role.isEnabled),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    (widget.canEditRole || canToggle || canDelete)
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (widget.canEditRole)
                                OutlinedButton(
                                  onPressed: () => _showRoleDialog(role: role),
                                  child: const Text('编辑'),
                                ),
                              if (canToggle)
                                OutlinedButton(
                                  onPressed: () => _toggleRole(role),
                                  child: Text(role.isEnabled ? '停用' : '启用'),
                                ),
                              if (canDelete)
                                OutlinedButton(
                                  onPressed: () => _deleteRole(role),
                                  child: const Text('删除'),
                                ),
                            ],
                          )
                        : const Text('-'),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      pagination: MesPaginationBar(
        page: _page,
        totalPages: _totalPages,
        total: _total,
        loading: _loading,
        showTotal: false,
        onPrevious: () => _loadRoles(page: _page - 1),
        onNext: () => _loadRoles(page: _page + 1),
      ),
    );
  }
}
