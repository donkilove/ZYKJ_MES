import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/user_service.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/simple_pagination_bar.dart';

enum _UserAction { edit, disable, enable, resetPassword, delete }

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
    this.onNavigateToRoleManagement,
    this.userService,
    this.craftService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;
  final VoidCallback? onNavigateToRoleManagement;
  final UserService? userService;
  final CraftService? craftService;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  static const String _roleSystemAdmin = 'system_admin';
  static const String _roleOperator = 'operator';
  static const int _userPageSize = 50;

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
  List<CraftStageItem> _stages = const [];
  int _total = 0;
  int _userPage = 1;
  String? _myRoleCode;

  bool _isCurrentUserSystemAdmin() => _myRoleCode == _roleSystemAdmin;

  int get _userTotalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _userPageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService(widget.session);
    _craftService = widget.craftService ?? CraftService(widget.session);
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

  bool _isOperator(String? roleCode) => roleCode == _roleOperator;

  List<RoleItem> _assignableRoles({String? includeRoleCode}) {
    final items =
        _roles
            .where((role) => role.isEnabled || role.code == includeRoleCode)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return items;
  }

  Future<List<CraftStageItem>> _fetchLatestStages() async {
    final result = await _craftService.listStages(pageSize: 500, enabled: true);
    if (mounted) {
      setState(() => _stages = result.items);
    }
    return result.items;
  }

  Future<List<CraftStageItem>> _loadEnabledStagesForDialog() async {
    try {
      return await _fetchLatestStages();
    } catch (_) {
      return _stages;
    }
  }

  List<XTypeGroup> _exportTypeGroups(String format) {
    switch (format) {
      case 'excel':
        return const [
          XTypeGroup(label: 'Excel', extensions: ['xlsx']),
        ];
      case 'csv':
      default:
        return const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ];
    }
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

  Future<void> _loadInitialData({int? page}) async {
    final targetPage = page ?? _userPage;
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await Future.wait<dynamic>([
        _userService.listAllRoles(),
        _craftService.listStages(pageSize: 500, enabled: true),
        _userService.listUsers(
          page: targetPage,
          pageSize: _userPageSize,
          keyword: _keywordController.text.trim(),
          roleCode: _filterRoleCode,
          stageId: _filterStageId,
          isActive: _filterIsActive,
          isOnline: _filterIsOnline,
        ),
        _userService.getMyProfile(),
      ]);
      final roles = result[0] as RoleListResult;
      final stages = result[1] as CraftStageListResult;
      final users = result[2] as UserListResult;
      final myProfile = result[3] as ProfileResult;

      if (!mounted) {
        return;
      }
      final resolvedTotalPages = users.total <= 0
          ? 1
          : (((users.total - 1) ~/ _userPageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _roles = roles.items;
        _stages = stages.items;
        _users = users.items;
        _total = users.total;
        _userPage = resolvedPage;
        _myRoleCode = myProfile.roleCode;
      });
      if (resolvedPage != targetPage) {
        await _loadInitialData(page: resolvedPage);
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

  Future<void> _loadUsers({bool silent = false, int? page}) async {
    final targetPage = page ?? _userPage;
    if (!silent) {
      setState(() {
        _loading = true;
        _message = '';
      });
    }

    try {
      final result = await _userService.listUsers(
        page: targetPage,
        pageSize: _userPageSize,
        keyword: _keywordController.text.trim(),
        roleCode: _filterRoleCode,
        stageId: _filterStageId,
        isActive: _filterIsActive,
        isOnline: _filterIsOnline,
      );
      if (!mounted) {
        return;
      }
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _userPageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _users = result.items;
        _total = result.total;
        _userPage = resolvedPage;
      });
      if (resolvedPage != targetPage) {
        await _loadUsers(silent: silent, page: resolvedPage);
      }
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
    final currentStages = await _loadEnabledStagesForDialog();
    if (!mounted) {
      return;
    }
    final assignableRoles = _assignableRoles();
    if (assignableRoles.isEmpty) {
      setState(() {
        _message = '当前没有可分配的启用角色。';
      });
      return;
    }
    final accountController = TextEditingController();
    final passwordController = TextEditingController();
    final remarkController = TextEditingController();
    bool isActive = true;
    final formKey = GlobalKey<FormState>();
    String? selectedRoleCode;
    int? selectedStageId;

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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: remarkController,
                          decoration: const InputDecoration(
                            labelText: '备注（可选）',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('账号状态：'),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('启用'),
                              selected: isActive,
                              onSelected: (_) =>
                                  setDialogState(() => isActive = true),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('停用'),
                              selected: !isActive,
                              onSelected: (_) =>
                                  setDialogState(() => isActive = false),
                            ),
                          ],
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
                              }
                            });
                          },
                          child: Column(
                            children: assignableRoles.map((role) {
                              return RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(role.name),
                                subtitle: Text(
                                  '${role.code} · ${role.roleType == 'builtin' ? '系统内置' : '自定义'}',
                                ),
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
                            child: currentStages.isEmpty
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
                                      });
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: currentStages.map((stage) {
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

                    try {
                      await _userService.createUser(
                        account: accountController.text.trim(),
                        password: passwordController.text,
                        roleCode: selectedRoleCode!,
                        stageId: selectedStageId,
                        remark: remarkController.text.trim().isEmpty
                            ? null
                            : remarkController.text.trim(),
                        isActive: isActive,
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

    if (created == true) {
      await _loadUsers();
    }
  }

  Future<void> _showEditUserDialog(UserItem user) async {
    if (!widget.canWrite) {
      _showNoPermission();
      return;
    }
    final currentStages = await _loadEnabledStagesForDialog();
    if (!mounted) {
      return;
    }
    final assignableRoles = _assignableRoles(includeRoleCode: user.roleCode);
    if (assignableRoles.isEmpty) {
      setState(() {
        _message = '当前没有可分配的启用角色。';
      });
      return;
    }
    final accountController = TextEditingController(text: user.username);
    final passwordController = TextEditingController();
    final remarkController = TextEditingController(text: user.remark ?? '');
    final formKey = GlobalKey<FormState>();
    final canEditAccount = _isCurrentUserSystemAdmin();
    String? selectedRoleCode = user.roleCode;
    int? selectedStageId = _isOperator(selectedRoleCode) ? user.stageId : null;

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
                        TextFormField(
                          controller: accountController,
                          readOnly: !canEditAccount,
                          decoration: InputDecoration(
                            labelText: '账号（用户名与姓名统一）',
                            helperText: canEditAccount ? null : '仅系统管理员可修改账号',
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: remarkController,
                          decoration: const InputDecoration(
                            labelText: '备注（可选）',
                          ),
                          maxLines: 2,
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
                              }
                            });
                          },
                          child: Column(
                            children: assignableRoles.map((role) {
                              return RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(role.name),
                                subtitle: Text(
                                  '${role.code} · ${role.roleType == 'builtin' ? '系统内置' : '自定义'}',
                                ),
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
                            child: currentStages.isEmpty
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
                                      });
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: currentStages.map((stage) {
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

                    try {
                      await _userService.updateUser(
                        userId: user.id,
                        account: canEditAccount
                            ? accountController.text.trim()
                            : null,
                        password: passwordController.text.trim().isEmpty
                            ? null
                            : passwordController.text.trim(),
                        roleCode: selectedRoleCode!,
                        stageId: selectedStageId,
                        remark: remarkController.text.trim().isEmpty
                            ? null
                            : remarkController.text.trim(),
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
          content: Text(
            '确认逻辑删除用户“${user.username}”吗？删除后账号将被停用，并从常规列表中隐藏，且不可再登录。',
          ),
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
        ).showSnackBar(SnackBar(content: Text('用户 ${user.username} 已逻辑删除并停用')));
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
        isOnline: _filterIsOnline,
        isActive: _filterIsActive,
        format: format,
      );
      if (!mounted) return;
      final bytes = base64Decode(result.contentBase64);
      final location = await getSaveLocation(
        suggestedName: result.filename,
        acceptedTypeGroups: _exportTypeGroups(format),
      );
      if (location == null || !mounted) return;
      await XFile.fromData(
        bytes,
        mimeType: result.contentType,
        name: result.filename,
      ).saveTo(location.path);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已导出到 ${location.path}')));
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
                  onSubmitted: (_) => _loadUsers(page: 1),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : () => _loadUsers(page: 1),
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
                    _loadUsers(page: 1);
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<int?>(
                  initialValue: _filterStageId,
                  onTap: () {
                    unawaited(_fetchLatestStages());
                  },
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
                    _loadUsers(page: 1);
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
                    _loadUsers(page: 1);
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
                    _loadUsers(page: 1);
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
                        child: SingleChildScrollView(
                          controller: _userListScrollController,
                          child: DataTable(
                            columnSpacing: 16,
                            headingRowColor: WidgetStateProperty.all(
                              theme.colorScheme.surfaceContainerHighest,
                            ),
                            columns: const [
                              DataColumn(label: Text('账号')),
                              DataColumn(label: Text('角色')),
                              DataColumn(label: Text('工段')),
                              DataColumn(label: Text('在线')),
                              DataColumn(label: Text('状态')),
                              DataColumn(label: Text('创建时间')),
                              DataColumn(label: Text('操作')),
                            ],
                            rows: _users.map((user) {
                              final statusLabel = user.isOnline ? '在线' : '离线';
                              final statusColor = user.isOnline
                                  ? Colors.green
                                  : theme.colorScheme.outline;
                              final activeLabel = user.isActive ? '启用' : '停用';
                              final activeColor = user.isActive
                                  ? Colors.blue
                                  : Colors.red;
                              final createdAtStr = user.createdAt != null
                                  ? '${user.createdAt!.year}-${user.createdAt!.month.toString().padLeft(2, '0')}-${user.createdAt!.day.toString().padLeft(2, '0')}'
                                  : '-';
                              return DataRow(
                                cells: [
                                  DataCell(Text(user.username)),
                                  DataCell(
                                    Text(
                                      user.roleName?.trim().isNotEmpty == true
                                          ? user.roleName!
                                          : '-',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      user.stageName?.trim().isNotEmpty == true
                                          ? user.stageName!
                                          : '/',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      activeLabel,
                                      style: TextStyle(
                                        color: activeColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(createdAtStr)),
                                  DataCell(
                                    PopupMenuButton<_UserAction>(
                                      onSelected: (action) =>
                                          _handleUserAction(action, user),
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
                                      child: const Text('操作'),
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
          const SizedBox(height: 12),
          SimplePaginationBar(
            page: _userPage,
            totalPages: _userTotalPages,
            total: _total,
            loading: _loading,
            onPrevious: () => _loadUsers(page: _userPage - 1),
            onNext: () => _loadUsers(page: _userPage + 1),
          ),
        ],
      ),
    );
  }
}
