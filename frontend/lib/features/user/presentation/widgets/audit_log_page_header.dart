import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class AuditLogPageHeader extends StatelessWidget {
  const AuditLogPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
  });

  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('audit-log-page-header'),
      child: MesRefreshPageHeader(
        title: '审计日志',
        subtitle: '统一查看操作人、目标对象与动作结果。',
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}
