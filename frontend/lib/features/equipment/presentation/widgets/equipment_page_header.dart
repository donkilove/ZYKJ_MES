import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class EquipmentPageHeader extends StatelessWidget {
  const EquipmentPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('equipment-page-header'),
      child: MesPageHeader(
        title: '设备管理',
        subtitle: '统一装配设备模块全部页签。',
      ),
    );
  }
}
