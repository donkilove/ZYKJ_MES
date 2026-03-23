import 'package:flutter/material.dart';

import 'adaptive_table_container.dart';
import 'unified_list_table_header_style.dart';

class CrudListTableSection extends StatelessWidget {
  const CrudListTableSection({
    super.key,
    required this.loading,
    required this.isEmpty,
    required this.child,
    this.emptyText = '暂无数据',
    this.cardKey,
    this.loadingWidget,
    this.emptyWidget,
    this.contentPadding = EdgeInsets.zero,
    this.enableUnifiedHeaderStyle = false,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    this.clipBehavior = Clip.hardEdge,
  });

  final bool loading;
  final bool isEmpty;
  final Widget child;
  final String emptyText;
  final Key? cardKey;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final EdgeInsetsGeometry contentPadding;
  final bool enableUnifiedHeaderStyle;
  final ShapeBorder shape;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget body;

    if (loading) {
      body = loadingWidget ?? const Center(child: CircularProgressIndicator());
    } else if (isEmpty) {
      body = emptyWidget ?? Center(child: Text(emptyText));
    } else {
      final content = enableUnifiedHeaderStyle
          ? UnifiedListTableHeaderStyle.wrap(theme: theme, child: child)
          : child;
      body = AdaptiveTableContainer(padding: contentPadding, child: content);
    }

    return Card(
      key: cardKey,
      shape: shape,
      clipBehavior: clipBehavior,
      child: SizedBox.expand(child: body),
    );
  }
}
