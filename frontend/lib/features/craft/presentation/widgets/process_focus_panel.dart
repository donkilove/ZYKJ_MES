import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';

class ProcessFocusPanel extends StatelessWidget {
  const ProcessFocusPanel({
    super.key,
    required this.item,
    required this.jumpNotice,
    this.onViewReference,
  });

  final CraftProcessItem? item;
  final String jumpNotice;
  final VoidCallback? onViewReference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('process-focus-panel'),
      child: MesSectionCard(
        title: '聚焦工序详情',
        child: item == null
            ? MesEmptyState(
                title: jumpNotice.isNotEmpty ? jumpNotice : '当前未选中工序',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (jumpNotice.isNotEmpty) ...[
                    Text(
                      jumpNotice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text('名称：${item!.name}'),
                  const SizedBox(height: 8),
                  Text('编码：${item!.code}'),
                  const SizedBox(height: 8),
                  Text('所属工段：${item!.stageName ?? '-'}'),
                  const SizedBox(height: 8),
                  Text('状态：${item!.isEnabled ? '启用' : '停用'}'),
                  if (item!.remark.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('备注：${item!.remark}'),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onViewReference,
                      icon: const Icon(Icons.account_tree_outlined),
                      label: const Text('查看引用'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
