import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';

class UserManagementPageHeader extends StatelessWidget {
  const UserManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return CrudPageHeader(title: '用户管理', onRefresh: loading ? null : onRefresh);
  }
}
