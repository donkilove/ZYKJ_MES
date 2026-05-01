import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class FunctionPermissionConfigPageHeader extends StatelessWidget {
  const FunctionPermissionConfigPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
  });

  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('function-permission-config-page-header'),
      child: MesRefreshPageHeader(
        title: '功能权限配置',
        subtitle: '统一配置模块权限能力包。',
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}
