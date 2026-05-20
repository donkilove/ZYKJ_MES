import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionApplyAssistDialogResult {
  const ProductionApplyAssistDialogResult({
    required this.targetOperatorUserId,
    required this.helperUserId,
    required this.reason,
  });

  final int targetOperatorUserId;
  final int helperUserId;
  final String? reason;
}

Future<ProductionApplyAssistDialogResult?> showProductionApplyAssistDialog({
  required BuildContext context,
  required MyOrderItem order,
  required List<AssistUserOptionItem> targetOperators,
  required List<AssistUserOptionItem> assistUsers,
}) {
  return showMesLockedFormDialog<ProductionApplyAssistDialogResult?>(
    context: context,
    wrapMesDialog: false,
    builder: (_) {
      return ProductionApplyAssistDialog(
        order: order,
        targetOperators: targetOperators,
        assistUsers: assistUsers,
      );
    },
  );
}

class ProductionApplyAssistDialog extends StatefulWidget {
  const ProductionApplyAssistDialog({
    super.key,
    required this.order,
    required this.targetOperators,
    required this.assistUsers,
  });

  final MyOrderItem order;
  final List<AssistUserOptionItem> targetOperators;
  final List<AssistUserOptionItem> assistUsers;

  @override
  State<ProductionApplyAssistDialog> createState() =>
      _ProductionApplyAssistDialogState();
}

