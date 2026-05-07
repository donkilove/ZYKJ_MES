import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

/// 带刷新按钮的页面头部。语义化 `MesPageHeader` 的常见模式：
/// 标题 + 右侧 40x40 的圆形刷新动作按钮。
class MesRefreshPageHeader extends StatelessWidget {
  const MesRefreshPageHeader({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actionsBeforeTitle = const <Widget>[],
    this.onRefresh,
    this.actionsBeforeRefresh = const <Widget>[],
    this.showRefreshButton = true,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actionsBeforeTitle;
  final VoidCallback? onRefresh;
  final List<Widget> actionsBeforeRefresh;
  final bool showRefreshButton;

  List<Widget> _buildTrailingActions() {
    return [
      ...actionsBeforeRefresh,
      if (showRefreshButton)
        Tooltip(
          message: '刷新',
          child: SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final trailingActions = _buildTrailingActions();
    if (leading != null &&
        (title ?? '').trim().isEmpty &&
        (subtitle ?? '').trim().isEmpty &&
        actionsBeforeTitle.isEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: leading!),
          if (trailingActions.isNotEmpty) ...[
            const SizedBox(width: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: trailingActions,
            ),
          ],
        ],
      );
    }

    return MesPageHeader(
      title: title,
      subtitle: subtitle,
      actionsBeforeTitle: actionsBeforeTitle,
      actions: trailingActions,
    );
  }
}
