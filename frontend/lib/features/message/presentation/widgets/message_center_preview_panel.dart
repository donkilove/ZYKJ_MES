import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '消息详情预览',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('message-center-preview-scroll'),
                  controller: _scrollController,
                  primary: false,
                  padding: const EdgeInsets.only(right: 8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: widget.child,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
