import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class LoginSessionPageHeader extends StatelessWidget {
  const LoginSessionPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
  });

  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('login-session-page-header'),
      child: MesRefreshPageHeader(
        title: '登录会话',
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}
