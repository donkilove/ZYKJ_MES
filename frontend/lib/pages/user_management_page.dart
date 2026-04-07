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

enum _UserAction { edit, disable, enable, resetPassword, delete, restore }

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
    this.canRestoreUser = false,
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
  final bool canRestoreUser;
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
  static const String _deletedScopeActive = 'active';
  static const String _deletedScopeDeleted = 'deleted';
  static const String _deletedScopeAll = 'all';
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
  List<UserItem> get _pollableUsers => _users
      .where((user) => user.isActive && !user.isDeleted)
      .toList(growable: false);

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
  String _deletedScope = _deletedScopeActive;

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
  int? _myUserId;
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
        _filterIsActive != null ||
        _deletedScope != _deletedScopeActive;
  }

  String get _deletedScopeLabel {
    switch (_deletedScope) {
      case _deletedScopeDeleted:
        return '已删除用户';
      case _deletedScopeAll:
        return '全部用户';
      case _deletedScopeActive:
      default:
        return '常规用户';
    }
  }

  String get _emptyListMessage {
    if (_hasSearchCriteria) {
      return '当前$_deletedScopeLabel筛选未命中任何用户，请尝试修改关键词或清除筛选。';
    }
    if (_deletedScope == _deletedScopeDeleted) {
      return '暂无已删除用户';
    }
    return '暂无用户';
  }

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

  String _formatDialogDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _roleLabelForUser(String? roleCode, String? roleName) {
    final role = _findRoleByCode(roleCode);
    if (role != null) {
      return role.name;
    }
    if (roleName != null && roleName.trim().isNotEmpty) {
      return roleName.trim();
    }
    return '-';
  }

  String _stageLabelForUser(int? stageId, String? stageName) {
    if (stageName != null && stageName.trim().isNotEmpty) {
      return stageName.trim();
    }
    if (stageId != null) {
      for (final stage in _stages) {
        if (stage.id == stageId) {
          return stage.name;
        }
      }
    }
    return '未分配';
  }

  bool _isCurrentLoginUser(UserItem user) =>
      _myUserId != null && user.id == _myUserId;

  String _formatLifecycleSuccessMessage(
    UserLifecycleResult result, {
    required bool active,
  }) {
    if (active) {
      return '用户 ${result.user.username} 已启用，需重新登录后才会恢复在线状态。';
    }
    final forcedOfflineCount = result.forcedOfflineSessionCount;
    if (forcedOfflineCount > 0) {
      return '用户 ${result.user.username} 已停用，并强制下线 $forcedOfflineCount 个会话。';
    }
    if (result.clearedOnlineStatus) {
      return '用户 ${result.user.username} 已停用，在线状态已清除。';
    }
    return '用户 ${result.user.username} 已停用。';
  }

  String _formatDeleteSuccessMessage(UserDeleteResult result) {
    final forcedOfflineCount = result.forcedOfflineSessionCount;
    if (forcedOfflineCount > 0) {
      return '已逻辑删除用户 ${result.user.username}，并强制下线 $forcedOfflineCount 个会话；用户已移入已删除视图。';
    }
    return '已逻辑删除用户 ${result.user.username}；用户已移入已删除视图。';
  }

  String _formatRestoreSuccessMessage(UserLifecycleResult result) {
    return '用户 ${result.user.username} 已恢复到常规列表，当前保持停用状态。';
  }

  String _formatPasswordResetSuccessMessage(UserPasswordResetResult result) {
    final forcedOfflineCount = result.forcedOfflineSessionCount;
    if (forcedOfflineCount > 0) {
      return '用户 ${result.user.username} 密码已重置，并强制下线 $forcedOfflineCount 个会话。';
    }
    if (result.clearedOnlineStatus) {
      return '用户 ${result.user.username} 密码已重置，在线状态已清除。';
    }
    return '用户 ${result.user.username} 密码已重置。';
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
    _onlineStatusTimer = Timer(
      _currentOnlineRefreshDelay,
      _executeOnlineStatusRefresh,
    );
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
      final nextSeconds = (_currentOnlineRefreshDelay.inSeconds * 2).clamp(
        _onlineRefreshInterval.inSeconds,
        _maxOnlineRefreshInterval.inSeconds,
      );
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

  // 后端 list/export 接口虽然支持 stage_id/is_online，但页面查询区只开放账号、角色、账号状态、数据范围筛选，故不传这两个参数。
  Future<UserListResult> _queryUsersPage(int page) {
    return _userService.listUsers(
      page: page,
      pageSize: _userPageSize,
      keyword: _keywordController.text.trim(),
      roleCode: _filterRoleCode,
      isActive: _filterIsActive,
      deletedScope: _deletedScope,
    );
  }

  Future<bool> _refreshVisibleUsersOnlineStatus() async {
    final userIds = _pollableUsers
        .map((user) => user.id)
        .toList(growable: false);
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
            _myUserId = myProfile.id;
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
    int accountCheckSequence = 0;
    bool checkingAccountConflict = false;
    String? accountConflictError;
    String? createdAccount;
    bool createdActive = true;

    Future<void> checkAccountConflict(
      StateSetter setDialogState, {
      bool force = false,
    }) async {
      final account = accountController.text.trim();
      if (account.isEmpty || account.length < 2 || account.length > 10) {
        setDialogState(() {
          checkingAccountConflict = false;
          accountConflictError = null;
        });
        formKey.currentState?.validate();
        return;
      }
      if (!force && !accountController.selection.isValid) {
        return;
      }
      final currentSequence = ++accountCheckSequence;
      setDialogState(() {
        checkingAccountConflict = true;
        accountConflictError = null;
      });
      try {
        final result = await _userService.listUsers(
          page: 1,
          pageSize: 20,
          keyword: account,
        );
        if (!mounted || currentSequence != accountCheckSequence) {
          return;
        }
        final duplicated = result.items.any(
          (user) => user.username.trim().toLowerCase() == account.toLowerCase(),
        );
        setDialogState(() {
          checkingAccountConflict = false;
          accountConflictError = duplicated ? '账号已存在，请更换后再创建' : null;
        });
        formKey.currentState?.validate();
      } catch (error) {
        if (_isUnauthorized(error)) {
          widget.onLogout();
          return;
        }
        if (!mounted || currentSequence != accountCheckSequence) {
          return;
        }
        setDialogState(() {
          checkingAccountConflict = false;
          accountConflictError = null;
        });
      }
    }

    final created = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = _isOperator(selectedRoleCode);
            final canAssignStage = _canAssignStage(selectedRoleCode);
            final stageHelperText = selectedRoleCode == null
                ? '请先选择角色，再确定是否需要分配工段'
                : isOperatorSelected
                ? '操作员必须选择一个工段后才能创建'
                : canAssignStage
                ? '当前角色可选工段，不选则默认无工段'
                : '该角色无需分配工段';

            return AlertDialog(
              title: const Text('新建用户'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: accountController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: '账号',
                            helperText: checkingAccountConflict
                                ? '正在检查账号是否可用...'
                                : null,
                            suffixIcon: checkingAccountConflict
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          onChanged: (_) {
                            setDialogState(() {
                              accountConflictError = null;
                            });
                            checkAccountConflict(setDialogState);
                          },
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
                            if (accountConflictError != null) {
                              return accountConflictError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                        Text(
                          stageHelperText,
                          style: TextStyle(
                            color: isOperatorSelected
                                ? Colors.red
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            fontWeight: isOperatorSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
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
                    await checkAccountConflict(setDialogState, force: true);
                    if (checkingAccountConflict ||
                        accountConflictError != null) {
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
                      createdAccount = accountController.text.trim();
                      createdActive = isActive;
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
      if (mounted && createdAccount != null) {
        final followup = createdActive
            ? '用户 $createdAccount 已创建，首次登录需修改密码。'
            : '用户 $createdAccount 已创建，首次登录需修改密码；当前为停用状态，启用后方可登录。';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(followup)));
      }
    }
  }

  Future<void> _showEditUserDialog(UserItem user) async {
    if (!widget.canEditUser) {
      _showNoPermission();
      return;
    }
    late final List<CraftStageItem> currentStages;
    var detailUser = user;
    String? detailWarning;
    try {
      final results = await _runWithOnlineRefreshPaused(() async {
        return Future.wait<dynamic>([
          _loadEnabledStagesForDialog(),
          _userService.getUserDetail(userId: user.id),
        ]);
      });
      currentStages = results[0] as List<CraftStageItem>;
      detailUser = results[1] as UserItem;
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      currentStages = await _loadEnabledStagesForDialog();
      detailWarning = '部分详情刷新失败，以下内容已回退为列表中的当前数据。';
    }
    if (!mounted) {
      return;
    }
    final assignableRoles = _assignableRoles(
      includeRoleCode: detailUser.roleCode,
    );
    if (assignableRoles.isEmpty) {
      setState(() {
        _message = '当前没有可分配的启用角色。';
      });
      return;
    }
    final accountController = TextEditingController(text: detailUser.username);
    final formKey = GlobalKey<FormState>();
    final canEditAccount = _isCurrentUserSystemAdmin();
    final originalAccount = detailUser.username.trim();
    final originalRoleCode = detailUser.roleCode;
    final originalRoleName = _roleLabelForUser(
      detailUser.roleCode,
      detailUser.roleName,
    );
    final originalStageId = detailUser.stageId;
    final originalStageName = _stageLabelForUser(
      detailUser.stageId,
      detailUser.stageName,
    );
    final originalActive = detailUser.isActive;
    final originalMustChangePassword = detailUser.mustChangePassword;
    String? selectedRoleCode = detailUser.roleCode;
    int? selectedStageId = _canAssignStage(selectedRoleCode)
        ? detailUser.stageId
        : null;
    bool isActive = detailUser.isActive;
    bool mustChangePassword = detailUser.mustChangePassword;

    final updated = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = _isOperator(selectedRoleCode);
            final canAssignStage = _canAssignStage(selectedRoleCode);
            final theme = Theme.of(context);
            final stageHelperText = selectedRoleCode == null
                ? '请先选择角色，再确定是否需要分配工段'
                : isOperatorSelected
                ? '操作员必须选择一个工段后才能保存'
                : canAssignStage
                ? '当前角色可选工段，不选则默认无工段'
                : '该角色无需分配工段';

            Widget buildInfoItem(String label, String value) {
              return SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: Text('编辑用户：${detailUser.username}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前信息',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            buildInfoItem(
                              '当前账号状态',
                              originalActive ? '启用' : '停用',
                            ),
                            buildInfoItem(
                              '首次登录需改密',
                              originalMustChangePassword ? '是' : '否',
                            ),
                            buildInfoItem(
                              '最近登录时间',
                              _formatDialogDateTime(detailUser.lastLoginAt),
                            ),
                            buildInfoItem(
                              '最近改密时间',
                              _formatDialogDateTime(
                                detailUser.passwordChangedAt,
                              ),
                            ),
                            buildInfoItem(
                              '最近登录 IP',
                              detailUser.lastLoginIp?.trim().isNotEmpty == true
                                  ? detailUser.lastLoginIp!.trim()
                                  : '-',
                            ),
                            buildInfoItem('当前角色', originalRoleName),
                            buildInfoItem('当前工段', originalStageName),
                          ],
                        ),
                        if (detailWarning != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            detailWarning!,
                            key: const ValueKey('userEditDetailWarning'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          '编辑内容',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        Row(
                          children: [
                            const Text('账号状态：'),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              key: const ValueKey('userEditStatusEnabled'),
                              label: const Text('启用'),
                              selected: isActive,
                              onSelected: (_) =>
                                  setDialogState(() => isActive = true),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              key: const ValueKey('userEditStatusDisabled'),
                              label: const Text('停用'),
                              selected: !isActive,
                              onSelected: (_) =>
                                  setDialogState(() => isActive = false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          key: const ValueKey('userEditMustChangePassword'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('下次登录强制改密'),
                          subtitle: Text(
                            mustChangePassword
                                ? '用户下次登录后必须先修改密码'
                                : '用户下次登录无需强制修改密码',
                          ),
                          value: mustChangePassword,
                          onChanged: (value) =>
                              setDialogState(() => mustChangePassword = value),
                        ),
                        const SizedBox(height: 8),
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
                        Text(
                          stageHelperText,
                          style: TextStyle(
                            color: isOperatorSelected
                                ? Colors.red
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isOperatorSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
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

                    final updatedAccount = accountController.text.trim();
                    final updatedRoleCode = selectedRoleCode!;
                    final updatedStageId = _canAssignStage(updatedRoleCode)
                        ? selectedStageId
                        : null;
                    final updatedRoleName = _roleLabelForUser(
                      updatedRoleCode,
                      null,
                    );
                    final updatedStageName = _stageLabelForUser(
                      updatedStageId,
                      null,
                    );
                    final accountChanged =
                        canEditAccount && updatedAccount != originalAccount;
                    final roleChanged = updatedRoleCode != originalRoleCode;
                    final stageChanged = updatedStageId != originalStageId;
                    final activeChanged = isActive != originalActive;
                    final mustChangePasswordChanged =
                        mustChangePassword != originalMustChangePassword;

                    if (!accountChanged &&
                        !roleChanged &&
                        !stageChanged &&
                        !activeChanged &&
                        !mustChangePasswordChanged) {
                      if (context.mounted) {
                        Navigator.of(context).pop(false);
                      }
                      return;
                    }

                    final summaryLines = <String>[];
                    if (accountChanged) {
                      summaryLines.add(
                        '账号：$originalAccount -> $updatedAccount',
                      );
                    }
                    if (roleChanged) {
                      summaryLines.add(
                        '角色：$originalRoleName -> $updatedRoleName',
                      );
                    }
                    if (stageChanged) {
                      summaryLines.add(
                        '工段：$originalStageName -> $updatedStageName',
                      );
                    }
                    if (activeChanged) {
                      summaryLines.add(
                        '账号状态：${originalActive ? '启用' : '停用'} -> ${isActive ? '启用' : '停用'}',
                      );
                    }
                    if (mustChangePasswordChanged) {
                      summaryLines.add(
                        '下次登录强制改密：${originalMustChangePassword ? '开启' : '关闭'} -> ${mustChangePassword ? '开启' : '关闭'}',
                      );
                    }

                    final riskHints = <String>[];
                    if (originalActive && !isActive) {
                      riskHints.add('用户将无法继续登录，在线状态会被置为离线，并收到停用通知');
                    }
                    if (!originalMustChangePassword && mustChangePassword) {
                      riskHints.add('用户下次登录后必须修改密码');
                    }
                    if (roleChanged &&
                        originalStageId != null &&
                        updatedStageId == null) {
                      riskHints.add('角色变更后原工段分配将失效');
                    }

                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('确认保存用户变更'),
                          content: SizedBox(
                            width: 420,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '本次变更摘要',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ...summaryLines.map(
                                  (line) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(line),
                                  ),
                                ),
                                if (riskHints.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '风险提示',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...riskHints.map(
                                    (hint) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(hint),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('确认保存'),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed != true) {
                      return;
                    }

                    try {
                      await _userService.updateUser(
                        userId: detailUser.id,
                        account: accountChanged ? updatedAccount : null,
                        roleCode: roleChanged ? updatedRoleCode : null,
                        stageId: stageChanged ? updatedStageId : null,
                        isActive: activeChanged ? isActive : null,
                        mustChangePassword: mustChangePasswordChanged
                            ? mustChangePassword
                            : null,
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
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;
    final confirmed = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('逻辑删除用户'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '影响摘要',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('目标账号：${user.username}'),
                      const SizedBox(height: 4),
                      Text('当前在线状态：${user.isOnline ? '在线' : '离线'}'),
                      const SizedBox(height: 4),
                      Text(
                        '当前角色：${_roleLabelForUser(user.roleCode, user.roleName)}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前工段：${_stageLabelForUser(user.stageId, user.stageName)}',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '删除后用户会被停用、从常规列表隐藏，且数据仍保留，可在已删除视图中恢复。',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.isOnline ? '提交后将强制下线当前会话。' : '删除后账号不可登录，需恢复后重新管理。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: user.isOnline ? theme.colorScheme.error : null,
                          fontWeight: user.isOnline
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: remarkController,
                        enabled: !submitting,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '删除原因',
                          hintText: '请输入逻辑删除原因',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入删除原因';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setDialogState(() => submitting = true);
                          Navigator.of(context).pop(true);
                        },
                  child: Text(submitting ? '删除中...' : '确认删除'),
                ),
              ],
            );
          },
        );
      },
    );
    final remark = remarkController.text.trim();

    if (confirmed != true) {
      return;
    }

    try {
      final result = await _userService.deleteUser(
        userId: user.id,
        remark: remark,
      );
      if (mounted) {
        setState(() {
          if (_deletedScope == _deletedScopeAll) {
            _users = _users
                .map(
                  (existing) => existing.id == user.id
                      ? result.user.copyWith(isOnline: false)
                      : existing,
                )
                .toList(growable: false);
          } else {
            _users = _users
                .where((existing) => existing.id != user.id)
                .toList(growable: false);
            _total = (_total > 0) ? _total - 1 : 0;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatDeleteSuccessMessage(result))),
        );
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

  Future<void> _confirmRestoreUser(UserItem user) async {
    if (!widget.canRestoreUser) {
      _showNoPermission();
      return;
    }
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    final confirmed = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('恢复用户'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '恢复后用户会回到常规列表，但默认保持停用状态，需要管理员显式启用后才可再次登录。',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Text('目标账号：${user.username}'),
                      const SizedBox(height: 4),
                      Text(
                        '当前角色：${_roleLabelForUser(user.roleCode, user.roleName)}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前工段：${_stageLabelForUser(user.stageId, user.stageName)}',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: remarkController,
                        enabled: !submitting,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '恢复原因',
                          hintText: '请输入恢复原因',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入恢复原因';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setDialogState(() => submitting = true);
                          Navigator.of(context).pop(true);
                        },
                  child: Text(submitting ? '恢复中...' : '确认恢复'),
                ),
              ],
            );
          },
        );
      },
    );
    final remark = remarkController.text.trim();
    if (confirmed != true) {
      return;
    }

    try {
      final result = await _userService.restoreUser(
        userId: user.id,
        remark: remark,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (_deletedScope == _deletedScopeDeleted) {
          _users = _users
              .where((existing) => existing.id != user.id)
              .toList(growable: false);
          _total = (_total > 0) ? _total - 1 : 0;
        } else {
          _users = _users
              .map(
                (existing) => existing.id == user.id ? result.user : existing,
              )
              .toList(growable: false);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatRestoreSuccessMessage(result))),
      );
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
        _message = '恢复用户失败：${_errorMessage(error)}';
      });
    }
  }

  Future<void> _toggleUserActive(UserItem user, {required bool active}) async {
    if (!widget.canToggleUser) {
      _showNoPermission();
      return;
    }
    final actionLabel = active ? '启用' : '停用';
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    final confirmed = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final roleLabel = _roleLabelForUser(user.roleCode, user.roleName);
            final statusLabel = user.isActive ? '启用' : '停用';
            final onlineLabel = user.isOnline ? '在线' : '离线';
            final helperText = active
                ? '启用后账号可重新登录，但不会自动恢复在线状态。'
                : '停用后账号将无法继续登录，系统会强制下线该用户所有活跃会话。';
            return AlertDialog(
              title: Text('$actionLabel用户'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '目标账号：${user.username}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('当前角色：$roleLabel'),
                      const SizedBox(height: 4),
                      Text('当前账号状态：$statusLabel'),
                      const SizedBox(height: 4),
                      Text('当前在线状态：$onlineLabel'),
                      const SizedBox(height: 12),
                      Text(
                        helperText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: !active ? theme.colorScheme.error : null,
                          fontWeight: !active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: remarkController,
                        enabled: !submitting,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: active ? '备注（可选）' : '停用原因',
                          hintText: active ? '可填写启用说明' : '请输入停用原因',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (!active &&
                              (value == null || value.trim().isEmpty)) {
                            return '请输入停用原因';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setDialogState(() => submitting = true);
                          Navigator.of(context).pop(true);
                        },
                  child: Text(submitting ? '$actionLabel中...' : actionLabel),
                ),
              ],
            );
          },
        );
      },
    );
    final remark = remarkController.text.trim();
    if (confirmed != true) {
      return;
    }

    try {
      late final UserLifecycleResult result;
      if (active) {
        result = await _userService.enableUser(
          userId: user.id,
          remark: remark.isEmpty ? null : remark,
        );
      } else {
        result = await _userService.disableUser(
          userId: user.id,
          remark: remark,
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatLifecycleSuccessMessage(result, active: active)),
        ),
      );
      final disabledCurrentUser = !active && result.user.id == _myUserId;
      if (disabledCurrentUser) {
        widget.onLogout();
        return;
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
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    final confirmed = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: Text('重置密码：${user.username}'),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前信息',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('目标账号：${user.username}'),
                      const SizedBox(height: 4),
                      Text(
                        '角色：${_roleLabelForUser(user.roleCode, user.roleName)}',
                      ),
                      const SizedBox(height: 4),
                      Text('当前账号状态：${user.isActive ? '启用' : '停用'}'),
                      const SizedBox(height: 4),
                      Text('当前在线状态：${user.isOnline ? '在线' : '离线'}'),
                      const SizedBox(height: 12),
                      Text(
                        '风险提示：旧密码会立即失效；当前在线会话将被强制下线；下次登录必须修改密码。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: '新密码',
                          helperText: '密码规则：至少6位；不能包含连续4位相同字符。',
                          border: OutlineInputBorder(),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: remarkController,
                        enabled: !submitting,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '重置原因',
                          hintText: '请输入本次重置密码的原因',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入重置原因';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => submitting = true);
                          try {
                            final result = await _userService.resetUserPassword(
                              userId: user.id,
                              password: passwordController.text,
                              remark: remarkController.text,
                            );
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.of(context).pop(true);
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _formatPasswordResetSuccessMessage(result),
                                ),
                              ),
                            );
                            await _loadUsers(silent: true);
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            setDialogState(() => submitting = false);
                            if (_isUnauthorized(error)) {
                              widget.onLogout();
                              return;
                            }
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('重置密码失败：${_errorMessage(error)}'),
                              ),
                            );
                          }
                        },
                  child: Text(submitting ? '重置中...' : '确认重置'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed == true) {
      return;
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
        deletedScope: _deletedScope,
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
        await _showResetPasswordDialog(user);
        return;
      case _UserAction.delete:
        await _confirmDeleteUser(user);
        return;
      case _UserAction.restore:
        await _confirmRestoreUser(user);
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

  Widget _buildDeletedScopeFilter() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('userToolbarDeletedScopeFilter'),
      initialValue: _deletedScope,
      decoration: const InputDecoration(
        labelText: '数据范围',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      items: const [
        DropdownMenuItem(value: _deletedScopeActive, child: Text('常规用户')),
        DropdownMenuItem(value: _deletedScopeDeleted, child: Text('仅已删除')),
        DropdownMenuItem(value: _deletedScopeAll, child: Text('全部用户')),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() => _deletedScope = value);
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
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
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
    const deletedScopeWidth = 150.0;
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
        final deletedScopeFilter = SizedBox(
          width: deletedScopeWidth,
          child: _buildDeletedScopeFilter(),
        );
        final desktopToolbarMinWidth =
            roleWidth +
            statusWidth +
            deletedScopeWidth +
            desktopSearchMinWidth +
            (buttons.length * 120) +
            ((buttons.length + 4) * spacing);

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
              deletedScopeFilter,
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
            deletedScopeFilter,
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
                  final activeLabel = user.isDeleted
                      ? '已删除'
                      : user.isActive
                      ? '启用'
                      : '停用';
                  final activeColor = user.isDeleted
                      ? theme.colorScheme.outline
                      : user.isActive
                      ? Colors.blue
                      : Colors.red;
                  final createdAtStr = user.createdAt != null
                      ? '${user.createdAt!.year}-${user.createdAt!.month.toString().padLeft(2, '0')}-${user.createdAt!.day.toString().padLeft(2, '0')}'
                      : '-';
                  return DataRow(
                    color: user.isDeleted
                        ? MaterialStatePropertyAll<Color?>(
                            theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.35),
                          )
                        : null,
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
                            if (!user.isDeleted && widget.canEditUser)
                              const PopupMenuItem(
                                value: _UserAction.edit,
                                child: Text('编辑'),
                              ),
                            if (!user.isDeleted &&
                                widget.canToggleUser &&
                                user.isActive)
                              const PopupMenuItem(
                                value: _UserAction.disable,
                                child: Text('停用'),
                              )
                            else if (!user.isDeleted && widget.canToggleUser)
                              const PopupMenuItem(
                                value: _UserAction.enable,
                                child: Text('启用'),
                              ),
                            if (!user.isDeleted && widget.canResetPassword)
                              const PopupMenuItem(
                                value: _UserAction.resetPassword,
                                child: Text('重置密码'),
                              ),
                            if (!user.isDeleted &&
                                widget.canDeleteUser &&
                                !_isCurrentLoginUser(user))
                              const PopupMenuItem(
                                value: _UserAction.delete,
                                child: Text('逻辑删除'),
                              ),
                            if (user.isDeleted && widget.canRestoreUser)
                              const PopupMenuItem(
                                value: _UserAction.restore,
                                child: Text('恢复用户'),
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
