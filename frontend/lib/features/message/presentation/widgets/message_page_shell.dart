import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: KeyedSubtree(
            key: ValueKey('message-page-header'),
            child: MesPageHeader(
              title: '消息中心',
              subtitle: '统一查看系统消息、待办与跳转入口。',
            ),
          ),
        ),
        const SizedBox(height: 16),
        tabBar,
        Expanded(child: tabBarView),
      ],
    );
  }
}
