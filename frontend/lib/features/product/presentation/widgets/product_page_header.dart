import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductPageHeader extends StatelessWidget {
  const ProductPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('product-page-header'),
      child: MesPageHeader(title: '产品管理', subtitle: '统一装配产品模块全部页签。'),
    );
  }
}
