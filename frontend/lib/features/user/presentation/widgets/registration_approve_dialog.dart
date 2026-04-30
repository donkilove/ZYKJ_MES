import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';

class RegistrationApproveDialog extends StatefulWidget {
  const RegistrationApproveDialog({
    super.key,
    required this.item,
    required this.assignableRoles,
    required this.currentStages,
    required this.defaultRoleCode,
    required this.isOperator,
    required this.onApprove,
  });

  final RegistrationRequestItem item;
  final List<RoleItem> assignableRoles;
  final List<CraftStageItem> currentStages;
  final String? defaultRoleCode;
  final bool Function(String?) isOperator;
  final Future<bool> Function({
    required String account,
    required String roleCode,
    String? password,
    int? stageId,
  }) onApprove;

  @override
  State<RegistrationApproveDialog> createState() => _RegistrationApproveDialogState();
}

class _RegistrationApproveDialogState extends State<RegistrationApproveDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _accountController;
  final _passwordController = TextEditingController();
  String? _selectedRoleCode;
  int? _selectedStageId;
  bool _submitting = false;

  static const int _accountMaxLength = 10;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(text: widget.item.account);
    _selectedRoleCode = widget.defaultRoleCode;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedRoleCode == null) {
      return;
    }
    if (widget.isOperator(_selectedRoleCode) && _selectedStageId == null) {
      return;
    }

    setState(() => _submitting = true);
    final success = await widget.onApprove(
      account: _accountController.text.trim(),
      roleCode: _selectedRoleCode!,
      password: _passwordController.text.trim(),
      stageId: _selectedStageId,
    );
    if (mounted) {
      setState(() => _submitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOperatorSelected = widget.isOperator(_selectedRoleCode);
    final theme = Theme.of(context);

    return MesDialog(
      title: const Text('通过注册申请并分配信息'),
      width: 860,
      content: SizedBox(
        width: 860,
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：基础信息
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '申请账号信息',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(100)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '原始申请账号：${widget.item.account}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '入库设置',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accountController,
                      maxLength: _accountMaxLength,
                      readOnly: _submitting,
                      decoration: const InputDecoration(
                        labelText: '入库账号',
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return '请输入入库账号';
                        if (value.trim().length < 2) return '账号至少 2 个字符';
                        if (value.trim().length > _accountMaxLength) return '账号最多 $_accountMaxLength 个字符';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      readOnly: _submitting,
                      decoration: const InputDecoration(
                        labelText: '初始密码',
                        filled: true,
                        helperText: '密码规则：至少6位；不能包含连续4位相同字符。',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return '请输入初始密码';
                        if (value.trim().length < 6) return '密码至少 6 个字符';
                        if (RegExp(r'(.)\1\1\1').hasMatch(value.trim())) return '初始密码不能包含连续4位相同字符';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // 右侧：角色与工段分配
              Expanded(
                flex: 6,
                child: Container(
                  height: 480,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '角色分配（单选）',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.assignableRoles.map((role) {
                            final isSelected = _selectedRoleCode == role.code;
                            return ChoiceChip(
                              label: Text(role.name),
                              selected: isSelected,
                              onSelected: _submitting
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _selectedRoleCode = role.code;
                                        if (!widget.isOperator(_selectedRoleCode)) {
                                          _selectedStageId = null;
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                        if (_selectedRoleCode == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('请选择一个角色', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1),
                        ),
                        Text(
                          '工段分配（单选，仅操作员角色可选）',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Opacity(
                          opacity: isOperatorSelected ? 1 : 0.5,
                          child: IgnorePointer(
                            ignoring: !isOperatorSelected || _submitting,
                            child: widget.currentStages.isEmpty
                                ? const Text('暂无可分配工段')
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: widget.currentStages.map((stage) {
                                      return ChoiceChip(
                                        label: Text(stage.name),
                                        selected: _selectedStageId == stage.id,
                                        onSelected: (_) {
                                          setState(() => _selectedStageId = stage.id);
                                        },
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                        if (isOperatorSelected && _selectedStageId == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('操作员角色必须选择一个工段', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '处理中...' : '确认通过'),
        ),
      ],
    );
  }
}