class _ProductionApplyAssistDialogState
    extends State<ProductionApplyAssistDialog> {
  static const String _operatorRoleCode = 'operator';

  late final int? _targetOperatorUserId;
  late final AssistUserOptionItem? _targetOperator;

  late String? _helperRoleCode;
  int? _helperStageId;
  int? _helperUserId;

  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _targetOperatorUserId = widget.order.operatorUserId;
    _targetOperator = widget.targetOperators
        .cast<AssistUserOptionItem?>()
        .firstWhere(
          (item) => item?.id == _targetOperatorUserId,
          orElse: () {
            if (_targetOperatorUserId == null) {
              return null;
            }
            final targetOperatorUserId = _targetOperatorUserId;
            return AssistUserOptionItem(
              id: targetOperatorUserId,
              username: (widget.order.operatorUsername ?? '').trim().isEmpty
                  ? 'operator_${widget.order.operatorUserId}'
                  : widget.order.operatorUsername!,
              fullName: null,
              roleCodes: const ['operator'],
              stageId: widget.order.currentStageId,
              stageName: widget.order.currentStageName,
            );
          },
        );

    final initialSelection = _resolveSelection(
      preferredRoleCode: _defaultRoleCode(_roleOptions(widget.assistUsers)),
      preferredStageId: widget.order.currentStageId,
      preferredUserId: null,
    );
    _helperRoleCode = initialSelection.roleCode;
    _helperStageId = initialSelection.stageId;
    _helperUserId = initialSelection.userId;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_targetOperatorUserId == null || _helperUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择代班人')));
      return;
    }
    final targetOperatorUserId = _targetOperatorUserId;
    final reason = _reasonController.text.trim();
    Navigator.of(context).pop(
      ProductionApplyAssistDialogResult(
        targetOperatorUserId: targetOperatorUserId,
        helperUserId: _helperUserId!,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }

  List<String> _roleOptions(List<AssistUserOptionItem> users) {
    final seen = <String>{};
    final options = <String>[];
    for (final user in users) {
      for (final roleCode in user.roleCodes) {
        final normalized = roleCode.trim();
        if (normalized.isEmpty || !seen.add(normalized)) {
          continue;
        }
        options.add(normalized);
      }
    }
    options.sort((a, b) => _roleSortWeight(a).compareTo(_roleSortWeight(b)));
    return options;
  }

  int _roleSortWeight(String code) {
    switch (code) {
      case _operatorRoleCode:
        return 0;
      case 'production_admin':
        return 1;
      case 'system_admin':
        return 2;
      default:
        return 100 + code.codeUnitAt(0);
    }
  }

  String? _defaultRoleCode(List<String> roleOptions) {
    if (roleOptions.contains(_operatorRoleCode)) {
      return _operatorRoleCode;
    }
    if (roleOptions.isEmpty) {
      return null;
    }
    return roleOptions.first;
  }

  String _roleLabel(String roleCode) {
    switch (roleCode) {
      case _operatorRoleCode:
        return '操作员';
      case 'production_admin':
        return '生产管理员';
      case 'system_admin':
        return '系统管理员';
      default:
        return roleCode;
    }
  }

  List<_AssistStageOption> _stageOptionsForRole({
    required List<AssistUserOptionItem> users,
    required String? roleCode,
  }) {
    if (roleCode != _operatorRoleCode) {
      return const [];
    }
    final optionsById = <int, _AssistStageOption>{};
    for (final user in users) {
      if (!user.roleCodes.contains(_operatorRoleCode) || user.stageId == null) {
        continue;
      }
      if (_isCurrentOrderStage(user.stageId)) {
        continue;
      }
      optionsById.putIfAbsent(
        user.stageId!,
        () => _AssistStageOption(
          id: user.stageId!,
          name: (user.stageName ?? '').trim().isEmpty
              ? '工段 ${user.stageId}'
              : user.stageName!.trim(),
        ),
      );
    }
    final options = optionsById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return options;
  }

  int? _resolveInitialStageId({
    required List<AssistUserOptionItem> users,
    required int? preferredStageId,
    required String? roleCode,
  }) {
    final stageOptions = _stageOptionsForRole(users: users, roleCode: roleCode);
    if (stageOptions.isEmpty) {
      return null;
    }
    if (preferredStageId != null &&
        stageOptions.any((item) => item.id == preferredStageId)) {
      return preferredStageId;
    }
    return stageOptions.first.id;
  }

  List<AssistUserOptionItem> _helperUsersForSelection() {
    return widget.assistUsers.where((user) {
      if (_targetOperatorUserId != null && user.id == _targetOperatorUserId) {
        return false;
      }
      if (_helperRoleCode == null ||
          !user.roleCodes.contains(_helperRoleCode)) {
        return false;
      }
      if (_helperRoleCode == _operatorRoleCode) {
        if (_isCurrentOrderStage(user.stageId)) {
          return false;
        }
        return _helperStageId != null && user.stageId == _helperStageId;
      }
      return true;
    }).toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  int? _resolveInitialHelperUserId(int? preferredUserId) {
    final filtered = _helperUsersForSelection();
    if (preferredUserId != null &&
        filtered.any((user) => user.id == preferredUserId)) {
      return preferredUserId;
    }
    return null;
  }

  bool _isCurrentOrderStage(int? stageId) {
    final currentStageId = widget.order.currentStageId;
    return stageId != null &&
        currentStageId != null &&
        stageId == currentStageId;
  }

  _AssistSelection _resolveSelection({
    String? preferredRoleCode,
    int? preferredStageId,
    int? preferredUserId,
  }) {
    final roleOptions = _roleOptions(widget.assistUsers);
    final orderedRoles = <String>[
      if (preferredRoleCode != null && roleOptions.contains(preferredRoleCode))
        preferredRoleCode,
      ...roleOptions.where((code) => code != preferredRoleCode),
    ];
    if (orderedRoles.isEmpty) {
      return const _AssistSelection(roleCode: null, stageId: null, userId: null);
    }
    for (final roleCode in orderedRoles) {
      if (roleCode == _operatorRoleCode) {
        final stageOptions = _stageOptionsForRole(
          users: widget.assistUsers,
          roleCode: roleCode,
        );
        if (stageOptions.isEmpty) {
          continue;
        }
        final resolvedStageId =
            preferredStageId != null &&
                stageOptions.any((item) => item.id == preferredStageId)
            ? preferredStageId
            : stageOptions.first.id;
        final users = _helperUsersFor(roleCode: roleCode, stageId: resolvedStageId);
        if (users.isEmpty) {
          continue;
        }
        final resolvedUserId =
            preferredUserId != null && users.any((item) => item.id == preferredUserId)
            ? preferredUserId
            : null;
        return _AssistSelection(
          roleCode: roleCode,
          stageId: resolvedStageId,
          userId: resolvedUserId,
        );
      }
      final users = _helperUsersFor(roleCode: roleCode, stageId: null);
      if (users.isEmpty) {
        continue;
      }
      final resolvedUserId =
          preferredUserId != null && users.any((item) => item.id == preferredUserId)
          ? preferredUserId
          : null;
      return _AssistSelection(
        roleCode: roleCode,
        stageId: null,
        userId: resolvedUserId,
      );
    }
    return _AssistSelection(
      roleCode: orderedRoles.first,
      stageId: orderedRoles.first == _operatorRoleCode
          ? _resolveInitialStageId(
              users: widget.assistUsers,
              preferredStageId: preferredStageId,
              roleCode: orderedRoles.first,
            )
          : null,
      userId: null,
    );
  }

  List<AssistUserOptionItem> _helperUsersFor({
    required String roleCode,
    required int? stageId,
  }) {
    return widget.assistUsers.where((user) {
      if (_targetOperatorUserId != null && user.id == _targetOperatorUserId) {
        return false;
      }
      if (!user.roleCodes.contains(roleCode)) {
        return false;
      }
      if (roleCode == _operatorRoleCode) {
        if (_isCurrentOrderStage(user.stageId)) {
          return false;
        }
        return stageId != null && user.stageId == stageId;
      }
      return true;
    }).toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  void _onHelperRoleChanged(String? roleCode) {
    final selection = _resolveSelection(
      preferredRoleCode: roleCode,
      preferredStageId: _helperStageId ?? widget.order.currentStageId,
      preferredUserId: _helperUserId,
    );
    setState(() {
      _helperRoleCode = selection.roleCode;
      _helperStageId = selection.stageId;
      _helperUserId = selection.userId;
    });
  }

  void _onHelperStageChanged(int? stageId) {
    final preferredUserId = _helperUserId;
    setState(() {
      _helperStageId = stageId;
      _helperUserId = _resolveInitialHelperUserId(preferredUserId);
    });
  }

  String _displayText(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return '-';
    }
    return normalized;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _workViewLabel(String value) {
    switch (value) {
      case 'assist':
        return '代班工单';
      case 'proxy':
        return '代理视角';
      case 'own':
      default:
        return '我的工单';
    }
  }

  Widget _buildReadOnlyInfo({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            '$label：',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildOrderInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '订单信息',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: _buildReadOnlyInfo(
                  label: '订单号',
                  value: widget.order.orderCode,
                ),
              ),
              SizedBox(
                width: 220,
                child: _buildReadOnlyInfo(
                  label: '产品',
                  value: widget.order.productName,
                ),
              ),
              SizedBox(
                width: 220,
                child: _buildReadOnlyInfo(
                  label: '供应商',
                  value: _displayText(widget.order.supplierName),
                ),
              ),
              SizedBox(
                width: 220,
                child: _buildReadOnlyInfo(
                  label: '数量',
                  value: '${widget.order.quantity}',
                ),
              ),
              SizedBox(
                width: 220,
                child: _buildReadOnlyInfo(
                  label: '订单状态',
                  value: productionOrderStatusLabel(widget.order.orderStatus),
                ),
              ),
              SizedBox(
                width: 220,
                child: _buildReadOnlyInfo(
                  label: '当前工序',
                  value: widget.order.currentProcessName,
                ),
              ),
              SizedBox(
                width: 220,
                child: _buildReadOnlyInfo(
                  label: '工单视角',
                  value: _workViewLabel(widget.order.workView),
                ),
              ),
              SizedBox(
                width: 220,
                child: _buildReadOnlyInfo(
                  label: '交期',
                  value: _formatDate(widget.order.dueDate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final helperRoleOptions = _roleOptions(widget.assistUsers);
    final helperStageOptions = _stageOptionsForRole(
      users: widget.assistUsers,
      roleCode: _helperRoleCode,
    );
    final helperUsers = _helperUsersForSelection();
    final hasAvailableHelper = helperUsers.isNotEmpty;
    final helperHintText = _helperRoleCode == _operatorRoleCode &&
            helperStageOptions.isEmpty
        ? '本工段操作员无需发起代班'
        : '暂无可选代班人';
    final targetDisplay = _targetOperator?.displayName ?? '未识别目标操作员';
    final targetStageDisplay =
        (_targetOperator?.stageName ?? widget.order.currentStageName ?? '')
            .trim()
            .isEmpty
        ? '-'
        : (_targetOperator?.stageName ?? widget.order.currentStageName)!;

    return MesDialog(
      title: const Text('发起代班'),
      width: 860,
      scrollable: true,
      content: SizedBox(
        key: const ValueKey('production-apply-assist-dialog'),
        width: 860,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOrderInfoCard(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '代班安排',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyInfo(label: '目标对象', value: targetDisplay),
                        const SizedBox(height: 8),
                        _buildReadOnlyInfo(
                          label: '当前工段',
                          value: targetStageDisplay,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _helperRoleCode,
                          decoration: const InputDecoration(
                            labelText: '代班角色',
                            border: OutlineInputBorder(),
                          ),
                          items: helperRoleOptions
                              .map(
                                (roleCode) => DropdownMenuItem<String>(
                                  value: roleCode,
                                  child: Text(_roleLabel(roleCode)),
                                ),
                              )
                              .toList(),
                          onChanged: _onHelperRoleChanged,
                        ),
                        if (_helperRoleCode == _operatorRoleCode) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: _helperStageId,
                            decoration: const InputDecoration(
                              labelText: '代班工段',
                              border: OutlineInputBorder(),
                            ),
                            items: helperStageOptions
                                .map(
                                  (stage) => DropdownMenuItem<int>(
                                    value: stage.id,
                                    child: Text(
                                      stage.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: helperStageOptions.isEmpty
                                ? null
                                : _onHelperStageChanged,
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _helperUserId,
                          decoration: InputDecoration(
                            labelText: '代班人',
                            border: const OutlineInputBorder(),
                            helperText: hasAvailableHelper ? null : helperHintText,
                          ),
                          items: helperUsers
                              .map(
                                (user) => DropdownMenuItem<int>(
                                  value: user.id,
                                  child: Text(
                                    user.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          selectedItemBuilder: (context) => helperUsers
                              .map(
                                (user) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    user.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: helperUsers.isEmpty
                              ? null
                              : (value) =>
                                    setState(() => _helperUserId = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '补充说明',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reasonController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '代班原因（可选）',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '提交后会立即为当前工序建立代班授权。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: hasAvailableHelper ? _submit : null,
          child: const Text('发起代班'),
        ),
      ],
    );
  }
}

class _AssistSelection {
  const _AssistSelection({
    required this.roleCode,
    required this.stageId,
    required this.userId,
  });

  final String? roleCode;
  final int? stageId;
  final int? userId;
}

class _AssistStageOption {
  const _AssistStageOption({required this.id, required this.name});

  final int id;
  final String name;
}
