import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
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

Future<void> showUserEditDialog({
  required BuildContext context,
  required UserService userService,
  required UserItem user,
  required List<RoleItem> allRoles,
  required Future<List<CraftStageItem>> Function() loadEnabledStages,
  required Future<dynamic> Function(Future<dynamic> Function() action) runWithOnlineRefreshPaused,
  required List<RoleItem> Function({String? includeRoleCode}) assignableRoles,
  required bool Function() isCurrentUserSystemAdmin,
  required String Function(String?, String?) roleLabelForUser,
  required String Function(int?, String?) stageLabelForUser,
  required String Function(DateTime?) formatDialogDateTime,
  required VoidCallback onLogout,
  required Future<void> Function() onSuccess,
}) async {
    late final List<CraftStageItem> currentStages;
    var detailUser = user;
    String? detailWarning;
    try {
      final results = await runWithOnlineRefreshPaused(() async {
        return Future.wait<dynamic>([
          loadEnabledStages(),
          userService.getUserDetail(userId: user.id),
        ]);
      });
      currentStages = results[0] as List<CraftStageItem>;
      detailUser = results[1] as UserItem;
    } catch (error) {
      if (isUnauthorized(error)) {
        onLogout();
        return;
      }
      currentStages = await loadEnabledStages();
      detailWarning = '部分详情刷新失败，以下内容已回退为列表中的当前数据。';
    }
    if (!context.mounted) {
      return;
    }
    final roles = assignableRoles(
      includeRoleCode: detailUser.roleCode,
    );
    if (roles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有可分配的启用角色。')),
        );
      }
      return;
    }
    final accountController = TextEditingController(text: detailUser.username);
    final formKey = GlobalKey<FormState>();
    final canEditAccount = isCurrentUserSystemAdmin();
    final originalAccount = detailUser.username.trim();
    final originalRoleCode = detailUser.roleCode;
    final originalRoleName = roleLabelForUser(
      detailUser.roleCode,
      detailUser.roleName,
    );
    final originalStageId = detailUser.stageId;
    final originalStageName = stageLabelForUser(
      detailUser.stageId,
      detailUser.stageName,
    );
    final originalActive = detailUser.isActive;
    final originalMustChangePassword = detailUser.mustChangePassword;
    String? selectedRoleCode = detailUser.roleCode;
    int? selectedStageId = _canAssignStage(allRoles, selectedRoleCode)
        ? detailUser.stageId
        : null;
    bool isActive = detailUser.isActive;
    bool mustChangePassword = detailUser.mustChangePassword;

    final updated = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOperatorSelected = _isOperator(selectedRoleCode);
            final canAssignStage = _canAssignStage(allRoles, selectedRoleCode);
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
                              formatDialogDateTime(detailUser.lastLoginAt),
                            ),
                            buildInfoItem(
                              '最近改密时间',
                              formatDialogDateTime(
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
                            detailWarning,
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
                            children: roles.map((role) {
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
                    final updatedStageId = _canAssignStage(allRoles, updatedRoleCode)
                        ? selectedStageId
                        : null;
                    final updatedRoleName = roleLabelForUser(
                      updatedRoleCode,
                      null,
                    );
                    final updatedStageName = stageLabelForUser(
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
                      await userService.updateUser(
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
                      if (isUnauthorized(error)) {
                        onLogout();
                        return;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('更新用户失败：${(error is ApiException ? error.message : error.toString())}'),
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
      await onSuccess();
    }
}
