import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class AccountSettingsPageHeader extends StatelessWidget {
  const AccountSettingsPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('account-settings-page-header'),
      child: MesPageHeader(
        title: '个人中心',
        subtitle: '统一管理个人信息与密码修改入口。',
      ),
    );
  }
}
