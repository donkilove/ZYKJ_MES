import 'package:flutter/material.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_table_shell.dart';
import 'package:mes_client/features/user/presentation/widgets/user_data_table.dart';

class UserManagementTableSection extends StatelessWidget {
  const UserManagementTableSection({
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

  @override
  Widget build(BuildContext context) {
    return UserModuleTableShell(
      sectionKey: const ValueKey('user-management-table-section'),
      title: '用户列表',
      child: UserDataTable(
        users: users,
        loading: loading,
        emptyText: emptyText,
        canEditUser: canEditUser,
        canToggleUser: canToggleUser,
        canResetPassword: canResetPassword,
        canDeleteUser: canDeleteUser,
        canRestoreUser: canRestoreUser,
        myUserId: myUserId,
        onAction: onAction,
      ),
    );
  }
}
