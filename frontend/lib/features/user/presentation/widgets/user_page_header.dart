import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class UserPageHeader extends StatelessWidget {
  const UserPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('user-page-header'),
      child: MesPageHeader(title: '用户管理', subtitle: '统一装配用户模块全部页签。'),
    );
  }
}
