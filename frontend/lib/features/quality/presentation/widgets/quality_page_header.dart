import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class QualityPageHeader extends StatelessWidget {
  const QualityPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('quality-page-header'),
      child: MesPageHeader(
        title: '质量管理',
        subtitle: '统一装配质量模块全部页签。',
      ),
    );
  }
}
