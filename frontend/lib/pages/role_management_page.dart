import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/simple_pagination_bar.dart';

class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canManage,
    this.userService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canManage;
  final UserService? userService;

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  static const int _pageSize = 50;
  static const String _roleTypeBuiltin = 'builtin';
  static const String _roleTypeCustom = 'custom';

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
    if (!widget.canManage) {
      return;
    }
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController(text: role?.code ?? '');
    final nameController = TextEditingController(text: role?.name ?? '');
    final descController = TextEditingController(text: role?.description ?? '');
    var selectedRoleType = role?.roleType == _roleTypeBuiltin
        ? _roleTypeBuiltin
        : _roleTypeCustom;
    var selectedEnabled = role?.isEnabled ?? true;
    final canEditRoleType = role == null;
    final canEditStatus = !(role?.isBuiltin ?? false);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(role == null ? '新增角色' : '编辑角色'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: codeController,
                        readOnly: role?.isBuiltin ?? false,
                        decoration: const InputDecoration(labelText: '角色编码'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '角色编码不能为空';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        readOnly: role?.isBuiltin ?? false,
                        decoration: const InputDecoration(labelText: '角色名称'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '角色名称不能为空';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: '角色说明'),
                        minLines: 1,
                        maxLines: 3,
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
                      DropdownButtonFormField<bool>(
                        initialValue: selectedEnabled,
                        decoration: const InputDecoration(labelText: '状态'),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('启用')),
                          DropdownMenuItem(value: false, child: Text('停用')),
                        ],
                        onChanged: canEditStatus
                            ? (value) {
                                if (value == null) {
                                  return;
                                }
                                setDialogState(() {
                                  selectedEnabled = value;
                                });
                              }
                            : null,
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
                          code: codeController.text.trim(),
                          name: nameController.text.trim(),
                          description: descController.text.trim(),
                          roleType: selectedRoleType,
                          isEnabled: selectedEnabled,
                        );
                      } else {
                        await _userService.updateRole(
                          roleId: role.id,
                          code: codeController.text.trim(),
                          name: nameController.text.trim(),
                          description: descController.text.trim(),
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

    codeController.dispose();
    nameController.dispose();
    descController.dispose();

    if (saved == true && mounted) {
      await _loadRoles();
    }
  }

  Future<void> _toggleRole(RoleItem role) async {
    if (!widget.canManage || role.isBuiltin) {
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
    if (!widget.canManage || role.isBuiltin) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除角色'),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
              FilledButton(
                onPressed: widget.canManage ? () => _showRoleDialog() : null,
                child: const Text('新增角色'),
              ),
            ],
          ),
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_message, style: const TextStyle(color: Colors.red)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('总数：$_total'),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? const Center(child: Text('暂无角色数据'))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 980),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 20,
                              headingRowHeight: 44,
                              dataRowMinHeight: 60,
                              dataRowMaxHeight: 84,
                              columns: const [
                                DataColumn(label: Text('角色名称')),
                                DataColumn(label: Text('角色说明')),
                                DataColumn(label: Text('角色类型')),
                                DataColumn(label: Text('关联用户数')),
                                DataColumn(label: Text('状态')),
                                DataColumn(label: Text('操作')),
                              ],
                              rows: _items.map((role) {
                                final canToggle =
                                    widget.canManage && !role.isBuiltin;
                                final canDelete =
                                    widget.canManage && !role.isBuiltin;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(role.name),
                                          Text(
                                            role.code,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        role.description?.trim().isNotEmpty ==
                                                true
                                            ? role.description!
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(_roleTypeLabel(role.roleType)),
                                    ),
                                    DataCell(Text('${role.userCount}')),
                                    DataCell(
                                      Text(
                                        _statusLabel(role.isEnabled),
                                        style: TextStyle(
                                          color: _statusColor(
                                            context,
                                            role.isEnabled,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton(
                                            onPressed: widget.canManage
                                                ? () => _showRoleDialog(
                                                    role: role,
                                                  )
                                                : null,
                                            child: const Text('编辑'),
                                          ),
                                          OutlinedButton(
                                            onPressed: canToggle
                                                ? () => _toggleRole(role)
                                                : null,
                                            child: Text(
                                              role.isEnabled ? '停用' : '启用',
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: canDelete
                                                ? () => _deleteRole(role)
                                                : null,
                                            child: const Text('删除'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        SimplePaginationBar(
          page: _page,
          totalPages: _totalPages,
          total: _total,
          loading: _loading,
          onPrevious: () => _loadRoles(page: _page - 1),
          onNext: () => _loadRoles(page: _page + 1),
        ),
      ],
    );
  }
}
