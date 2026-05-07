import 'package:flutter/material.dart';

class MessagePageShell extends StatelessWidget {
  const MessagePageShell({
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
      key: const ValueKey('message-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('message-page-header-slot'),
            child: header,
          ),
          KeyedSubtree(
            key: const ValueKey('message-page-tab-bar'),
            child: tabBar,
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
