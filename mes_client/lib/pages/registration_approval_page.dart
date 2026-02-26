import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';

class RegistrationApprovalPage extends StatefulWidget {
  const RegistrationApprovalPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<RegistrationApprovalPage> createState() =>
      _RegistrationApprovalPageState();
}

class _RegistrationApprovalPageState extends State<RegistrationApprovalPage> {
  static const String _operatorRoleCode = 'operator';

  late final UserService _userService;

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<RegistrationRequestItem> _items = const [];
  List<RoleItem> _roles = const [];
  List<ProcessItem> _processes = const [];

  @override
  void initState() {
    super.initState();
    _userService = UserService(widget.session);
    _loadInitialData();
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

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
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

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await Future.wait<dynamic>([
        _userService.listRegistrationRequests(page: 1, pageSize: 100),
        _userService.listRoles(),
        _userService.listProcesses(),
      ]);
      final requests = result[0] as RegistrationRequestListResult;
      final roles = result[1] as RoleListResult;
      final processes = result[2] as ProcessListResult;

      if (!mounted) {
        return;
      }
      setState(() {
        _items = requests.items;
        _total = requests.total;
        _roles = roles.items;
        _processes = processes.items;
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

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await _userService.listRegistrationRequests(
        page: 1,
        pageSize: 100,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = result.items;
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
    required String? processCode,
  }) async {
    try {
      await _userService.approveRegistrationRequest(
        requestId: item.id,
        account: account,
        roleCodes: [roleCode],
        processCodes: processCode == null ? const [] : [processCode],
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
    if (_roles.isEmpty) {
      setState(() {
        _message = '角色数据为空，无法审批。';
      });
      return;
    }

    final formKey = GlobalKey<FormState>();
    final accountController = TextEditingController(text: item.account);
    String? selectedRoleCode = _defaultRoleCode();
    String? selectedProcessCode;

    final approved = await showDialog<bool>(
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
                            if (value.trim().length < 3) {
                              return '账号至少 3 个字符';
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
                    final success = await _approveRequest(
                      item: item,
                      account: accountController.text.trim(),
                      roleCode: selectedRoleCode!,
                      processCode: selectedProcessCode,
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

    if (approved == true && mounted) {
      setState(() {
        _message = '';
      });
    }
  }

  Future<void> _rejectRequest(RegistrationRequestItem item) async {
    try {
      await _userService.rejectRegistrationRequest(requestId: item.id);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('驳回注册申请'),
          content: Text('确认驳回账号“${item.account}”的注册申请吗？'),
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
      await _rejectRequest(item);
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
                onPressed: _loading ? null : _loadInitialData,
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
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          title: Text(item.account),
                          subtitle: Text('提交时间：${_formatTime(item.createdAt)}'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _openApproveDialog(item),
                                child: const Text('通过'),
                              ),
                              TextButton(
                                onPressed: () => _confirmReject(item),
                                child: const Text('驳回'),
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
