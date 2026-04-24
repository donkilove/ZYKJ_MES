import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_detail_panel.dart';

class MessageCenterPreviewPanel extends StatefulWidget {
  const MessageCenterPreviewPanel({super.key, required this.child});

  final Widget child;

  @override
  State<MessageCenterPreviewPanel> createState() =>
      _MessageCenterPreviewPanelState();
}

class _MessageCenterPreviewPanelState extends State<MessageCenterPreviewPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactScroll = constraints.maxHeight < 220;
        if (useCompactScroll) {
          return Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: const ValueKey('message-center-preview-scroll'),
              controller: _scrollController,
              primary: false,
              padding: const EdgeInsets.only(right: 4),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: MesDetailPanel(title: '消息详情预览', child: widget.child),
              ),
            ),
          );
        }
        return MesDetailPanel(
          title: '消息详情预览',
          expandChild: true,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: const ValueKey('message-center-preview-scroll'),
              controller: _scrollController,
              primary: false,
              padding: const EdgeInsets.only(right: 4),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
