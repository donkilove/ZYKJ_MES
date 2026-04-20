import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/locked_form_dialog.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/services/user_service.dart';

String formatLifecycleSuccessMessage(
  UserLifecycleResult result, {
  required bool active,
}) {
  if (active) {
    return '用户 ${result.user.username} 已启用，需重新登录后才会恢复在线状态。';
  }
  final forcedOfflineCount = result.forcedOfflineSessionCount;
  if (forcedOfflineCount > 0) {
    return '用户 ${result.user.username} 已停用，并强制下线 $forcedOfflineCount 个会话。';
  }
  if (result.clearedOnlineStatus) {
    return '用户 ${result.user.username} 已停用，在线状态已清除。';
  }
  return '用户 ${result.user.username} 已停用。';
}

String formatDeleteSuccessMessage(UserDeleteResult result) {
  final forcedOfflineCount = result.forcedOfflineSessionCount;
  if (forcedOfflineCount > 0) {
    return '已逻辑删除用户 ${result.user.username}，并强制下线 $forcedOfflineCount 个会话；用户已移入已删除视图。';
  }
  return '已逻辑删除用户 ${result.user.username}；用户已移入已删除视图。';
}

String formatRestoreSuccessMessage(UserLifecycleResult result) {
  return '用户 ${result.user.username} 已恢复到常规列表，当前保持停用状态。';
}

Future<void> showConfirmDeleteUserDialog({
  required BuildContext context,
  required UserService userService,
  required UserItem user,
  required String roleLabel,
  required String stageLabel,
  required void Function(dynamic error) onError,
  required Future<void> Function(UserDeleteResult result) onSuccess,
}) async {
  final remarkController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var submitting = false;
  final confirmed = await showLockedFormDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: const Text('逻辑删除用户'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '影响摘要',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('目标账号：${user.username}'),
                    const SizedBox(height: 4),
                    Text('当前在线状态：${user.isOnline ? '在线' : '离线'}'),
                    const SizedBox(height: 4),
                    Text('当前角色：$roleLabel'),
                    const SizedBox(height: 4),
                    Text('当前工段：$stageLabel'),
                    const SizedBox(height: 12),
                    Text(
                      '删除后用户会被停用、从常规列表隐藏，且数据仍保留，可在已删除视图中恢复。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.isOnline ? '提交后将强制下线当前会话。' : '删除后账号不可登录，需恢复后重新管理。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: user.isOnline ? theme.colorScheme.error : null,
                        fontWeight: user.isOnline
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: remarkController,
                      enabled: !submitting,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '删除原因',
                        hintText: '请输入逻辑删除原因',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入删除原因';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
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
                    : () {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        setDialogState(() => submitting = true);
                        Navigator.of(context).pop(true);
                      },
                child: Text(submitting ? '删除中...' : '确认删除'),
              ),
            ],
          );
        },
      );
    },
  );
  final remark = remarkController.text.trim();

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    final result = await userService.deleteUser(
      userId: user.id,
      remark: remark,
    );
    await onSuccess(result);
  } catch (error) {
    onError(error);
  }
}

Future<void> showConfirmRestoreUserDialog({
  required BuildContext context,
  required UserService userService,
  required UserItem user,
  required String roleLabel,
  required String stageLabel,
  required void Function(dynamic error) onError,
  required Future<void> Function(UserLifecycleResult result) onSuccess,
}) async {
  final remarkController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var submitting = false;

  final confirmed = await showLockedFormDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: const Text('恢复用户'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '恢复后用户会回到常规列表，但默认保持停用状态，需要管理员显式启用后才可再次登录。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('目标账号：${user.username}'),
                    const SizedBox(height: 4),
                    Text('当前角色：$roleLabel'),
                    const SizedBox(height: 4),
                    Text('当前工段：$stageLabel'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: remarkController,
                      enabled: !submitting,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '恢复原因',
                        hintText: '请输入恢复原因',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入恢复原因';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
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
                    : () {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        setDialogState(() => submitting = true);
                        Navigator.of(context).pop(true);
                      },
                child: Text(submitting ? '恢复中...' : '确认恢复'),
              ),
            ],
          );
        },
      );
    },
  );
  final remark = remarkController.text.trim();
  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    final result = await userService.restoreUser(
      userId: user.id,
      remark: remark,
    );
    await onSuccess(result);
  } catch (error) {
    onError(error);
  }
}

Future<void> showToggleUserActiveDialog({
  required BuildContext context,
  required UserService userService,
  required UserItem user,
  required bool active,
  required String roleLabel,
  required int? myUserId,
  required VoidCallback onLogout,
  required void Function(dynamic error) onError,
  required Future<void> Function(UserLifecycleResult result) onSuccess,
}) async {
  final actionLabel = active ? '启用' : '停用';
  final remarkController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var submitting = false;

  final confirmed = await showLockedFormDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final statusLabel = user.isActive ? '启用' : '停用';
          final onlineLabel = user.isOnline ? '在线' : '离线';
          final helperText = active
              ? '启用后账号可重新登录，但不会自动恢复在线状态。'
              : '停用后账号将无法继续登录，系统会强制下线该用户所有活跃会话。';
          return AlertDialog(
            title: Text('$actionLabel用户'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '目标账号：${user.username}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('当前角色：$roleLabel'),
                    const SizedBox(height: 4),
                    Text('当前账号状态：$statusLabel'),
                    const SizedBox(height: 4),
                    Text('当前在线状态：$onlineLabel'),
                    const SizedBox(height: 12),
                    Text(
                      helperText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: !active ? theme.colorScheme.error : null,
                        fontWeight: !active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: remarkController,
                      enabled: !submitting,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: active ? '备注（可选）' : '停用原因',
                        hintText: active ? '可填写启用说明' : '请输入停用原因',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!active &&
                            (value == null || value.trim().isEmpty)) {
                          return '请输入停用原因';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
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
                    : () {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        setDialogState(() => submitting = true);
                        Navigator.of(context).pop(true);
                      },
                child: Text(submitting ? '$actionLabel中...' : actionLabel),
              ),
            ],
          );
        },
      );
    },
  );
  final remark = remarkController.text.trim();
  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    late final UserLifecycleResult result;
    if (active) {
      result = await userService.enableUser(
        userId: user.id,
        remark: remark.isEmpty ? null : remark,
      );
    } else {
      result = await userService.disableUser(userId: user.id, remark: remark);
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(formatLifecycleSuccessMessage(result, active: active)),
      ),
    );
    await onSuccess(result);
    if (!active && myUserId != null && user.id == myUserId) {
      onLogout();
    }
  } catch (error) {
    onError(error);
  }
}
