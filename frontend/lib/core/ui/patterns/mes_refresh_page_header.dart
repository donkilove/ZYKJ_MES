import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

/// 带刷新按钮的页面头部。语义化 `MesPageHeader` 的常见模式：
/// 标题 + 右侧 40x40 的圆形刷新动作按钮。
class MesRefreshPageHeader extends StatelessWidget {
  const MesRefreshPageHeader({super.key, required this.title, this.onRefresh});

  final String title;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: title,
      actions: [
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
      ],
    );
  }
}
