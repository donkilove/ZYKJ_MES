import 'package:flutter/material.dart';

class QualityPageShell extends StatelessWidget {
  const QualityPageShell({
    super.key,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('quality-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('quality-page-tab-bar'),
            child: tabBar,
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
