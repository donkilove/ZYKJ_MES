import 'package:flutter/material.dart';

class MessagePageShell extends StatelessWidget {
  const MessagePageShell({
    super.key,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        tabBar,
        Expanded(child: tabBarView),
      ],
    );
  }
}
