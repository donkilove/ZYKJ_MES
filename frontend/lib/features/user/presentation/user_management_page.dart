import 'dart:async';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/core/services/export_file_service.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/user/services/user_service.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/features/user/presentation/widgets/user_create_dialog.dart';
import 'package:mes_client/features/user/presentation/widgets/user_edit_dialog.dart';
import 'package:mes_client/features/user/presentation/widgets/user_export_task_dialog.dart';
import 'package:mes_client/features/user/presentation/widgets/user_reset_password_dialog.dart';
import 'package:mes_client/features/user/presentation/widgets/user_action_dialogs.dart';
import 'package:mes_client/features/user/presentation/widgets/user_import_dialog.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_feedback_banner.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_filter_section.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_page_header.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_table_section.dart';
import 'package:mes_client/features/user/presentation/widgets/user_data_table.dart';

typedef UserExportFileSaver =
    Future<String?> Function({
      required String filename,
      required List<int> bytes,
      required String mimeType,
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
    this.canImport = false,
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
  final bool canImport;
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
  static const String _deletedScopeActive = 'active';
  static const String _deletedScopeDeleted = 'deleted';
  static const String _deletedScopeAll = 'all';
  static const int _userPageSize = 10;
  static const Duration _headerRefreshCooldown = Duration(seconds: 2);
  static const String _headerRefreshThrottledMessage = '刚刚已刷新，无需重复操作';

  late final UserService _userService;
  late final CraftService _craftService;
  late final ExportFileService _exportFileService;
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
    _exportFileService = const ExportFileService();
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
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

  Future<String?> _saveExportFile({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    required String format,
  }) async {
    final customSaver = widget.saveExportFile;
    if (customSaver != null) {
      return customSaver(
        filename: filename,
        bytes: bytes,
        mimeType: mimeType,
        format: format,
      );
    }
    return _exportFileService.saveBytes(
      filename: filename,
      bytes: bytes,
      mimeType: mimeType,
      format: format,
    );
  }

  Future<void> _applyFiltersAndReload() => _loadUsers(page: 1);

  Future<void> _handleActionSuccess() =>
      _loadUsers(silent: true, page: _userPage);

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

  Future<void> _confirmDeleteUser(UserItem user) async {
    if (!widget.canDeleteUser) {
      _showNoPermission();
      return;
    }
    await showConfirmDeleteUserDialog(
      context: context,
      userService: _userService,
      user: user,
      roleLabel: _roleLabelForUser(user.roleCode, user.roleName),
      stageLabel: _stageLabelForUser(user.stageId, user.stageName),
      onError: (error) {
        if (_isUnauthorized(error)) {
          widget.onLogout();
        } else if (mounted) {
          setState(() => _message = '删除用户失败：${_errorMessage(error)}');
        }
      },
      onSuccess: (result) async {
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
            SnackBar(content: Text(formatDeleteSuccessMessage(result))),
          );
        }
        await _handleActionSuccess();
      },
    );
  }

  Future<void> _confirmRestoreUser(UserItem user) async {
    if (!widget.canRestoreUser) {
      _showNoPermission();
      return;
    }
    await showConfirmRestoreUserDialog(
      context: context,
      userService: _userService,
      user: user,
      roleLabel: _roleLabelForUser(user.roleCode, user.roleName),
      stageLabel: _stageLabelForUser(user.stageId, user.stageName),
      onError: (error) {
        if (_isUnauthorized(error)) {
          widget.onLogout();
        } else if (mounted) {
          setState(() => _message = '恢复用户失败：${_errorMessage(error)}');
        }
      },
      onSuccess: (result) async {
        if (mounted) {
          setState(() {
            if (_deletedScope == _deletedScopeDeleted) {
              _users = _users
                  .where((existing) => existing.id != user.id)
                  .toList(growable: false);
              _total = (_total > 0) ? _total - 1 : 0;
            } else {
              _users = _users
                  .map(
                    (existing) =>
                        existing.id == user.id ? result.user : existing,
                  )
                  .toList(growable: false);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(formatRestoreSuccessMessage(result))),
          );
        }
        await _handleActionSuccess();
      },
    );
  }

  Future<void> _toggleUserActive(UserItem user, {required bool active}) async {
    if (!widget.canToggleUser) {
      _showNoPermission();
      return;
    }
    await showToggleUserActiveDialog(
      context: context,
      userService: _userService,
      user: user,
      active: active,
      roleLabel: _roleLabelForUser(user.roleCode, user.roleName),
      myUserId: _myUserId,
      onLogout: widget.onLogout,
      onError: (error) {
        if (_isUnauthorized(error)) {
          widget.onLogout();
        } else if (mounted) {
          final actionLabel = active ? '启用' : '停用';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$actionLabel用户失败：${_errorMessage(error)}')),
          );
        }
      },
      onSuccess: (result) async {
        await _handleActionSuccess();
      },
    );
  }

  String? get _normalizedKeyword {
    final keyword = _keywordController.text.trim();
    return keyword.isEmpty ? null : keyword;
  }

  String _deletedScopeText(String value) {
    switch (value) {
      case _deletedScopeDeleted:
        return '仅已删除';
      case _deletedScopeAll:
        return '全部用户';
      case _deletedScopeActive:
      default:
        return '常规用户';
    }
  }

  String _formatLabel(String format) => format == 'excel' ? 'Excel' : 'CSV';

  Future<void> _showCreateExportTaskDialog({required String format}) async {
    if (!widget.canExport) {
      _showNoPermission();
      return;
    }
    final confirmed = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return MesDialog(
          title: const Text('创建导出任务'),
          width: 420,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('导出格式：${_formatLabel(format)}'),
              const SizedBox(height: 6),
              Text('当前关键词：${_normalizedKeyword ?? '未设置'}'),
              const SizedBox(height: 6),
              Text('当前角色筛选：${_filterRoleCode ?? '全部'}'),
              const SizedBox(height: 6),
              Text(
                '当前账号状态筛选：${_filterIsActive == null
                    ? '全部'
                    : _filterIsActive!
                    ? '启用'
                    : '停用'}',
              ),
              const SizedBox(height: 6),
              Text('当前数据范围：${_deletedScopeText(_deletedScope)}'),
              const SizedBox(height: 6),
              Text('预计导出记录数：$_total'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('创建导出任务'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    try {
      final task = await _userService.createUserExportTask(
        format: format,
        keyword: _normalizedKeyword,
        roleCode: _filterRoleCode,
        isActive: _filterIsActive,
        deletedScope: _deletedScope,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导出任务已创建，生成完成后可下载')));
      await _showExportTaskDialog(highlightTaskId: task.id);
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建导出任务失败：${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _showExportTaskDialog({int? highlightTaskId}) async {
    if (!widget.canExport) {
      _showNoPermission();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return UserExportTaskDialog(
          userService: _userService,
          onLogout: widget.onLogout,
          highlightTaskId: highlightTaskId,
          saveExportFile: _saveExportFile,
        );
      },
    );
  }

  Future<void> _handleUserAction(UserTableAction action, UserItem user) async {
    if (action == UserTableAction.resetPassword) {
      if (!widget.canResetPassword) {
        _showNoPermission();
        return;
      }
      await showUserResetPasswordDialog(
        context: context,
        user: user,
        roleLabel: _roleLabelForUser(user.roleCode, user.roleName),
        userService: _userService,
        onLogout: widget.onLogout,
        onSuccess: _handleActionSuccess,
      );
      return;
    }
    switch (action) {
      case UserTableAction.edit:
        if (!widget.canEditUser) {
          _showNoPermission();
          return;
        }
        await showUserEditDialog(
          context: context,
          userService: _userService,
          user: user,
          allRoles: _roles,
          loadEnabledStages: _loadEnabledStagesForDialog,
          runWithOnlineRefreshPaused: _runWithOnlineRefreshPaused,
          assignableRoles: _assignableRoles,
          isCurrentUserSystemAdmin: _isCurrentUserSystemAdmin,
          roleLabelForUser: _roleLabelForUser,
          stageLabelForUser: _stageLabelForUser,
          formatDialogDateTime: _formatDialogDateTime,
          onLogout: widget.onLogout,
          onSuccess: _handleActionSuccess,
        );
        return;
      case UserTableAction.disable:
        await _toggleUserActive(user, active: false);
        return;
      case UserTableAction.enable:
        await _toggleUserActive(user, active: true);
        return;
      case UserTableAction.resetPassword:
        await showUserResetPasswordDialog(
          context: context,
          user: user,
          roleLabel: _roleLabelForUser(user.roleCode, user.roleName),
          userService: _userService,
          onLogout: widget.onLogout,
          onSuccess: _handleActionSuccess,
        );
        return;
      case UserTableAction.delete:
        await _confirmDeleteUser(user);
        return;
      case UserTableAction.restore:
        await _confirmRestoreUser(user);
        return;
    }
  }

  List<Widget> _buildToolbarButtons() {
    final theme = Theme.of(context);
    final isQuerying = _queryInFlight;
    final buttons = <Widget>[
      FilledButton.icon(
        onPressed: _loading ? null : _applyFiltersAndReload,
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
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.search, key: ValueKey('queryIcon')),
        ),
        label: Text(isQuerying ? '查询中...' : '查询用户'),
      ),
      FilledButton.icon(
        onPressed: (_loading || !widget.canCreateUser)
            ? null
            : () => showUserCreateDialog(
                context: context,
                userService: _userService,
                assignableRoles: _assignableRoles(),
                allRoles: _roles,
                loadEnabledStages: _loadEnabledStagesForDialog,
                onLogout: widget.onLogout,
                onSuccess: _handleActionSuccess,
              ),
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
          onSelected: _loading
              ? null
              : (value) => _showCreateExportTaskDialog(format: value),
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
      buttons.add(
        OutlinedButton.icon(
          onPressed: _loading ? null : _showExportTaskDialog,
          icon: const Icon(Icons.history),
          label: const Text('导出任务'),
        ),
      );
    }

    if (widget.canImport) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _loading
              ? null
              : () => showUserImportDialog(
                  context: context,
                  userService: _userService,
                ),
          icon: const Icon(Icons.upload_file),
          label: const Text('批量导入'),
        ),
      );
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    final emptyListHint = _emptyListMessage;

    return MesCrudPageScaffold(
      header: UserManagementPageHeader(
        loading: _loading,
        onRefresh: _refreshUsersFromHeader,
      ),
      filters: UserManagementFilterSection(
        keywordController: _keywordController,
        filterRoleCode: _filterRoleCode,
        filterIsActive: _filterIsActive,
        deletedScope: _deletedScope,
        roles: _roles,
        onFilterRoleCodeChanged: (value) {
          setState(() => _filterRoleCode = value);
          _applyFiltersAndReload();
        },
        onFilterIsActiveChanged: (value) {
          setState(() => _filterIsActive = value);
          _applyFiltersAndReload();
        },
        onFilterDeletedScopeChanged: (value) {
          setState(() => _deletedScope = value);
          _applyFiltersAndReload();
        },
        onSearch: _applyFiltersAndReload,
        actions: _buildToolbarButtons(),
      ),
      banner: _message.isEmpty
          ? null
          : UserManagementFeedbackBanner(message: _message),
      content: UserManagementTableSection(
        users: _users,
        loading: _loading,
        emptyText: emptyListHint,
        canEditUser: widget.canEditUser,
        canToggleUser: widget.canToggleUser,
        canResetPassword: widget.canResetPassword,
        canDeleteUser: widget.canDeleteUser,
        canRestoreUser: widget.canRestoreUser,
        myUserId: _myUserId,
        onAction: _handleUserAction,
      ),
      pagination: MesPaginationBar(
        page: _userPage,
        totalPages: _userTotalPages,
        total: _total,
        loading: _loading,
        showTotal: false,
        onPrevious: () => _loadUsers(page: _userPage - 1),
        onNext: () => _loadUsers(page: _userPage + 1),
      ),
    );
  }
}
