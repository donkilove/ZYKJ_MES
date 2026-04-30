import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/services/user_service.dart';

class RoleFormDialog extends StatefulWidget {
  const RoleFormDialog({
    super.key,
    required this.userService,
    this.role,
  });

  final UserService userService;
  final RoleItem? role;

  @override
  State<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedRoleType;
  late bool _selectedEnabled;
  bool _submitting = false;

  static const String _roleTypeBuiltin = 'builtin';
  static const String _roleTypeCustom = 'custom';
  static const String _maintenanceRoleCode = 'maintenance_staff';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.role?.name ?? '');
    _selectedRoleType = widget.role?.roleType == _roleTypeBuiltin
        ? _roleTypeBuiltin
        : _roleTypeCustom;
    _selectedEnabled = widget.role?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _isBuiltinSemanticsRole(RoleItem? role) {
    if (role == null) return false;
    return role.isBuiltin || role.code == _maintenanceRoleCode;
  }

  String _statusLabel(bool enabled) => enabled ? '启用' : '停用';

  String _generateImplicitRoleCode(String roleName) {
    final normalizedName = roleName.trim().toLowerCase();
    final buffer = StringBuffer('custom_');
    for (final rune in normalizedName.runes) {
      final char = String.fromCharCode(rune);
      final isLowerAlpha = rune >= 97 && rune <= 122;
      final isDigit = rune >= 48 && rune <= 57;
      if (isLowerAlpha || isDigit) {
        buffer.write(char);
        continue;
      }
      buffer.write(rune.toRadixString(16));
    }
    buffer.write('_');
    buffer.write(DateTime.now().millisecondsSinceEpoch.toRadixString(36));
    final generated = buffer.toString();
    if (generated.length <= 48) {
      return generated;
    }
    return generated.substring(generated.length - 48);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      if (widget.role == null) {
        await widget.userService.createRole(
          code: _generateImplicitRoleCode(_nameController.text),
          name: _nameController.text.trim(),
          roleType: _selectedRoleType,
          isEnabled: _selectedEnabled,
        );
      } else {
        await widget.userService.updateRole(
          roleId: widget.role!.id,
          name: _nameController.text.trim(),
          isEnabled: _selectedEnabled,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEditRoleType = widget.role == null;
    final editingExistingRole = widget.role != null;
    final hasBuiltinSemantics = _isBuiltinSemanticsRole(widget.role);
    final theme = Theme.of(context);

    return MesDialog(
      title: Text(widget.role == null ? '新增角色' : '编辑角色'),
      width: 720,
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：基本信息
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '基本信息',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      readOnly: hasBuiltinSemantics || _submitting,
                      decoration: const InputDecoration(
                        labelText: '角色名称',
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '角色名称不能为空';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRoleType,
                      decoration: const InputDecoration(
                        labelText: '角色类型',
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _roleTypeCustom,
                          child: Text('自定义'),
                        ),
                        if (_selectedRoleType == _roleTypeBuiltin)
                          const DropdownMenuItem(
                            value: _roleTypeBuiltin,
                            child: Text('系统内置'),
                          ),
                      ],
                      onChanged: canEditRoleType && !_submitting
                          ? (value) {
                              if (value != null) {
                                setState(() => _selectedRoleType = value);
                              }
                            }
                          : null,
                    ),
                    if (widget.role == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '新增角色仅支持自定义角色，系统内置角色由系统预置。',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // 右侧：状态与控制
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '状态与控制',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!editingExistingRole) ...[
                      Text('初始启停状态', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('启用'), icon: Icon(Icons.check_circle_outline)),
                          ButtonSegment(value: false, label: Text('停用'), icon: Icon(Icons.block)),
                        ],
                        selected: {_selectedEnabled},
                        onSelectionChanged: _submitting
                            ? null
                            : (set) => setState(() => _selectedEnabled = set.first),
                        showSelectedIcon: false,
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedEnabled ? Icons.check_circle : Icons.block,
                              color: _selectedEnabled ? Colors.green : theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '当前状态：${_statusLabel(_selectedEnabled)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        hasBuiltinSemantics
                            ? '系统内置角色仅禁止改名、删除；如需变更启停，请使用列表中的启停按钮。'
                            : '如需变更启停，请使用列表中的启停按钮。',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
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
          child: Text(_submitting ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}
