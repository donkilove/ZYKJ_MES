import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class MesDetailPanel extends StatelessWidget {
  const MesDetailPanel({
    super.key,
    required this.title,
    required this.child,
    this.expandChild = false,
  });

  final String title;
  final Widget child;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return MesSectionCard(title: title, expandChild: expandChild, child: child);
  }
}
