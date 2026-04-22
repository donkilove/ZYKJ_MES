import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class QualityRepairOrdersPageHeader extends StatelessWidget {
  const QualityRepairOrdersPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('quality-repair-orders-page-header'),
      child: MesPageHeader(
        title: '维修订单',
        subtitle: '统一查看质量维修订单与处理入口。',
      ),
    );
  }
}
