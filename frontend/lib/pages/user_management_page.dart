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
import '../widgets/crud_page_header.dart';
import '../widgets/crud_list_table_section.dart';
import '../widgets/simple_pagination_bar.dart';
import '../widgets/unified_list_table_header_style.dart';

enum _UserAction { edit, disable, enable, resetPassword, delete }

typedef UserExportFileSaver =
    Future<String?> Function({
      required String filename,
      required String contentBase64,
      required String contentType,
      required String format,
    });

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canCreateUser,
    required this.canEditUser,
    required this.canToggleUser,
    required this.canResetPassword,
    required this.canDeleteUser,
    required this.canExport,
    this.onNavigateToRoleManagement,
    this.userService,
    this.craftService,
    this.saveExportFile,
    this.isCurrentTabVisible = true,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canCreateUser;
  final bool canEditUser;
  final bool canToggleUser;
  final bool canResetPassword;
  final bool canDeleteUser;
  final bool canExport;
  final VoidCallback? onNavigateToRoleManagement;
  final UserService? userService;
  final CraftService? craftService;
  final UserExportFileSaver? saveExportFile;
  final bool isCurrentTabVisible;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  static const String _roleSystemAdmin = 'system_admin';
  static const String _roleOperator = 'operator';
  static const int _userPageSize = 10;
  static const Duration _headerRefreshCooldown = Duration(seconds: 2);
  static const String _headerRefreshThrottledMessage = '刚刚已刷新，无需重复操作';

  late final UserService _userService;
  late final CraftService _craftService;
  final TextEditingController _keywordController = TextEditingController();
  Timer? _onlineStatusTimer;
  static const Duration _onlineRefreshInterval = Duration(seconds: 5);
  static const Duration _maxOnlineRefreshInterval = Duration(seconds: 60);
  Duration _currentOnlineRefreshDelay = _onlineRefreshInterval;
  bool _onlineRefreshInFlight = false;
  bool _onlineRefreshPaused = false;
  bool _baseDataLoaded = false;
  List<UserItem> get _pollableUsers =>
      _users.where((user) => user.isActive && !user.isDeleted).toList(growable: false);

  bool get _hasPollableUsers => _pollableUsers.isNotEmpty;

  bool get _canScheduleOnlineRefresh =>
      widget.isCurrentTabVisible &&
      !_loading &&
      !_onlineRefreshPaused &&
      !_onlineRefreshInFlight &&
      _hasPollableUsers;

  // 筛选条件
  String? _filterRoleCode;
  bool? _filterIsActive; // null=全部, true=启用, false=停用

  bool _loading = false;
  bool _queryInFlight = false;
  String _message = '';
  List<UserItem> _users = const [];
  List<RoleItem> _roles = const [];
  List<CraftStageItem> _stages = const [];
  int _total = 0;
  int _userPage = 1;
  DateTime? _lastHeaderRefreshAt;
  DateTime? _lastHeaderRefreshFeedbackAt;
  String? _myRoleCode;

  bool _isCurrentUserSystemAdmin() => _myRoleCode == _roleSystemAdmin;

  int get _userTotalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _userPageSize) + 1;
  }

  bool get _hasSearchCriteria {
    final keyword = _keywordController.text.trim();
    return keyword.isNotEmpty ||
        _filterRoleCode != null ||
        _filterIsActive != null;
  }

  String get _emptyListMessage => _hasSearchCriteria
      ? '当前账号/角色/状态筛选未命中任何用户，请尝试修改关键词或清除筛选。'
      : '暂无用户';

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService(widget.session);
    _craftService = widget.craftService ?? CraftService(widget.session);
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant UserManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentTabVisible && !oldWidget.isCurrentTabVisible) {
      _currentOnlineRefreshDelay = _onlineRefreshInterval;
      _scheduleOnlineStatusRefresh();
    } else if (!widget.isCurrentTabVisible && oldWidget.isCurrentTabVisible) {
      _stopOnlineStatusRefresh();
    }
  }

  @override
  void dispose() {
    _stopOnlineStatusRefresh();
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

  void _showNoPermission() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前账号没有操作权限')));
  }

  bool _isOperator(String? roleCode) => roleCode == _roleOperator;

  RoleItem? _findRoleByCode(String? roleCode) {
    if (roleCode == null) {
      return null;
    }
    for (final role in _roles) {
      if (role.code == roleCode) {
        return role;
      }
    }
    return null;
  }

  bool _canAssignStage(String? roleCode) {
    final role = _findRoleByCode(roleCode);
    if (role == null) {
      return _isOperator(roleCode);
    }
    return _isOperator(roleCode) ||
        role.roleType == 'custom' ||
        !role.isBuiltin;
  }

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

  Future<String?> _saveExportFile({
    required String filename,
    required String contentBase64,
    required String contentType,
    required String format,
  }) async {
    final customSaver = widget.saveExportFile;
    if (customSaver != null) {
      return customSaver(
        filename: filename,
        contentBase64: contentBase64,
        contentType: contentType,
        format: format,
      );
    }
    final bytes = base64Decode(contentBase64);
    final location = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: _exportTypeGroups(format),
    );
    if (location == null) {
      return null;
    }
    await XFile.fromData(
      bytes,
      mimeType: contentType,
      name: filename,
    ).saveTo(location.path);
    return location.path;
  }

  void _scheduleOnlineStatusRefresh() {
    if (!_canScheduleOnlineRefresh) {
      return;
    }
    if (_onlineStatusTimer?.isActive == true) {
      return;
    }
    _onlineStatusTimer = Timer(_currentOnlineRefreshDelay, _executeOnlineStatusRefresh);
  }

  void _stopOnlineStatusRefresh() {
    _onlineStatusTimer?.cancel();
    _onlineStatusTimer = null;
    _onlineRefreshInFlight = false;
  }

  Future<void> _executeOnlineStatusRefresh() async {
    _onlineStatusTimer = null;
    if (!_canScheduleOnlineRefresh) {
      return;
    }
    _onlineRefreshInFlight = true;
    final success = await _refreshVisibleUsersOnlineStatus();
    _onlineRefreshInFlight = false;
    if (success) {
      _currentOnlineRefreshDelay = _onlineRefreshInterval;
    } else {
      final nextSeconds = (_currentOnlineRefreshDelay.inSeconds * 2)
          .clamp(_onlineRefreshInterval.inSeconds, _maxOnlineRefreshInterval.inSeconds);
      _currentOnlineRefreshDelay = Duration(seconds: nextSeconds);
    }
    if (mounted) {
      _scheduleOnlineStatusRefresh();
    }
  }

  Future<T> _runWithOnlineRefreshPaused<T>(Future<T> Function() action) async {
    final previousPaused = _onlineRefreshPaused;
    _onlineRefreshPaused = true;
    _stopOnlineStatusRefresh();
    try {
      return await action();
    } finally {
      _onlineRefreshPaused = previousPaused;
      if (!_onlineRefreshPaused) {
        _scheduleOnlineStatusRefresh();
      }
    }
  }

  // 后端 list/export 接口虽然支持 stage_id/is_online，但页面查询区只开放账号、角色、账号状态筛选，故不传这两个参数。
  Future<UserListResult> _queryUsersPage(int page) {
    return _userService.listUsers(
      page: page,
      pageSize: _userPageSize,
      keyword: _keywordController.text.trim(),
      roleCode: _filterRoleCode,
      isActive: _filterIsActive,
    );
  }

  Future<bool> _refreshVisibleUsersOnlineStatus() async {
    final userIds = _pollableUsers.map((user) => user.id).toList(growable: false);
    if (userIds.isEmpty) {
      return false;
    }
    try {
      final onlineUserIds = await _userService.listOnlineUserIds(
        userIds: userIds,
      );
      if (!mounted) {
        return false;
      }
      setState(() {
        _users = _users
            .map(
              (user) =>
                  user.copyWith(isOnline: onlineUserIds.contains(user.id)),
            )
            .toList(growable: false);
      });
      return true;
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
      }
      return false;
    }
  }

  Future<void> _refreshUsersFromHeader() async {
    final now = DateTime.now();
    final lastRefreshAt = _lastHeaderRefreshAt;
    if (lastRefreshAt != null &&
        now.difference(lastRefreshAt) < _headerRefreshCooldown) {
      _showHeaderRefreshThrottledMessage(now);
      return;
    }
    _lastHeaderRefreshAt = now;
    await _loadUsers(page: _userPage);
  }

  void _showHeaderRefreshThrottledMessage(DateTime now) {
    if (!mounted) {
      return;
    }
    final lastFeedbackAt = _lastHeaderRefreshFeedbackAt;
    if (lastFeedbackAt != null &&
        now.difference(lastFeedbackAt) < _headerRefreshCooldown) {
      return;
    }
    _lastHeaderRefreshFeedbackAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
        content: Text(_headerRefreshThrottledMessage),
      ),
    );
  }

  Future<void> _loadInitialData({int? page}) async {
    final targetPage = page ?? _userPage;
    setState(() {
      _loading = true;
      _queryInFlight = true;
      _message = '';
    });

    try {
      await _runWithOnlineRefreshPaused(() async {
        if (!_baseDataLoaded) {
          final baseData = await Future.wait<dynamic>([
            _userService.listAllRoles(),
            _craftService.listStages(pageSize: 500, enabled: true),
            _userService.getMyProfile(),
          ]);
          final roles = baseData[0] as RoleListResult;
          final stages = baseData[1] as CraftStageListResult;
          final myProfile = baseData[2] as ProfileResult;
          if (!mounted) {
            return;
          }
          setState(() {
            _roles = roles.items;
            _stages = stages.items;
            _myRoleCode = myProfile.roleCode;
            _baseDataLoaded = true;
          });
        }

        var users = await _queryUsersPage(targetPage);
        var resolvedTotalPages = users.total <= 0
            ? 1
            : (((users.total - 1) ~/ _userPageSize) + 1);
        var resolvedPage = targetPage > resolvedTotalPages
            ? resolvedTotalPages
            : targetPage;
        if (resolvedPage != targetPage) {
          users = await _queryUsersPage(resolvedPage);
          resolvedTotalPages = users.total <= 0
              ? 1
              : (((users.total - 1) ~/ _userPageSize) + 1);
          if (resolvedPage > resolvedTotalPages) {
            resolvedPage = resolvedTotalPages;
          }
        }

        if (!mounted) {
          return;
        }
        setState(() {
          _users = users.items;
          _total = users.total;
          _userPage = resolvedPage;
        });
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
          _queryInFlight = false;
        });
        _scheduleOnlineStatusRefresh();
      }
    }
  }

  Future<void> _loadUsers({bool silent = false, int? page}) async {
    if (!silent) {
      await _runWithOnlineRefreshPaused(() async {
        await _loadUsersCore(silent: false, page: page);
      });
      return;
    }
    await _loadUsersCore(silent: true, page: page);
  }

  Future<void> _loadUsersCore({required bool silent, int? page}) async {
    final targetPage = page ?? _userPage;
    if (!silent) {
      setState(() {
        _loading = true;
        _queryInFlight = true;
        _message = '';
      });
    }

    try {
      final result = await _queryUsersPage(targetPage);
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
        await _loadUsersCore(silent: silent, page: resolvedPage);
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
      if (mounted) {
        if (!silent) {
          setState(() {
            _loading = false;
            _queryInFlight = false;
          });
        }
        _scheduleOnlineStatusRefresh();
      }
    }
  }

  Future<void> _showCreateUserDialog() async {
    if (!widget.canCreateUser) {
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
            final canAssignStage = _canAssignStage(selectedRoleCode);

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
                          decoration: const InputDecoration(labelText: '账号'),
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
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '密码',
                            helperText: '密码规则：至少6位；不能包含连续4位相同字符。',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入密码';
                            }
                            if (value.length < 6) {
                              return '密码至少 6 个字符';
                            }
                            if (RegExp(r'(.)\1\1\1').hasMatch(value)) {
                              return '密码不能包含连续4位相同字符';
                            }
                            return null;
                          },
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
                          '工段分配（单选，操作员必选，自定义角色可选）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: canAssignStage ? 1 : 0.5,
                          child: IgnorePointer(
                            ignoring: !canAssignStage,
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
    if (!widget.canEditUser) {
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
    final formKey = GlobalKey<FormState>();
    final canEditAccount = _isCurrentUserSystemAdmin();
    String? selectedRoleCode = user.roleCode;
    int? selectedStageId = _canAssignStage(selectedRoleCode)
        ? user.stageId
        : null;

    final updated = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = _isOperator(selectedRoleCode);
            final canAssignStage = _canAssignStage(selectedRoleCode);

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
                            labelText: '账号',
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
                          '工段分配（单选，操作员必选，自定义角色可选）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: canAssignStage ? 1 : 0.5,
                          child: IgnorePointer(
                            ignoring: !canAssignStage,
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
                        roleCode: selectedRoleCode!,
                        stageId: selectedStageId,
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
    if (!widget.canDeleteUser) {
      _showNoPermission();
      return;
    }
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
        setState(() {
          _users = _users
              .where((existing) => existing.id != user.id)
              .toList(growable: false);
          _total = (_total > 0) ? _total - 1 : 0;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('用户 ${user.username} 已逻辑删除并停用')));
      }
      await _loadUsers(silent: true);
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
    if (!widget.canToggleUser) {
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
        setState(() {
          _users = _users
              .map(
                (existing) => existing.id == user.id
                    ? existing.copyWith(
                        isActive: active,
                        isOnline: active ? existing.isOnline : false,
                      )
                    : existing,
              )
              .toList(growable: false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户 ${user.username} 已$actionLabel')),
        );
      }
      await _loadUsers(silent: true);
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
    if (!widget.canResetPassword) {
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
                decoration: const InputDecoration(
                  labelText: '新密码',
                  helperText: '密码规则：至少6位；不能包含连续4位相同字符。',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入新密码';
                  if (value.length < 6) return '密码至少 6 个字符';
                  if (RegExp(r'(.)\1\1\1').hasMatch(value)) {
                    return '新密码不能包含连续4位相同字符';
                  }
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
      setState(() {
        _users = _users
            .map(
              (existing) => existing.id == user.id
                  ? existing.copyWith(isOnline: false)
                  : existing,
            )
            .toList(growable: false);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('用户 ${user.username} 密码已重置')));
      await _loadUsers(silent: true);
    }
  }

  Future<void> _exportUsers({String format = 'csv'}) async {
    if (!widget.canExport) {
      _showNoPermission();
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await _userService.exportUsers(
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        roleCode: _filterRoleCode,
        isActive: _filterIsActive,
        format: format,
      );
      if (!mounted) return;
      final savedPath = await _saveExportFile(
        filename: result.filename,
        contentBase64: result.contentBase64,
        contentType: result.contentType,
        format: format,
      );
      if (!mounted) return;
      if (savedPath == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消导出保存')));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导出到 $savedPath')));
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
    if (action == _UserAction.resetPassword) {
      await _showResetPasswordDialog(user);
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
        return;
      case _UserAction.delete:
        await _confirmDeleteUser(user);
        return;
    }
  }

  Widget _buildKeywordField() {
    return TextField(
      key: const ValueKey('userToolbarKeywordField'),
      controller: _keywordController,
      decoration: const InputDecoration(
        labelText: '按账号搜索',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _loadUsers(page: 1),
    );
  }

  Widget _buildRoleFilter() {
    return DropdownButtonFormField<String?>(
      key: const ValueKey('userToolbarRoleFilter'),
      initialValue: _filterRoleCode,
      decoration: const InputDecoration(
        labelText: '用户角色',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<bool?>(
      key: const ValueKey('userToolbarStatusFilter'),
      initialValue: _filterIsActive,
      decoration: const InputDecoration(
        labelText: '账号状态',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  List<Widget> _buildToolbarButtons() {
    final theme = Theme.of(context);
    final isQuerying = _queryInFlight;
    final buttons = <Widget>[
      FilledButton.icon(
        onPressed: _loading ? null : () => _loadUsers(page: 1),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: isQuerying
              ? SizedBox(
                  key: const ValueKey('queryBusy'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : const Icon(Icons.search, key: ValueKey('queryIcon')),
        ),
        label: Text(isQuerying ? '查询中...' : '查询用户'),
      ),
      FilledButton.icon(
        onPressed: (_loading || !widget.canCreateUser)
            ? null
            : _showCreateUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('新建用户'),
      ),
    ];

    if (widget.onNavigateToRoleManagement != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: widget.onNavigateToRoleManagement,
          icon: const Icon(Icons.admin_panel_settings),
          label: const Text('角色管理'),
        ),
      );
    }

    if (widget.canExport) {
      buttons.add(
        PopupMenuButton<String>(
          enabled: !_loading,
          onSelected: _loading ? null : (value) => _exportUsers(format: value),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'csv', child: Text('导出 CSV')),
            PopupMenuItem(value: 'excel', child: Text('导出 Excel')),
          ],
        child: IgnorePointer(
          child: OutlinedButton.icon(
            onPressed: _loading ? null : () {},
            icon: const Icon(Icons.download),
            label: const Text('导出当前筛选结果'),
          ),
        ),
        ),
      );
    }

    return buttons;
  }

  Widget _buildToolbar() {
    const spacing = 12.0;
    const roleWidth = 150.0;
    const statusWidth = 130.0;
    const desktopSearchMinWidth = 320.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttons = _buildToolbarButtons();
        final roleFilter = SizedBox(
          width: roleWidth,
          child: _buildRoleFilter(),
        );
        final statusFilter = SizedBox(
          width: statusWidth,
          child: _buildStatusFilter(),
        );
        final desktopToolbarMinWidth =
            roleWidth +
            statusWidth +
            desktopSearchMinWidth +
            (buttons.length * 120) +
            ((buttons.length + 3) * spacing);

        if (constraints.maxWidth >= desktopToolbarMinWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildKeywordField()),
              const SizedBox(width: spacing),
              statusFilter,
              const SizedBox(width: spacing),
              roleFilter,
              const SizedBox(width: spacing),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: spacing,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.end,
                  children: buttons,
                ),
              ),
            ],
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 280, child: _buildKeywordField()),
            statusFilter,
            roleFilter,
            ...buttons,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emptyListHint = _emptyListMessage;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CrudPageHeader(
            title: '用户管理',
            onRefresh: _loading ? null : _refreshUsersFromHeader,
          ),
          const SizedBox(height: 12),
          _buildToolbar(),
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
            child: CrudListTableSection(
              key: const ValueKey('userListSection'),
              cardKey: const ValueKey('userListCard'),
              loading: _loading,
              isEmpty: _users.isEmpty,
              emptyText: emptyListHint,
              enableUnifiedHeaderStyle: true,
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  UnifiedListTableHeaderStyle.column(context, '账号'),
                  UnifiedListTableHeaderStyle.column(context, '角色'),
                  UnifiedListTableHeaderStyle.column(context, '工段'),
                  UnifiedListTableHeaderStyle.column(context, '在线'),
                  UnifiedListTableHeaderStyle.column(context, '状态'),
                  UnifiedListTableHeaderStyle.column(context, '创建时间'),
                  UnifiedListTableHeaderStyle.column(context, '操作'),
                ],
                rows: _users.map((user) {
                  final statusLabel = user.isOnline ? '在线' : '离线';
                  final statusColor = user.isOnline
                      ? Colors.green
                      : theme.colorScheme.outline;
                  final activeLabel = user.isActive ? '启用' : '停用';
                  final activeColor = user.isActive ? Colors.blue : Colors.red;
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
                        UnifiedListTableHeaderStyle.actionMenuButton<
                          _UserAction
                        >(
                          theme: theme,
                          onSelected: (action) =>
                              _handleUserAction(action, user),
                          itemBuilder: (context) => [
                            if (widget.canEditUser)
                              const PopupMenuItem(
                                value: _UserAction.edit,
                                child: Text('编辑'),
                              ),
                            if (widget.canToggleUser && user.isActive)
                              const PopupMenuItem(
                                value: _UserAction.disable,
                                child: Text('停用'),
                              )
                            else if (widget.canToggleUser)
                              const PopupMenuItem(
                                value: _UserAction.enable,
                                child: Text('启用'),
                              ),
                            if (widget.canResetPassword)
                              const PopupMenuItem(
                                value: _UserAction.resetPassword,
                                child: Text('重置密码'),
                              ),
                            if (widget.canDeleteUser)
                              const PopupMenuItem(
                                value: _UserAction.delete,
                                child: Text('删除'),
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
          const SizedBox(height: 12),
          SimplePaginationBar(
            page: _userPage,
            totalPages: _userTotalPages,
            total: _total,
            loading: _loading,
            showTotal: false,
            onPrevious: () => _loadUsers(page: _userPage - 1),
            onNext: () => _loadUsers(page: _userPage + 1),
          ),
        ],
      ),
    );
  }
}
