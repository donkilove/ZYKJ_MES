import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductParameterHistoryDialog extends StatelessWidget {
  const ProductParameterHistoryDialog({
    super.key,
    required this.row,
    required this.history,
    required this.formatTime,
    required this.historyTypeLabel,
    required this.onClose,
    required this.onViewSnapshot,
  });

  final ProductParameterVersionListItem row;
  final ProductParameterHistoryListResult history;
  final String Function(DateTime value) formatTime;
  final String Function(String value) historyTypeLabel;
  final VoidCallback onClose;
  final ValueChanged<ProductParameterHistoryItem> onViewSnapshot;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-history-dialog'),
      child: AlertDialog(
        title: Text(
          '参数变更历史 - ${row.productName} / ${row.productCategory} / ${history.versionLabel ?? row.versionLabel}',
        ),
        content: SizedBox(
          width: 760,
          height: 480,
          child: history.items.isEmpty
              ? const Center(child: Text('暂无历史记录'))
              : ListView.separated(
                  itemCount: history.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = history.items[index];
                    final keySummary = item.changedKeys.isEmpty
                        ? '无参数字段变化'
                        : item.changedKeys.join(', ');
                    final typeLabel = historyTypeLabel(item.changeType);
                    return ListTile(
                      title: Text(
                        '$typeLabel / ${item.parameterName ?? '未指定参数'}',
                      ),
                      subtitle: Text(
                        '产品：${item.productName}   分类：${item.productCategory.isEmpty ? '-' : item.productCategory}\n'
                        '时间：${formatTime(item.createdAt)}\n'
                        '版本：${item.versionLabel ?? '-'}   操作人：${item.operatorUsername}   类型：$typeLabel\n'
                        '参数：$keySummary\n'
                        '变更原因：${item.changeReason}\n'
                        '变更前：${item.beforeSummary ?? '-'}\n'
                        '变更后：${item.afterSummary ?? '-'}',
                      ),
                      isThreeLine: false,
                      trailing:
                          item.beforeSnapshot != '{}' || item.afterSnapshot != '{}'
                          ? TextButton(
                              onPressed: () => onViewSnapshot(item),
                              child: const Text('查看快照'),
                            )
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(onPressed: onClose, child: const Text('关闭')),
        ],
      ),
    );
  }
}
