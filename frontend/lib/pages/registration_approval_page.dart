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
    required this.canApprove,
    required this.canReject,
    this.userService,
    this.craftService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canApprove;
  final bool canReject;
  final UserService? userService;
  final CraftService? craftService;

  @override
  State<RegistrationApprovalPage> createState() =>
      _RegistrationApprovalPageState();
}

class _RegistrationApprovalPageState extends State<RegistrationApprovalPage> {
  static const String _operatorRoleCode = 'operator';
  static const int _requestPageSize = 100;
  static const int _accountMaxLength = 10;

  late final UserService _userService;
  late final CraftService _craftService;
  final ScrollController _requestListScrollController = ScrollController();
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<RegistrationRequestItem> _items = const [];
  List<RoleItem> _roles = const [];
  List<CraftStageItem> _stages = const [];
  int _requestPage = 1;
  String? _statusFilter = 'pending';

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
    _loadInitialData();
  }

  @override
  void dispose() {
    _requestListScrollController.dispose();
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
          keyword: _keywordController.text.trim().isEmpty
              ? null
              : _keywordController.text.trim(),
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
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
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

    final formKey = GlobalKey<FormState>();
    final accountController = TextEditingController(text: item.account);
    final passwordController = TextEditingController();
    String? selectedRoleCode = _defaultRoleCode();
    int? selectedStageId;

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
                          maxLength: _accountMaxLength,
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
                            if (value.trim().length > _accountMaxLength) {
                              return '账号最多 $_accountMaxLength 个字符';
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
                    final success = await _approveRequest(
                      item: item,
                      account: accountController.text.trim(),
                      roleCode: selectedRoleCode!,
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
    if (!widget.canReject) {
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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '按用户名搜索',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadRequests(page: 1),
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: '申请状态',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('全部')),
                    DropdownMenuItem<String?>(
                      value: 'pending',
                      child: Text('待审批'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'approved',
                      child: Text('已通过'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'rejected',
                      child: Text('已驳回'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _loadRequests(page: 1);
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : () => _loadRequests(page: 1),
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('当前列表总数：$_total', style: theme.textTheme.titleMedium),
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
                ? Center(
                    child: Text(
                      _statusFilter == null ? '暂无注册申请记录' : '当前状态下暂无注册申请记录',
                    ),
                  )
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
                              DataColumn(label: Text('驳回原因')),
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
                                  DataCell(Text(item.rejectedReason ?? '-')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (item.status == 'pending') ...[
                                          if (widget.canApprove)
                                            TextButton(
                                              onPressed: () =>
                                                  _openApproveDialog(item),
                                              child: const Text('通过'),
                                            ),
                                          if (widget.canReject)
                                            TextButton(
                                              onPressed: () =>
                                                  _confirmReject(item),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    theme.colorScheme.error,
                                              ),
                                              child: const Text('驳回'),
                                            ),
                                          if (!widget.canApprove &&
                                              !widget.canReject)
                                            const Text(
                                              '-',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
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
