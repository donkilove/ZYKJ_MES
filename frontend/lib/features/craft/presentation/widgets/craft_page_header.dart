import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class CraftPageHeader extends StatelessWidget {
  const CraftPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('craft-page-header'),
      child: MesPageHeader(
        title: '工艺管理',
        subtitle: '统一装配工艺模块全部页签。',
      ),
    );
  }
}
