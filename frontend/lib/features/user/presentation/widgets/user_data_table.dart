import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/user/models/user_models.dart';

enum UserTableAction { edit, disable, enable, resetPassword, delete, restore }

class UserDataTable extends StatelessWidget {
  final List<UserItem> users;
  final bool loading;
  final String emptyText;

  final bool canEditUser;
  final bool canToggleUser;
  final bool canResetPassword;
  final bool canDeleteUser;
  final bool canRestoreUser;
  final int? myUserId;

  final void Function(UserTableAction action, UserItem user) onAction;

  const UserDataTable({
    super.key,
    required this.users,
    required this.loading,
    required this.emptyText,
    required this.canEditUser,
    required this.canToggleUser,
    required this.canResetPassword,
    required this.canDeleteUser,
    required this.canRestoreUser,
    required this.myUserId,
    required this.onAction,
  });

  bool _isCurrentLoginUser(UserItem user) =>
      myUserId != null && user.id == myUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CrudListTableSection(
      key: const ValueKey('userListSection'),
      cardKey: const ValueKey('userListCard'),
      loading: loading,
      isEmpty: users.isEmpty,
      emptyText: emptyText,
      enableUnifiedHeaderStyle: true,
      child: DataTable(
        columnSpacing: 16,
        columns: [
          UnifiedListTableHeaderStyle.column(context, '账号'),
          UnifiedListTableHeaderStyle.column(context, '角色'),
          UnifiedListTableHeaderStyle.column(context, '工段'),
          UnifiedListTableHeaderStyle.column(context, '在线'),
          UnifiedListTableHeaderStyle.column(context, '状态'),
          UnifiedListTableHeaderStyle.column(context, '创建时间'),
          UnifiedListTableHeaderStyle.column(context, '操作'),
        ],
        rows: users.map((user) {
          final statusLabel = user.isOnline ? '在线' : '离线';
          final statusColor = user.isOnline
              ? Colors.green
              : theme.colorScheme.outline;
          final activeLabel = user.isDeleted
              ? '已删除'
              : user.isActive
                  ? '启用'
                  : '停用';
          final activeColor = user.isDeleted
              ? theme.colorScheme.outline
              : user.isActive
                  ? Colors.blue
                  : Colors.red;
          final createdAtStr = user.createdAt != null
              ? '${user.createdAt!.year}-${user.createdAt!.month.toString().padLeft(2, '0')}-${user.createdAt!.day.toString().padLeft(2, '0')}'
              : '-';
          return DataRow(
            color: user.isDeleted
                ? WidgetStatePropertyAll<Color?>(
                    theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                  )
                : null,
            cells: [
              DataCell(Text(user.username)),
              DataCell(
                Text(
                  user.roleName?.trim().isNotEmpty == true
                      ? user.roleName!
                      : '-',
                ),
              ),
              DataCell(
                Text(
                  user.stageName?.trim().isNotEmpty == true
                      ? user.stageName!
                      : '/',
                ),
              ),
              DataCell(
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(
                Text(
                  activeLabel,
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(Text(createdAtStr)),
              DataCell(
                UnifiedListTableHeaderStyle.actionMenuButton<UserTableAction>(
                  theme: theme,
                  onSelected: (action) => onAction(action, user),
                  itemBuilder: (context) => [
                    if (!user.isDeleted && canEditUser)
                      const PopupMenuItem(
                        value: UserTableAction.edit,
                        child: Text('编辑'),
                      ),
                    if (!user.isDeleted && canToggleUser && user.isActive)
                      const PopupMenuItem(
                        value: UserTableAction.disable,
                        child: Text('停用'),
                      )
                    else if (!user.isDeleted && canToggleUser)
                      const PopupMenuItem(
                        value: UserTableAction.enable,
                        child: Text('启用'),
                      ),
                    if (!user.isDeleted && canResetPassword)
                      const PopupMenuItem(
                        value: UserTableAction.resetPassword,
                        child: Text('重置密码'),
                      ),
                    if (!user.isDeleted &&
                        canDeleteUser &&
                        !_isCurrentLoginUser(user))
                      const PopupMenuItem(
                        value: UserTableAction.delete,
                        child: Text('逻辑删除'),
                      ),
                    if (user.isDeleted && canRestoreUser)
                      const PopupMenuItem(
                        value: UserTableAction.restore,
                        child: Text('恢复用户'),
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
