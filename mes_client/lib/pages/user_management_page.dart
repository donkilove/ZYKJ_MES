import 'dart:async';

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
  static const String _roleSystemAdmin = 'system_admin';
  static const String _roleProductionAdmin = 'production_admin';
  static const String _roleQualityAdmin = 'quality_admin';
  static const String _roleOperator = 'operator';

  static const List<String> _rolePriority = [
    _roleSystemAdmin,
    _roleProductionAdmin,
    _roleQualityAdmin,
    _roleOperator,
  ];

  late final UserService _userService;
  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _userListScrollController = ScrollController();
  Timer? _onlineStatusTimer;
  static const Duration _onlineRefreshInterval = Duration(seconds: 5);
  bool _onlineRefreshInFlight = false;

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
    _startOnlineStatusRefresh();
    _loadInitialData();
  }

  @override
  void dispose() {
    _stopOnlineStatusRefresh();
    _keywordController.dispose();
    _userListScrollController.dispose();
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

  String? _pickPreferredRoleCode(List<String> roleCodes) {
    for (final code in _rolePriority) {
      if (roleCodes.contains(code)) {
        return code;
      }
    }
    if (roleCodes.isNotEmpty) {
      return roleCodes.first;
    }
    return null;
  }

  String? _pickPreferredProcessCode(List<String> processCodes) {
    if (processCodes.isEmpty) {
      return null;
    }
    final sorted = [...processCodes]..sort();
    return sorted.first;
  }

  bool _isOperator(String? roleCode) => roleCode == _roleOperator;

  void _startOnlineStatusRefresh() {
    _onlineStatusTimer?.cancel();
    _onlineStatusTimer = Timer.periodic(_onlineRefreshInterval, (_) {
      if (!mounted || _onlineRefreshInFlight) {
        return;
      }
      _onlineRefreshInFlight = true;
      _loadUsers(silent: true).whenComplete(() {
        _onlineRefreshInFlight = false;
      });
    });
  }

  void _stopOnlineStatusRefresh() {
    _onlineStatusTimer?.cancel();
    _onlineStatusTimer = null;
    _onlineRefreshInFlight = false;
  }

  String _formatLastSeen(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
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

  Future<void> _loadUsers({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _message = '';
      });
    }

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
      if (!silent) {
        setState(() {
          _message = _isForbidden(error)
              ? '当前账号没有用户查询权限。'
              : '加载用户失败：${_errorMessage(error)}';
        });
      }
    } finally {
      if (mounted && !silent) {
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
    String? selectedRoleCode;
    String? selectedProcessCode;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = _isOperator(selectedRoleCode);

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
                          decoration: const InputDecoration(
                            labelText: '账号（用户名与姓名统一）',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入账号';
                            }
                            if (value.trim().length < 2) {
                              return '账号至少 2 个字符';
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
                        const Text(
                          '角色分配（单选）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        RadioGroup<String>(
                          groupValue: selectedRoleCode,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedRoleCode = value;
                              if (!_isOperator(selectedRoleCode)) {
                                selectedProcessCode = null;
                              }
                            });
                          },
                          child: Column(
                            children: _roles.map((role) {
                              return RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(role.name),
                                subtitle: Text(role.code),
                                value: role.code,
                              );
                            }).toList(),
                          ),
                        ),
                        if (selectedRoleCode == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '请选择一个角色',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          '工序分配（单选，仅操作员角色可选）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: isOperatorSelected ? 1 : 0.5,
                          child: IgnorePointer(
                            ignoring: !isOperatorSelected,
                            child: RadioGroup<String>(
                              groupValue: selectedProcessCode,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedProcessCode = value;
                                });
                              },
                              child: Column(
                                children: _processes.map((process) {
                                  return RadioListTile<String>(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(process.name),
                                    subtitle: Text(process.code),
                                    value: process.code,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        if (isOperatorSelected && selectedProcessCode == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '操作员角色必须分配一个工序',
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
                    if (selectedRoleCode == null) {
                      return;
                    }
                    if (_isOperator(selectedRoleCode) &&
                        selectedProcessCode == null) {
                      return;
                    }

                    try {
                      await _userService.createUser(
                        account: accountController.text.trim(),
                        password: passwordController.text,
                        roleCodes: [selectedRoleCode!],
                        processCodes: selectedProcessCode == null
                            ? const []
                            : [selectedProcessCode!],
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
                          SnackBar(
                            content: Text('创建用户失败：${_errorMessage(error)}'),
                          ),
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
    final hasLegacyMultiRoles = user.roleCodes.length > 1;
    final hasLegacyMultiProcesses = user.processCodes.length > 1;
    String? selectedRoleCode = _pickPreferredRoleCode(user.roleCodes);
    String? selectedProcessCode = _isOperator(selectedRoleCode)
        ? _pickPreferredProcessCode(user.processCodes)
        : null;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = _isOperator(selectedRoleCode);

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
                        if (hasLegacyMultiRoles || hasLegacyMultiProcesses)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              '检测到该用户存在历史多选分配数据，保存后将收敛为单选规则。',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        TextFormField(
                          controller: accountController,
                          decoration: const InputDecoration(
                            labelText: '账号（用户名与姓名统一）',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入账号';
                            }
                            if (value.trim().length < 2) {
                              return '账号至少 2 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: '新密码（留空不修改）',
                          ),
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                value.length < 6) {
                              return '密码至少 6 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '角色分配（单选）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        RadioGroup<String>(
                          groupValue: selectedRoleCode,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedRoleCode = value;
                              if (!_isOperator(selectedRoleCode)) {
                                selectedProcessCode = null;
                              }
                            });
                          },
                          child: Column(
                            children: _roles.map((role) {
                              return RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(role.name),
                                subtitle: Text(role.code),
                                value: role.code,
                              );
                            }).toList(),
                          ),
                        ),
                        if (selectedRoleCode == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '请选择一个角色',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          '工序分配（单选，仅操作员角色可选）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: isOperatorSelected ? 1 : 0.5,
                          child: IgnorePointer(
                            ignoring: !isOperatorSelected,
                            child: RadioGroup<String>(
                              groupValue: selectedProcessCode,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedProcessCode = value;
                                });
                              },
                              child: Column(
                                children: _processes.map((process) {
                                  return RadioListTile<String>(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(process.name),
                                    subtitle: Text(process.code),
                                    value: process.code,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        if (isOperatorSelected && selectedProcessCode == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '操作员角色必须分配一个工序',
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
                    if (selectedRoleCode == null) {
                      return;
                    }
                    if (_isOperator(selectedRoleCode) &&
                        selectedProcessCode == null) {
                      return;
                    }

                    try {
                      await _userService.updateUser(
                        userId: user.id,
                        account: accountController.text.trim(),
                        password: passwordController.text.trim().isEmpty
                            ? null
                            : passwordController.text.trim(),
                        roleCodes: [selectedRoleCode!],
                        processCodes: selectedProcessCode == null
                            ? const []
                            : [selectedProcessCode!],
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
                          SnackBar(
                            content: Text('更新用户失败：${_errorMessage(error)}'),
                          ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('用户 ${user.username} 已删除')));
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
          Text('总数：$_total', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? const Center(child: Text('暂无用户'))
                : Card(
                    child: SizedBox.expand(
                      child: Scrollbar(
                        controller: _userListScrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _userListScrollController,
                          itemCount: _users.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final statusLabel = user.isOnline
                                ? 'Online'
                                : 'Offline ${_formatLastSeen(user.lastSeenAt)}';
                            final statusColor = user.isOnline
                                ? Colors.green
                                : theme.colorScheme.outline;
                            return ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.username,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: statusColor.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                  ),
          ),
        ],
      ),
    );
  }
}
