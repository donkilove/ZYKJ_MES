import 'package:flutter/material.dart';

class CraftPageShell extends StatelessWidget {
  const CraftPageShell({
    super.key,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('craft-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('craft-page-tab-bar'),
            child: tabBar,
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
