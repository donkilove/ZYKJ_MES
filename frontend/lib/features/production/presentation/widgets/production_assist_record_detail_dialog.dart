import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionAssistRecordDetailDialog extends StatelessWidget {
  const ProductionAssistRecordDetailDialog({
    super.key,
    required this.item,
  });

  final AssistAuthorizationItem item;

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  TableRow _detailRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: const Text('代班记录详情'),
      width: 520,
      content: SizedBox(
        key: const ValueKey('production-assist-record-detail-dialog'),
        width: 520,
        child: Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
          },
          children: [
            _detailRow('订单号', item.orderCode),
            _detailRow('工序', item.processName),
            _detailRow('目标操作员', item.targetOperatorUsername),
            _detailRow('发起人', item.requesterUsername),
            _detailRow('代班人', item.helperUsername),
            _detailRow('状态', assistAuthorizationStatusLabel(item.status)),
            _detailRow('申请原因', item.reason ?? '-'),
            _detailRow('处理人', item.reviewerUsername ?? '-'),
            _detailRow(
              '处理时间',
              item.reviewedAt != null ? _formatDateTime(item.reviewedAt!) : '-',
            ),
            _detailRow('处理备注', item.reviewRemark ?? '-'),
            _detailRow('创建时间', _formatDateTime(item.createdAt)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
