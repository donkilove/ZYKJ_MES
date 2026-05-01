import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class AccountSettingsPageHeader extends StatelessWidget {
  const AccountSettingsPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
  });

  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('account-settings-page-header'),
      child: MesRefreshPageHeader(
        title: '个人中心',
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}
