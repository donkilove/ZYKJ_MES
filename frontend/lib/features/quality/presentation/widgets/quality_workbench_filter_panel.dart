import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class QualityWorkbenchFilterPanel extends StatelessWidget {
  const QualityWorkbenchFilterPanel({
    super.key,
    required this.child,
    this.title = '筛选控制台',
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MesFilterBar(title: title, child: child);
  }
}
