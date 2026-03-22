import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';

class ProductionRepairOrderDetailPage extends StatefulWidget {
  const ProductionRepairOrderDetailPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.repairOrderId,
    this.repairOrderCode,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int repairOrderId;
  final String? repairOrderCode;
  final ProductionService? service;

  @override
  State<ProductionRepairOrderDetailPage> createState() =>
      _ProductionRepairOrderDetailPageState();
}

class _ProductionRepairOrderDetailPageState
    extends State<ProductionRepairOrderDetailPage> {
  late final ProductionService _service;

  bool _loading = true;
  String _message = '';
  RepairOrderDetailItem? _detail;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final detail = await _service.getRepairOrderDetail(
        repairOrderId: widget.repairOrderId,
      );
      if (!mounted) {
        return;
      }
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = error is ApiException ? error.message : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label：',
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
    final detail = _detail;
    final title =
        widget.repairOrderCode ??
        detail?.repairOrderCode ??
        '#${widget.repairOrderId}';
    return Scaffold(
      appBar: AppBar(title: Text('维修详情 - $title')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? Center(child: Text(_message.isEmpty ? '加载失败' : _message))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  _row('维修单号', detail.repairOrderCode),
                  _row('来源订单', detail.sourceOrderCode ?? '-'),
                  _row('产品', detail.productName ?? '-'),
                  _row('工序', detail.sourceProcessName),
                  _row('送修人', detail.senderUsername ?? '-'),
                  _row('维修人', detail.repairOperatorUsername ?? '-'),
                  _row('生产数量', '${detail.productionQuantity}'),
                  _row('送修数量', '${detail.repairQuantity}'),
                  _row('已修数量', '${detail.repairedQuantity}'),
                  _row('报废数量', '${detail.scrapQuantity}'),
                  _row('报废已补', detail.scrapReplenished ? '是' : '否'),
                  _row('状态', repairOrderStatusLabel(detail.status)),
                  _row('送修时间', _formatDateTime(detail.repairTime)),
                  _row('完成时间', _formatDateTime(detail.completedAt)),
                  if (detail.defectRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '缺陷现象',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...detail.defectRows.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${item.phenomenon}（${item.quantity}件）'),
                      ),
                    ),
                  ],
                  if (detail.causeRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '维修原因',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...detail.causeRows.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${item.phenomenon} → ${item.reason}（${item.quantity}件${item.isScrap ? '，报废' : ''}）',
                        ),
                      ),
                    ),
                  ],
                  if (detail.returnRoutes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '回流分配',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...detail.returnRoutes.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${item.targetProcessName}（${item.returnQuantity}件）',
                        ),
                      ),
                    ),
                  ],
                  if (detail.eventLogs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '相关事件记录',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...detail.eventLogs.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${_formatDateTime(item.createdAt)} | ${item.eventTitle}'
                          '${(item.eventDetail ?? '').trim().isEmpty ? '' : ' | ${item.eventDetail}'}'
                          '${(item.orderCode ?? '').trim().isEmpty ? '' : ' | ${item.orderCode}'}'
                          '${(item.processCode ?? '').trim().isEmpty ? '' : ' | ${item.processCode}'}'
                          '${(item.orderStatus ?? '').trim().isEmpty ? '' : ' | ${item.orderStatus}'}'
                          '${(item.payloadJson ?? '').trim().isEmpty ? '' : '\n  载荷：${item.payloadJson}'}',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
