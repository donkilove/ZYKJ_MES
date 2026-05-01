import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_status_chip.dart';

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

  static const _columnWidths = <int, TableColumnWidth>{
    0: FlexColumnWidth(),
    1: FlexColumnWidth(),
    2: FlexColumnWidth(),
    3: FlexColumnWidth(),
    4: FlexColumnWidth(),
    5: FlexColumnWidth(),
    6: FlexColumnWidth(),
  };

  static const _headerLabels = ['账号', '角色', '工段', '在线', '状态', '创建时间', '操作'];

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      child: Table(
        columnWidths: _columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: _headerLabels.map((label) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Table(
        columnWidths: _columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: users.map((user) {
          final activeLabel = user.isDeleted
              ? '已删除'
              : user.isActive
                  ? '启用'
                  : '停用';
          final createdAtStr = user.createdAt != null
              ? '${user.createdAt!.year}-${user.createdAt!.month.toString().padLeft(2, '0')}-${user.createdAt!.day.toString().padLeft(2, '0')}'
              : '-';
          return TableRow(
            decoration: user.isDeleted
                ? BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                  )
                : null,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(user.username),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  user.roleName?.trim().isNotEmpty == true ? user.roleName! : '-',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  user.stageName?.trim().isNotEmpty == true ? user.stageName! : '/',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: UserModuleStatusChip(
                  tone: user.isOnline
                      ? UserModuleStatusTone.online
                      : UserModuleStatusTone.offline,
                  label: user.isOnline ? '在线' : '离线',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: UserModuleStatusChip(
                  tone: user.isDeleted
                      ? UserModuleStatusTone.deleted
                      : user.isActive
                          ? UserModuleStatusTone.active
                          : UserModuleStatusTone.inactive,
                  label: activeLabel,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(createdAtStr),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: UnifiedListTableHeaderStyle.actionMenuButton<UserTableAction>(
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

  @override
  Widget build(BuildContext context) {
    return CrudListTableSection(
      key: const ValueKey('userListSection'),
      cardKey: const ValueKey('userListCard'),
      loading: loading,
      isEmpty: users.isEmpty,
      emptyText: emptyText,
      stickyHeader: true,
      headerWidget: _buildHeader(context),
      bodyWidget: _buildBody(context),
      child: const SizedBox.shrink(),
    );
  }
}
