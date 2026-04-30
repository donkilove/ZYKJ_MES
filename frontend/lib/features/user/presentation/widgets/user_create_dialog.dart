import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/services/user_service.dart';

bool _isOperator(String? roleCode) => roleCode == 'operator';

RoleItem? _findRoleByCode(List<RoleItem> roles, String? roleCode) {
  if (roleCode == null) return null;
  for (final role in roles) {
    if (role.code == roleCode) return role;
  }
  return null;
}

bool _canAssignStage(List<RoleItem> roles, String? roleCode) {
  final role = _findRoleByCode(roles, roleCode);
  if (role == null) return _isOperator(roleCode);
  return _isOperator(roleCode) || role.roleType == 'custom' || !role.isBuiltin;
}

bool isUnauthorized(Object error) {
  return error is ApiException && error.statusCode == 401;
}

Future<void> showUserCreateDialog({
  required BuildContext context,
  required UserService userService,
  required List<RoleItem> assignableRoles,
  required List<RoleItem> allRoles,
  required Future<List<CraftStageItem>> Function() loadEnabledStages,
  required VoidCallback onLogout,
  required Future<void> Function() onSuccess,
}) async {
    final currentStages = await loadEnabledStages();
    if (!context.mounted) {
      return;
    }
    if (assignableRoles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有可分配的启用角色。')),
        );
      }
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
        final result = await userService.listUsers(
          page: 1,
          pageSize: 20,
          keyword: account,
        );
        if (!context.mounted || currentSequence != accountCheckSequence) {
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
        if (isUnauthorized(error)) {
          onLogout();
          return;
        }
        if (!context.mounted || currentSequence != accountCheckSequence) {
          return;
        }
        setDialogState(() {
          checkingAccountConflict = false;
          accountConflictError = null;
        });
      }
    }

    final created = await showMesLockedFormDialog<bool>(
      context: context,
      wrapMesDialog: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = _isOperator(selectedRoleCode);
            final canAssignStage = _canAssignStage(allRoles, selectedRoleCode);
            final stageHelperText = selectedRoleCode == null
                ? '请先选择角色，再确定是否需要分配工段'
                : isOperatorSelected
                ? '操作员必须选择一个工段后才能创建'
                : canAssignStage
                ? '当前角色可选工段，不选则默认无工段'
                : '该角色无需分配工段';

            return MesDialog(
              title: const Text('新建用户'),
              width: 860,
              content: SizedBox(
                width: 860,
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
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
                            TextFormField(
                              controller: accountController,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: '账号',
                                filled: true,
                                border: const OutlineInputBorder(),
                                helperText: checkingAccountConflict
                                    ? '正在检查账号是否可用...'
                                    : null,
                                suffixIcon: checkingAccountConflict
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                              ),
                              onChanged: (_) {
                                setDialogState(() => accountConflictError = null);
                                checkAccountConflict(setDialogState);
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return '请输入账号';
                                if (value.trim().length < 2) return '账号至少 2 个字符';
                                if (value.trim().length > 10) return '账号最多 10 个字符';
                                if (accountConflictError != null) return accountConflictError;
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: const InputDecoration(
                                labelText: '密码',
                                filled: true,
                                border: OutlineInputBorder(),
                                helperText: '密码规则：至少6位；不能包含连续4位相同字符。',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return '请输入密码';
                                if (value.length < 6) return '密码至少 6 个字符';
                                if (RegExp(r'(.)\1\1\1').hasMatch(value)) return '密码不能包含连续4位相同字符';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Text('账号状态', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: true, label: Text('启用'), icon: Icon(Icons.check_circle_outline)),
                                ButtonSegment(value: false, label: Text('停用'), icon: Icon(Icons.block)),
                              ],
                              selected: {isActive},
                              onSelectionChanged: (set) {
                                setDialogState(() => isActive = set.first);
                              },
                              showSelectedIcon: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      // 右侧：角色与工段分配
                      Expanded(
                        flex: 6,
                        child: Container(
                          height: 420,
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '角色分配（单选）',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                if (assignableRoles.isEmpty)
                                  const Text('无可分配角色', style: TextStyle(color: Colors.red))
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: assignableRoles.map((role) {
                                      final isSelected = selectedRoleCode == role.code;
                                      return ChoiceChip(
                                        label: Text(role.name),
                                        selected: isSelected,
                                        onSelected: (_) {
                                          setDialogState(() {
                                            selectedRoleCode = role.code;
                                            if (!_isOperator(selectedRoleCode)) {
                                              selectedStageId = null;
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                if (selectedRoleCode == null)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text('请选择一个角色', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(height: 1),
                                ),
                                Text(
                                  '工段分配（单选，操作员必选，自定义角色可选）',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  stageHelperText,
                                  style: TextStyle(
                                    color: isOperatorSelected ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Opacity(
                                  opacity: canAssignStage ? 1 : 0.5,
                                  child: IgnorePointer(
                                    ignoring: !canAssignStage,
                                    child: currentStages.isEmpty
                                        ? const Text('暂无可分配工段')
                                        : Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: currentStages.map((stage) {
                                              return ChoiceChip(
                                                label: Text(stage.name),
                                                selected: selectedStageId == stage.id,
                                                onSelected: (_) {
                                                  setDialogState(() => selectedStageId = stage.id);
                                                },
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ),
                                if (isOperatorSelected && selectedStageId == null)
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
                      await userService.createUser(
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
                      if (isUnauthorized(error)) {
                        onLogout();
                        return;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('创建用户失败：${(error is ApiException ? error.message : error.toString())}'),
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
      await onSuccess();
      if (context.mounted && createdAccount != null) {
        final followup = createdActive
            ? '用户 $createdAccount 已创建，首次登录需修改密码。'
            : '用户 $createdAccount 已创建，首次登录需修改密码；当前为停用状态，启用后方可登录。';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(followup)));
      }
    }
}
