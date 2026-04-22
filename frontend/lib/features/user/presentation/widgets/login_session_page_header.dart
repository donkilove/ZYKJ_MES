import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class LoginSessionPageHeader extends StatelessWidget {
  const LoginSessionPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('login-session-page-header'),
      child: MesPageHeader(
        title: '登录会话',
        subtitle: '统一查看在线会话和强制下线入口。',
      ),
    );
  }
}
