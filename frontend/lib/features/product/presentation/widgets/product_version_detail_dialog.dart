import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/product/models/product_models.dart';

const Map<String, String> _productVersionStatusLabels = {
  'draft': '草稿',
  'effective': '已生效',
  'obsolete': '已失效',
  'disabled': '已停用',
  'inactive': '已失效',
};

class ProductVersionDetailDialog extends StatelessWidget {
  const ProductVersionDetailDialog({
    super.key,
    required this.version,
  });

  final ProductVersionItem version;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: Text('版本详情 - ${version.versionLabel}'),
      width: 420,
      scrollable: true,
      content: SizedBox(
        key: const ValueKey('product-version-detail-dialog'),
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow('版本号', version.versionLabel),
            _detailRow('状态', _productVersionStatusLabels[version.lifecycleStatus] ?? version.lifecycleStatus),
            _detailRow('变更摘要', version.note ?? '-'),
            _detailRow('来源版本', version.sourceVersionLabel ?? '-'),
            _detailRow('创建人', version.createdByUsername ?? '-'),
            _detailRow('创建时间', _formatDate(version.createdAt)),
            if (version.updatedAt != null) _detailRow('最后更新', _formatDate(version.updatedAt!)),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
