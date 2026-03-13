import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/user_service.dart';
import '../widgets/locked_form_dialog.dart';

enum _UserAction { edit, disable, enable, resetPassword, delete }

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
    this.onNavigateToRoleManagement,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;
  final VoidCallback? onNavigateToRoleManagement;

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
  late final CraftService _craftService;
  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _userListScrollController = ScrollController();
  Timer? _onlineStatusTimer;
  static const Duration _onlineRefreshInterval = Duration(seconds: 5);
  bool _onlineRefreshInFlight = false;

  // 筛选条件
  String? _filterRoleCode;
  int? _filterStageId;
  bool? _filterIsOnline; // null=全部, true=在线, false=离线
  bool? _filterIsActive; // null=全部, true=启用, false=停用

  bool _loading = false;
  String _message = '';
  List<UserItem> _users = const [];
  List<RoleItem> _roles = const [];
  List<ProcessItem> _processes = const [];
  List<CraftStageItem> _stages = const [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _userService = UserService(widget.session);
    _craftService = CraftService(widget.session);
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

  void _showNoPermission() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前账号没有操作权限')));
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

  bool _isOperator(String? roleCode) => roleCode == _roleOperator;

  List<String> _getProcessCodesByStage(int stageId) {
    return _processes
        .where((p) => p.stageId == stageId)
        .map((p) => p.code)
        .toList();
  }

  int? _getStageIdFromProcessCodes(Set<String> processCodes) {
    if (processCodes.isEmpty) {
      return null;
    }
    final firstProcess = _processes.firstWhere(
      (p) => processCodes.contains(p.code),
      orElse: () => _processes.first,
    );
    return firstProcess.stageId;
  }

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

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await Future.wait<dynamic>([
        _userService.listRoles(),
        _userService.listProcesses(),
        _craftService.listStages(pageSize: 500, enabled: true),
        _userService.listUsers(
          page: 1,
          pageSize: 50,
          keyword: _keywordController.text.trim(),
          roleCode: _filterRoleCode,
          stageId: _filterStageId,
          isActive: _filterIsActive,
        ),
      ]);
      final roles = result[0] as RoleListResult;
      final processes = result[1] as ProcessListResult;
      final stages = result[2] as CraftStageListResult;
      final users = result[3] as UserListResult;

      if (!mounted) {
        return;
      }
      final userItems = users.items;
      final filtered = _filterIsOnline == null
          ? userItems
          : userItems.where((u) => u.isOnline == _filterIsOnline).toList();
      setState(() {
        _roles = roles.items;
        _processes = processes.items;
        _stages = stages.items;
        _users = filtered;
        _total = _filterIsOnline == null ? users.total : filtered.length;
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
        roleCode: _filterRoleCode,
        stageId: _filterStageId,
        isActive: _filterIsActive,
      );
      if (!mounted) {
        return;
      }
      // 前端过滤在线状态（后端不支持在线状态筛选参数）
      final filtered = _filterIsOnline == null
          ? result.items
          : result.items.where((u) => u.isOnline == _filterIsOnline).toList();
      setState(() {
        _users = filtered;
        _total = _filterIsOnline == null ? result.total : filtered.length;
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
    if (!widget.canWrite) {
      _showNoPermission();
      return;
    }
    final accountController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedRoleCode;
    int? selectedStageId;
    Set<String> selectedProcessCodes = <String>{};

    final created = await showLockedFormDialog<bool>(
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
                            if (value.trim().length > 10) {
                              return '账号最多 10 个字符';
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
                                selectedStageId = null;
                                selectedProcessCodes = <String>{};
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
                          '工段分配（单选，仅操作员角色可选）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: isOperatorSelected ? 1 : 0.5,
                          child: IgnorePointer(
                            ignoring: !isOperatorSelected,
                            child: _stages.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('暂无可分配工段'),
                                  )
                                : RadioGroup<int>(
                                    groupValue: selectedStageId,
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setDialogState(() {
                                        selectedStageId = value;
                                        selectedProcessCodes =
                                            _getProcessCodesByStage(
                                              value,
                                            ).toSet();
                                      });
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _stages.map((stage) {
                                        return RadioListTile<int>(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(stage.name),
                                          subtitle: Text(stage.code),
                                          value: stage.id,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ),
                        if (isOperatorSelected && selectedStageId == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '操作员角色必须选择一个工段',
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
                        selectedStageId == null) {
                      return;
                    }

                    final orderedProcessCodes = selectedProcessCodes.toList()
                      ..sort();
                    try {
                      await _userService.createUser(
                        account: accountController.text.trim(),
                        password: passwordController.text,
                        roleCodes: [selectedRoleCode!],
                        processCodes: orderedProcessCodes,
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
    if (!widget.canWrite) {
      _showNoPermission();
      return;
    }
    final accountController = TextEditingController(text: user.username);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final hasLegacyMultiRoles = user.roleCodes.length > 1;
    String? selectedRoleCode = _pickPreferredRoleCode(user.roleCodes);
    int? selectedStageId = _isOperator(selectedRoleCode)
        ? _getStageIdFromProcessCodes(user.processCodes.toSet())
        : null;
    Set<String> selectedProcessCodes = _isOperator(selectedRoleCode)
        ? user.processCodes.toSet()
        : <String>{};

    final updated = await showLockedFormDialog<bool>(
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
                        if (hasLegacyMultiRoles)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              '检测到该用户存在历史多角色分配数据，保存后将收敛为单角色规则。',
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
                            if (value.trim().length > 10) {
                              return '账号最多 10 个字符';
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
                                selectedStageId = null;
                                selectedProcessCodes = <String>{};
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
                          '工段分配（单选，仅操作员角色可选）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: isOperatorSelected ? 1 : 0.5,
                          child: IgnorePointer(
                            ignoring: !isOperatorSelected,
                            child: _stages.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('暂无可分配工段'),
                                  )
                                : RadioGroup<int>(
                                    groupValue: selectedStageId,
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setDialogState(() {
                                        selectedStageId = value;
                                        selectedProcessCodes =
                                            _getProcessCodesByStage(
                                              value,
                                            ).toSet();
                                      });
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _stages.map((stage) {
                                        return RadioListTile<int>(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(stage.name),
                                          subtitle: Text(stage.code),
                                          value: stage.id,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ),
                        if (isOperatorSelected && selectedStageId == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '操作员角色必须选择一个工段',
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
                        selectedStageId == null) {
                      return;
                    }

                    final orderedProcessCodes = selectedProcessCodes.toList()
                      ..sort();
                    try {
                      await _userService.updateUser(
                        userId: user.id,
                        account: accountController.text.trim(),
                        password: passwordController.text.trim().isEmpty
                            ? null
                            : passwordController.text.trim(),
                        roleCodes: [selectedRoleCode!],
                        processCodes: orderedProcessCodes,
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

  Future<void> _toggleUserActive(UserItem user, {required bool active}) async {
    if (!widget.canWrite) {
      _showNoPermission();
      return;
    }
    final actionLabel = active ? '启用' : '停用';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$actionLabel用户'),
          content: Text('确认$actionLabel用户"${user.username}"吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      if (active) {
        await _userService.enableUser(userId: user.id);
      } else {
        await _userService.disableUser(userId: user.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户 ${user.username} 已$actionLabel')),
        );
      }
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$actionLabel用户失败：${_errorMessage(error)}')),
        );
      }
    }
  }

  Future<void> _showResetPasswordDialog(UserItem user) async {
    if (!widget.canWrite) {
      _showNoPermission();
      return;
    }
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('重置密码：${user.username}'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: '新密码'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入新密码';
                  if (value.length < 6) return '密码至少 6 个字符';
                  return null;
                },
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
                if (!formKey.currentState!.validate()) return;
                try {
                  await _userService.resetUserPassword(
                    userId: user.id,
                    password: passwordController.text,
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
                      SnackBar(content: Text('重置密码失败：${_errorMessage(error)}')),
                    );
                  }
                }
              },
              child: const Text('确认重置'),
            ),
          ],
        );
      },
    );

    passwordController.dispose();
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('用户 ${user.username} 密码已重置')));
    }
  }

  Future<void> _exportUsers({String format = 'csv'}) async {
    setState(() => _loading = true);
    try {
      final result = await _userService.exportUsers(
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        roleCode: _filterRoleCode,
        stageId: _filterStageId,
        isActive: _filterIsActive,
        format: format,
      );
      if (!mounted) return;
      final bytes = base64Decode(result.contentBase64);
      final downloadsDir = Directory(
        '${Platform.environment['USERPROFILE'] ?? '.'}\\Downloads',
      );
      final file = File('${downloadsDir.path}\\${result.filename}');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已导出到 ${file.path}')));
      }
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：${_errorMessage(error)}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleUserAction(_UserAction action, UserItem user) async {
    if (!widget.canWrite) {
      _showNoPermission();
      return;
    }
    switch (action) {
      case _UserAction.edit:
        await _showEditUserDialog(user);
        return;
      case _UserAction.disable:
        await _toggleUserActive(user, active: false);
        return;
      case _UserAction.enable:
        await _toggleUserActive(user, active: true);
        return;
      case _UserAction.resetPassword:
        await _showResetPasswordDialog(user);
        return;
      case _UserAction.delete:
        await _confirmDeleteUser(user);
        return;
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
                onPressed: (_loading || !widget.canWrite)
                    ? null
                    : _showCreateUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('新建用户'),
              ),
              if (widget.onNavigateToRoleManagement != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: widget.onNavigateToRoleManagement,
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('角色管理'),
                ),
              ],
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                onSelected: (value) => _exportUsers(format: value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'csv', child: Text('导出 CSV')),
                  PopupMenuItem(value: 'excel', child: Text('导出 Excel')),
                ],
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () {},
                  icon: const Icon(Icons.download),
                  label: const Text('导出'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 高级筛选行
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String?>(
                  initialValue: _filterRoleCode,
                  decoration: const InputDecoration(
                    labelText: '角色',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部')),
                    ..._roles.map(
                      (role) => DropdownMenuItem(
                        value: role.code,
                        child: Text(role.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _filterRoleCode = value);
                    _loadUsers();
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<int?>(
                  initialValue: _filterStageId,
                  decoration: const InputDecoration(
                    labelText: '工段',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部')),
                    ..._stages.map(
                      (stage) => DropdownMenuItem(
                        value: stage.id,
                        child: Text(
                          stage.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _filterStageId = value);
                    _loadUsers();
                  },
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _filterIsOnline,
                  decoration: const InputDecoration(
                    labelText: '在线状态',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('全部')),
                    DropdownMenuItem(value: true, child: Text('在线')),
                    DropdownMenuItem(value: false, child: Text('离线')),
                  ],
                  onChanged: (value) {
                    setState(() => _filterIsOnline = value);
                    _loadUsers();
                  },
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _filterIsActive,
                  decoration: const InputDecoration(
                    labelText: '账号状态',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('全部')),
                    DropdownMenuItem(value: true, child: Text('启用')),
                    DropdownMenuItem(value: false, child: Text('停用')),
                  ],
                  onChanged: (value) {
                    setState(() => _filterIsActive = value);
                    _loadUsers();
                  },
                ),
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
                            final statusLabel = user.isOnline ? '在线' : '离线';
                            final statusColor = user.isOnline
                                ? Colors.green
                                : theme.colorScheme.outline;
                            final activeLabel = user.isActive ? '启用' : '停用';
                            final activeColor = user.isActive
                                ? Colors.blue
                                : Colors.red;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.username,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '角色：${user.roleNames.isEmpty ? '-' : user.roleNames.join('、')}'
                                          '\n工段：${user.stageNames.isEmpty ? '-' : user.stageNames.join('、')}',
                                          style: TextStyle(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.center,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
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
                                  Container(
                                    alignment: Alignment.center,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: activeColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: activeColor.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      activeLabel,
                                      style: TextStyle(
                                        color: activeColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.center,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: PopupMenuButton<_UserAction>(
                                      color: theme.colorScheme.primaryContainer,
                                      onSelected: (action) {
                                        _handleUserAction(action, user);
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: _UserAction.edit,
                                          child: Text('编辑'),
                                        ),
                                        if (user.isActive)
                                          const PopupMenuItem(
                                            value: _UserAction.disable,
                                            child: Text('停用'),
                                          )
                                        else
                                          const PopupMenuItem(
                                            value: _UserAction.enable,
                                            child: Text('启用'),
                                          ),
                                        const PopupMenuItem(
                                          value: _UserAction.resetPassword,
                                          child: Text('重置密码'),
                                        ),
                                        const PopupMenuItem(
                                          value: _UserAction.delete,
                                          child: Text('删除'),
                                        ),
                                      ],
                                      child: Text(
                                        '操作',
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
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
