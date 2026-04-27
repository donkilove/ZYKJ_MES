import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/services/user_service.dart';

String _formatPasswordResetSuccessMessage(UserPasswordResetResult result) {
  final forcedOfflineCount = result.forcedOfflineSessionCount;
  if (forcedOfflineCount > 0) {
    return '用户 ${result.user.username} 密码已重置，并强制下线 $forcedOfflineCount 个会话。';
  }
  if (result.clearedOnlineStatus) {
    return '用户 ${result.user.username} 密码已重置，在线状态已清除。';
  }
  return '用户 ${result.user.username} 密码已重置。';
}

Future<void> showUserResetPasswordDialog({
  required BuildContext context,
  required UserItem user,
  required String roleLabel,
  required UserService userService,
  required VoidCallback onLogout,
  required Future<void> Function() onSuccess,
}) async {
  final passwordController = TextEditingController();
  final remarkController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var submitting = false;

  final confirmed = await showMesLockedFormDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return MesDialog(
            title: Text('重置密码：${user.username}'),
            width: 460,
            content: Form(
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
                  Text('目标账号：${user.username}'),
                  const SizedBox(height: 4),
                  Text('角色：$roleLabel'),
                  const SizedBox(height: 4),
                  Text('当前账号状态：${user.isActive ? '启用' : '停用'}'),
                  const SizedBox(height: 4),
                  Text('当前在线状态：${user.isOnline ? '在线' : '离线'}'),
                  const SizedBox(height: 12),
                  Text(
                    '风险提示：旧密码会立即失效；当前在线会话将被强制下线；下次登录必须修改密码。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    enabled: !submitting,
                    decoration: const InputDecoration(
                      labelText: '新密码',
                      helperText: '密码规则：至少6位；不能包含连续4位相同字符。',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return '请输入新密码';
                      if (value.length < 6) return '密码至少 6 个字符';
                      if (RegExp(r'(.)\1\1\1').hasMatch(value)) {
                        return '新密码不能包含连续4位相同字符';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: remarkController,
                    enabled: !submitting,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '重置原因',
                      hintText: '请输入本次重置密码的原因',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入重置原因';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => submitting = true);
                        try {
                          final result = await userService.resetUserPassword(
                            userId: user.id,
                            password: passwordController.text,
                            remark: remarkController.text,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.of(dialogContext).pop(true);

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _formatPasswordResetSuccessMessage(result),
                              ),
                            ),
                          );
                          await onSuccess();
                        } catch (error) {
                          if (!dialogContext.mounted) {
                            return;
                          }
                          setDialogState(() => submitting = false);
                          if (error is ApiException && error.statusCode == 401) {
                            onLogout();
                            return;
                          }
                          if (!context.mounted) {
                            return;
                          }
                          final msg = error is ApiException ? error.message : error.toString();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('重置密码失败：$msg'),
                            ),
                          );
                        }
                      },
                child: Text(submitting ? '重置中...' : '确认重置'),
              ),
            ],
          );
        },
      );
    },
  );
  if (confirmed == true) {
    return;
  }
}
