import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_approve_dialog.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_reject_dialog.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_approval_feedback_banner.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_approval_filter_section.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_approval_page_header.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_approval_table_section.dart';

class RegistrationApprovalPage extends StatefulWidget {
  const RegistrationApprovalPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canApprove,
    required this.canReject,
    this.routePayloadJson,
    this.userService,
    this.craftService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canApprove;
  final bool canReject;
  final String? routePayloadJson;
  final UserService? userService;
  final CraftService? craftService;

  @override
  State<RegistrationApprovalPage> createState() =>
      _RegistrationApprovalPageState();
}

class _RegistrationApprovalPageState extends State<RegistrationApprovalPage> {
  static const String _operatorRoleCode = 'operator';
  static const int _requestPageSize = 10;

  late final UserService _userService;
  late final CraftService _craftService;

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<RegistrationRequestItem> _items = const [];
  List<RoleItem> _roles = const [];
  List<CraftStageItem> _stages = const [];
  int _requestPage = 1;
  String? _statusFilter = 'pending';
  int? _jumpRequestId;
  String? _lastHandledRoutePayloadJson;

  int get _requestTotalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _requestPageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService(widget.session);
    _craftService = widget.craftService ?? CraftService(widget.session);
    _consumeRoutePayload(widget.routePayloadJson);
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant RegistrationApprovalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routePayloadJson != oldWidget.routePayloadJson) {
      _consumeRoutePayload(widget.routePayloadJson);
    }
  }

  @override
  void dispose() {
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
    ).showSnackBar(const SnackBar(content: Text('当前账号没有审批权限')));
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  int? _parsePositiveInt(dynamic rawValue) {
    final value = switch (rawValue) {
      int v => v,
      String v => int.tryParse(v.trim()),
      _ => null,
    };
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  void _consumeRoutePayload(String? rawJson) {
    final normalized = (rawJson ?? '').trim();
    if (normalized.isEmpty || normalized == _lastHandledRoutePayloadJson) {
      return;
    }
    _lastHandledRoutePayloadJson = normalized;
    try {
      final payload = jsonDecode(normalized);
      if (payload is! Map<String, dynamic>) {
        return;
      }
      final requestId = _parsePositiveInt(payload['request_id']);
      if (requestId == null) {
        return;
      }
      setState(() {
        _jumpRequestId = requestId;
        _message = '已收到目标注册申请 #$requestId 的跳转请求，正在定位。';
      });
      final shouldReloadAllStatuses = _statusFilter != null;
      if (shouldReloadAllStatuses) {
        _applyStatusFilterAndReload(null);
        return;
      }
      if (_items.isNotEmpty || _total > 0 || _loading) {
        _applyJumpTargetHint();
      }
    } catch (_) {
      return;
    }
  }

  void _applyJumpTargetHint() {
    final requestId = _jumpRequestId;
    if (requestId == null || _loading) {
      return;
    }
    final matched = _items.where((item) => item.id == requestId).firstOrNull;
    setState(() {
      _message = matched == null
          ? '已切换到注册审批页，已收到目标注册申请 #$requestId，但当前列表页未定位到该记录。'
          : '已定位注册申请 #$requestId（账号：${matched.account}）。';
    });
    _jumpRequestId = null;
  }

  String? _defaultRoleCode() {
    final roles = _assignableRoles();
    if (roles.isEmpty) {
      return null;
    }
    for (final role in roles) {
      if (role.code == _operatorRoleCode) {
        return role.code;
      }
    }
    return roles.first.code;
  }

  bool _isOperator(String? roleCode) => roleCode == _operatorRoleCode;

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

  Future<void> _loadInitialData({int? page}) async {
    final targetPage = page ?? _requestPage;
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await Future.wait<dynamic>([
        _userService.listRegistrationRequests(
          page: targetPage,
          pageSize: _requestPageSize,
          status: _statusFilter,
        ),
        _userService.listAllRoles(),
        _craftService.listStages(pageSize: 500, enabled: true),
      ]);
      final requests = result[0] as RegistrationRequestListResult;
      final roles = result[1] as RoleListResult;
      final stages = result[2] as CraftStageListResult;

      if (!mounted) {
        return;
      }
      final resolvedTotalPages = requests.total <= 0
          ? 1
          : (((requests.total - 1) ~/ _requestPageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _items = requests.items;
        _total = requests.total;
        _roles = roles.items;
        _stages = stages.items;
        _requestPage = resolvedPage;
      });
      _applyJumpTargetHint();
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
            ? '当前账号没有注册审批权限。'
            : '加载注册审批数据失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRequests({int? page}) async {
    final targetPage = page ?? _requestPage;
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await _userService.listRegistrationRequests(
        page: targetPage,
        pageSize: _requestPageSize,
        status: _statusFilter,
      );
      if (!mounted) {
        return;
      }
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _requestPageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _items = result.items;
        _total = result.total;
        _requestPage = resolvedPage;
      });
      _applyJumpTargetHint();
      if (resolvedPage != targetPage) {
        await _loadRequests(page: resolvedPage);
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
            ? '当前账号没有注册审批权限。'
            : '加载注册申请失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reloadCurrentPage() => _loadRequests(page: _requestPage);

  Future<void> _applyStatusFilterAndReload(String? value) async {
    setState(() => _statusFilter = value);
    await _loadRequests(page: 1);
  }

  Future<void> _handleActionSuccess() => _reloadCurrentPage();

  Future<bool> _approveRequest({
    required RegistrationRequestItem item,
    required String account,
    required String roleCode,
    String? password,
    int? stageId,
  }) async {
    try {
      await _userService.approveRegistrationRequest(
        requestId: item.id,
        account: account,
        roleCode: roleCode,
        password: password,
        stageId: stageId,
      );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已通过账号 $account 的注册申请。')));
      await _handleActionSuccess();
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      setState(() {
        _message = '审批通过失败：${_errorMessage(error)}';
      });
      return false;
    }
  }

  Future<void> _openApproveDialog(RegistrationRequestItem item) async {
    if (!widget.canApprove) {
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

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return RegistrationApproveDialog(
          item: item,
          assignableRoles: assignableRoles,
          currentStages: currentStages,
          defaultRoleCode: _defaultRoleCode(),
          isOperator: _isOperator,
          onApprove: ({
            required account,
            required roleCode,
            password,
            stageId,
          }) async {
            return await _approveRequest(
              item: item,
              account: account,
              roleCode: roleCode,
              password: password,
              stageId: stageId,
            );
          },
        );
      },
    );



    if (approved == true && mounted) {
      setState(() {
        _message = '';
      });
    }
  }

  Future<void> _rejectRequest(
    RegistrationRequestItem item, {
    String? reason,
  }) async {
    if (!widget.canReject) {
      _showNoPermission();
      return;
    }
    try {
      await _userService.rejectRegistrationRequest(
        requestId: item.id,
        reason: reason,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已驳回账号 ${item.account} 的注册申请。')));
      await _handleActionSuccess();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '驳回申请失败：${_errorMessage(error)}';
      });
    }
  }

  Future<void> _confirmReject(RegistrationRequestItem item) async {
    if (!widget.canReject) {
      _showNoPermission();
      return;
    }
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return RegistrationRejectDialog(
          item: item,
          onReject: ({reason}) async {
            await _rejectRequest(item, reason: reason);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MesCrudPageScaffold(
      header: RegistrationApprovalPageHeader(
        loading: _loading,
        onRefresh: () => _loadInitialData(page: _requestPage),
      ),
      filters: RegistrationApprovalFilterSection(
        statusFilter: _statusFilter,
        onChanged: _applyStatusFilterAndReload,
      ),
      banner: _message.isEmpty
          ? null
          : RegistrationApprovalFeedbackBanner(message: _message),
      content: RegistrationApprovalTableSection(
        items: _items,
        loading: _loading,
        emptyText: _statusFilter == null ? '暂无注册申请记录' : '当前状态下暂无注册申请记录',
        canApprove: widget.canApprove,
        canReject: widget.canReject,
        onApprove: _openApproveDialog,
        onReject: _confirmReject,
        formatTime: _formatTime,
      ),
      pagination: MesPaginationBar(
        page: _requestPage,
        totalPages: _requestTotalPages,
        total: _total,
        loading: _loading,
        onPrevious: () => _loadRequests(page: _requestPage - 1),
        onNext: () => _loadRequests(page: _requestPage + 1),
      ),
    );
  }
}
