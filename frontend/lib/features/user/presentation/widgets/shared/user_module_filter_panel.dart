import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class UserModuleFilterPanel extends StatelessWidget {
  const UserModuleFilterPanel({
    super.key,
    required this.child,
    this.sectionKey,
  });

  final Widget child;
  final Key? sectionKey;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: sectionKey,
      child: MesFilterBar(child: child),
    );
  }
}
