import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class MesFilterBar extends StatelessWidget {
  const MesFilterBar({super.key, required this.child, this.title = '筛选条件'});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MesSectionCard(title: title, child: child);
  }
}
