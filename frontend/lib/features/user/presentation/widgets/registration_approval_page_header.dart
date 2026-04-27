import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class RegistrationApprovalPageHeader extends StatelessWidget {
  const RegistrationApprovalPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesRefreshPageHeader(title: '注册审批', onRefresh: loading ? null : onRefresh);
  }
}
