import 'package:flutter/material.dart';

class ProductionPageShell extends StatelessWidget {
  const ProductionPageShell({
    super.key,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('production-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('production-page-tab-bar'),
            child: tabBar,
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
