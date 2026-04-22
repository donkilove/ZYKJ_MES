import 'package:flutter/material.dart';

class EquipmentPageShell extends StatelessWidget {
  const EquipmentPageShell({
    super.key,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('equipment-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('equipment-page-tab-bar'),
            child: tabBar,
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
