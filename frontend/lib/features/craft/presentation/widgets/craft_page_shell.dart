import 'package:flutter/material.dart';

class CraftPageShell extends StatelessWidget {
  const CraftPageShell({
    super.key,
    required this.header,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget header;
  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('craft-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('craft-page-header-slot'),
            child: header,
          ),
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
