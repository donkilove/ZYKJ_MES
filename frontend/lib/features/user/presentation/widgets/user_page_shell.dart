import 'package:flutter/material.dart';

class UserPageShell extends StatelessWidget {
  const UserPageShell({
    super.key,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('user-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('user-page-tab-bar'),
            child: tabBar,
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
