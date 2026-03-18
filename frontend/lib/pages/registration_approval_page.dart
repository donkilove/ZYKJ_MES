import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/user_service.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/simple_pagination_bar.dart';

class RegistrationApprovalPage extends StatefulWidget {
  const RegistrationApprovalPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canReviewAction,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canReviewAction;

  @override
  State<RegistrationApprovalPage> createState() =>
      _RegistrationApprovalPageState();
}

class _RegistrationApprovalPageState extends State<RegistrationApprovalPage> {
  static const String _operatorRoleCode = 'operator';
  static const int _requestPageSize = 100;

  late final UserService _userService;
  late final CraftService _craftService;
  final ScrollController _requestListScrollController = ScrollController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<RegistrationRequestItem> _items = const [];
  List<RoleItem> _roles = const [];
  List<ProcessItem> _processes = const [];
  List<CraftStageItem> _stages = const [];
  int _requestPage = 1;

  int get _requestTotalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _requestPageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _userService = UserService(widget.session);
    _craftService = CraftService(widget.session);
    _loadInitialData();
  }

  @override
  void dispose() {
    _requestListScrollController.dispose();
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

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待审批';
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已驳回';
      default:
        return status;
    }
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  String? _defaultRoleCode() {
    if (_roles.isEmpty) {
      return null;
    }
    for (final role in _roles) {
      if (role.code == _operatorRoleCode) {
        return role.code;
      }
    }
    return _roles.first.code;
  }

  bool _isOperator(String? roleCode) => roleCode == _operatorRoleCode;

  List<String> _getProcessCodesByStage(int stageId) {
    return _processes
        .where((p) => p.stageId == stageId)
        .map((p) => p.code)
        .toList();
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
          status: 'pending',
        ),
        _userService.listAllRoles(),
        _userService.listProcesses(),
        _craftService.listStages(pageSize: 500, enabled: true),
      ]);
      final requests = result[0] as RegistrationRequestListResult;
      final roles = result[1] as RoleListResult;
      final processes = result[2] as ProcessListResult;
      final stages = result[3] as CraftStageListResult;

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
        _processes = processes.items;
        _stages = stages.items;
        _requestPage = resolvedPage;
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
        status: 'pending',
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

  Future<bool> _approveRequest({
    required RegistrationRequestItem item,
    required String account,
    required String roleCode,
    required List<String> processCodes,
    String? password,
    int? stageId,
  }) async {
    try {
      await _userService.approveRegistrationRequest(
        requestId: item.id,
        account: account,
        roleCodes: [roleCode],
        processCodes: processCodes,
        password: password,
        stageId: stageId,
      );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已通过账号 $account 的注册申请。')));
      await _loadRequests();
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
    if (!widget.canReviewAction) {
      _showNoPermission();
      return;
    }
    if (_roles.isEmpty) {
      setState(() {
        _message = '角色数据为空，无法审批。';
      });
      return;
    }

    final formKey = GlobalKey<FormState>();
    final accountController = TextEditingController(text: item.account);
    final passwordController = TextEditingController();
    String? selectedRoleCode = _defaultRoleCode();
    int? selectedStageId;
    Set<String> selectedProcessCodes = <String>{};

    final approved = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = _isOperator(selectedRoleCode);
            return AlertDialog(
              title: const Text('通过注册申请并分配信息'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('申请账号：${item.account}'),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: accountController,
                          decoration: const InputDecoration(
                            labelText: '入库账号',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入入库账号';
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
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '初始密码',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入初始密码';
                            }
                            if (value.trim().length < 6) {
                              return '密码至少 6 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '角色分配（单选）',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
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
                    final success = await _approveRequest(
                      item: item,
                      account: accountController.text.trim(),
                      roleCode: selectedRoleCode!,
                      processCodes: orderedProcessCodes,
                      password: passwordController.text.trim(),
                      stageId: selectedStageId,
                    );
                    if (success && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('确认通过'),
                ),
              ],
            );
          },
        );
      },
    );

    accountController.dispose();
    passwordController.dispose();

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
    if (!widget.canReviewAction) {
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
      await _loadRequests();
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
    if (!widget.canReviewAction) {
      _showNoPermission();
      return;
    }
    final reasonController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('驳回注册申请'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('确认驳回账号”${item.account}”的注册申请吗？'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: '驳回原因（可选）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('驳回'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        final reason = reasonController.text.trim();
        await _rejectRequest(item, reason: reason.isEmpty ? null : reason);
      }
    } finally {
      reasonController.dispose();
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
                '注册审批',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading
                    ? null
                    : () => _loadInitialData(page: _requestPage),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('待审批数量：$_total', style: theme.textTheme.titleMedium),
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
                : _items.isEmpty
                ? const Center(child: Text('暂无待审批注册申请'))
                : Card(
                    child: SizedBox.expand(
                      child: Scrollbar(
                        controller: _requestListScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _requestListScrollController,
                          child: DataTable(
                            columnSpacing: 16,
                            headingRowColor: WidgetStateProperty.all(
                              theme.colorScheme.surfaceContainerHighest,
                            ),
                            columns: const [
                              DataColumn(label: Text('用户名')),
                              DataColumn(label: Text('申请时间')),
                              DataColumn(label: Text('申请状态')),
                              DataColumn(label: Text('操作')),
                            ],
                            rows: _items.map((item) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(item.account)),
                                  DataCell(Text(_formatTime(item.createdAt))),
                                  DataCell(
                                    Text(
                                      _statusLabel(item.status),
                                      style: TextStyle(
                                        color: _statusColor(item.status, theme),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (item.status == 'pending') ...[
                                          TextButton(
                                            onPressed: widget.canReviewAction
                                                ? () => _openApproveDialog(item)
                                                : null,
                                            child: const Text('通过'),
                                          ),
                                          TextButton(
                                            onPressed: widget.canReviewAction
                                                ? () => _confirmReject(item)
                                                : null,
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  theme.colorScheme.error,
                                            ),
                                            child: const Text('驳回'),
                                          ),
                                        ] else
                                          const Text(
                                            '-',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
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
          const SizedBox(height: 12),
          SimplePaginationBar(
            page: _requestPage,
            totalPages: _requestTotalPages,
            total: _total,
            loading: _loading,
            onPrevious: () => _loadRequests(page: _requestPage - 1),
            onNext: () => _loadRequests(page: _requestPage + 1),
          ),
        ],
      ),
    );
  }
}
