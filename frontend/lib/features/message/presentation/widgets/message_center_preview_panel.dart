import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_detail_panel.dart';

class MessageCenterPreviewPanel extends StatelessWidget {
  const MessageCenterPreviewPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MesDetailPanel(
      title: '消息详情预览',
      expandChild: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: const ValueKey('message-center-preview-scroll'),
            padding: const EdgeInsets.only(right: 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
