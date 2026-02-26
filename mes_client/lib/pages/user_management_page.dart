import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  static const String _operatorRoleCode = 'operator';

  late final UserService _userService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  List<UserItem> _users = const [];
  List<RoleItem> _roles = const [];
  List<ProcessItem> _processes = const [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _userService = UserService(widget.session);
    _loadInitialData();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  bool _isForbidden(Object error) {
    return error is ApiException && error.statusCode == 403;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await Future.wait<dynamic>([
        _userService.listRoles(),
        _userService.listProcesses(),
        _userService.listUsers(
          page: 1,
          pageSize: 50,
          keyword: _keywordController.text.trim(),
        ),
      ]);
      final roles = result[0] as RoleListResult;
      final processes = result[1] as ProcessListResult;
      final users = result[2] as UserListResult;

      if (!mounted) {
        return;
      }
      setState(() {
        _roles = roles.items;
        _processes = processes.items;
        _users = users.items;
        _total = users.total;
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
        _message = _isForbidden(error)
            ? '当前账号没有用户管理权限，请使用有权限账号登录。'
            : '加载数据失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await _userService.listUsers(
        page: 1,
        pageSize: 50,
        keyword: _keywordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _users = result.items;
        _total = result.total;
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
        _message = _isForbidden(error)
            ? '当前账号没有用户查询权限。'
            : '加载用户失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showCreateUserDialog() async {
    final accountController = TextEditingController();
    final passwordController = TextEditingController(text: 'User@123456');
    final formKey = GlobalKey<FormState>();
    final selectedRoleCodes = <String>{};
    final selectedProcessCodes = <String>{};

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = selectedRoleCodes.contains(_operatorRoleCode);

            return AlertDialog(
              title: const Text('新建用户'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: accountController,
                          decoration: const InputDecoration(labelText: '账号（用户名与姓名统一）'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入账号';
                            }
                            if (value.trim().length < 3) {
                              return '账号至少 3 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(labelText: '密码'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入密码';
                            }
                            if (value.length < 6) {
                              return '密码至少 6 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('角色分配', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ..._roles.map((role) {
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(role.name),
                            subtitle: Text(role.code),
                            value: selectedRoleCodes.contains(role.code),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedRoleCodes.add(role.code);
                                } else {
                                  selectedRoleCodes.remove(role.code);
                                }
                                if (!selectedRoleCodes.contains(_operatorRoleCode)) {
                                  selectedProcessCodes.clear();
                                }
                              });
                            },
                          );
                        }),
                        if (selectedRoleCodes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '请至少选择一个角色',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          '工序分配（仅操作员角色必填）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ..._processes.map((process) {
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(process.name),
                            subtitle: Text(process.code),
                            value: selectedProcessCodes.contains(process.code),
                            onChanged: isOperatorSelected
                                ? (checked) {
                                    setDialogState(() {
                                      if (checked == true) {
                                        selectedProcessCodes.add(process.code);
                                      } else {
                                        selectedProcessCodes.remove(process.code);
                                      }
                                    });
                                  }
                                : null,
                          );
                        }),
                        if (isOperatorSelected && selectedProcessCodes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '操作员角色必须分配至少一个工序',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
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
                    if (selectedRoleCodes.isEmpty) {
                      return;
                    }
                    final isOperator = selectedRoleCodes.contains(_operatorRoleCode);
                    if (isOperator && selectedProcessCodes.isEmpty) {
                      return;
                    }

                    try {
                      await _userService.createUser(
                        account: accountController.text.trim(),
                        password: passwordController.text,
                        roleCodes: selectedRoleCodes.toList(),
                        processCodes: selectedProcessCodes.toList(),
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    } catch (error) {
                      if (_isUnauthorized(error)) {
                        widget.onLogout();
                        return;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('创建用户失败：${_errorMessage(error)}')),
                        );
                      }
                    }
                  },
                  child: const Text('创建'),
                ),
              ],
            );
          },
        );
      },
    );

    accountController.dispose();
    passwordController.dispose();

    if (created == true) {
      await _loadUsers();
    }
  }

  Future<void> _showEditUserDialog(UserItem user) async {
    final accountController = TextEditingController(text: user.username);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedRoleCodes = <String>{...user.roleCodes};
    final selectedProcessCodes = <String>{...user.processCodes};

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = selectedRoleCodes.contains(_operatorRoleCode);

            return AlertDialog(
              title: Text('编辑用户：${user.username}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: accountController,
                          decoration: const InputDecoration(labelText: '账号（用户名与姓名统一）'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入账号';
                            }
                            if (value.trim().length < 3) {
                              return '账号至少 3 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(labelText: '新密码（留空不修改）'),
                          validator: (value) {
                            if (value != null && value.isNotEmpty && value.length < 6) {
                              return '密码至少 6 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('角色分配', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ..._roles.map((role) {
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(role.name),
                            subtitle: Text(role.code),
                            value: selectedRoleCodes.contains(role.code),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedRoleCodes.add(role.code);
                                } else {
                                  selectedRoleCodes.remove(role.code);
                                }
                                if (!selectedRoleCodes.contains(_operatorRoleCode)) {
                                  selectedProcessCodes.clear();
                                }
                              });
                            },
                          );
                        }),
                        if (selectedRoleCodes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '请至少选择一个角色',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          '工序分配（仅操作员角色必填）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ..._processes.map((process) {
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(process.name),
                            subtitle: Text(process.code),
                            value: selectedProcessCodes.contains(process.code),
                            onChanged: isOperatorSelected
                                ? (checked) {
                                    setDialogState(() {
                                      if (checked == true) {
                                        selectedProcessCodes.add(process.code);
                                      } else {
                                        selectedProcessCodes.remove(process.code);
                                      }
                                    });
                                  }
                                : null,
                          );
                        }),
                        if (isOperatorSelected && selectedProcessCodes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '操作员角色必须分配至少一个工序',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
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
                    if (selectedRoleCodes.isEmpty) {
                      return;
                    }
                    final isOperator = selectedRoleCodes.contains(_operatorRoleCode);
                    if (isOperator && selectedProcessCodes.isEmpty) {
                      return;
                    }

                    try {
                      await _userService.updateUser(
                        userId: user.id,
                        account: accountController.text.trim(),
                        password: passwordController.text.trim().isEmpty
                            ? null
                            : passwordController.text.trim(),
                        roleCodes: selectedRoleCodes.toList(),
                        processCodes: selectedProcessCodes.toList(),
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    } catch (error) {
                      if (_isUnauthorized(error)) {
                        widget.onLogout();
                        return;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('更新用户失败：${_errorMessage(error)}')),
                        );
                      }
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

    accountController.dispose();
    passwordController.dispose();

    if (updated == true) {
      await _loadUsers();
    }
  }

  Future<void> _confirmDeleteUser(UserItem user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除用户'),
          content: Text('确认删除用户“${user.username}”吗？此操作不可恢复。'),
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
      await _userService.deleteUser(userId: user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户 ${user.username} 已删除')),
        );
      }
      await _loadUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '删除用户失败：${_errorMessage(error)}';
      });
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
                '用户管理',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadInitialData,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '按账号搜索',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadUsers(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _loadUsers,
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _showCreateUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('新建用户'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '总数：$_total',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('暂无用户'))
                    : Card(
                        child: ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return ListTile(
                              title: Text(user.username),
                              subtitle: Text(
                                '角色：${user.roleNames.isEmpty ? '-' : user.roleNames.join('、')}'
                                '\n工序：${user.processNames.isEmpty ? '-' : user.processNames.join('、')}',
                              ),
                              isThreeLine: true,
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => _showEditUserDialog(user),
                                    child: const Text('编辑'),
                                  ),
                                  TextButton(
                                    onPressed: () => _confirmDeleteUser(user),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
