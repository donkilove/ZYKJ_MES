import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class MessagePageHeader extends StatelessWidget {
  const MessagePageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('message-page-header'),
      child: MesPageHeader(
        title: '消息中心',
        subtitle: '统一装配消息中心全部功能。',
      ),
    );
  }
}
