import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductionPageHeader extends StatelessWidget {
  const ProductionPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('production-page-header'),
      child: MesPageHeader(
        title: '生产管理',
        subtitle: '统一装配生产模块全部页签。',
      ),
    );
  }
}
