import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../services/repair_scrap_service.dart';

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
  final RepairScrapService? service;

  @override
  State<ProductionRepairOrderDetailPage> createState() =>
      _ProductionRepairOrderDetailPageState();
}

class _ProductionRepairOrderDetailPageState
    extends State<ProductionRepairOrderDetailPage> {
  late final RepairScrapService _service;

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

  String _defectTraceText(RepairDefectPhenomenonDetailItem item) {
    final parts = <String>[];
    if (item.productionRecordId != null) {
      parts.add('报工记录#${item.productionRecordId}');
    }
    if (item.productionRecordType != null &&
        item.productionRecordType!.trim().isNotEmpty) {
      parts.add('类型${item.productionRecordType}');
    }
    if (item.productionRecordQuantity != null) {
      parts.add('报工数${item.productionRecordQuantity}');
    }
    if (item.productionSubOrderId != null) {
      parts.add('子单#${item.productionSubOrderId}');
    }
    if (item.productionRecordCreatedAt != null) {
      parts.add('报工时间${_formatDateTime(item.productionRecordCreatedAt)}');
    }
    return parts.join(' | ');
  }

  Widget _buildSummaryMetric(String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<TableRow> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: rows,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSection(String title, List<String> lines) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (lines.isEmpty)
              const Text('暂无数据')
            else
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line),
                ),
              ),
          ],
        ),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _buildSummaryMetric('维修单号', detail.repairOrderCode),
                          _buildSummaryMetric(
                            '状态',
                            repairOrderStatusLabel(detail.status),
                          ),
                          _buildSummaryMetric(
                            '送修数量',
                            '${detail.repairQuantity}',
                          ),
                          _buildSummaryMetric(
                            '已修数量',
                            '${detail.repairedQuantity}',
                          ),
                          _buildSummaryMetric(
                            '报废数量',
                            '${detail.scrapQuantity}',
                          ),
                          _buildSummaryMetric(
                            '报废已补',
                            detail.scrapReplenished ? '是' : '否',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard('维修基础信息', [
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '来源订单',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(detail.sourceOrderCode ?? '-'),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '产品',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(detail.productName ?? '-'),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '工序',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(detail.sourceProcessName),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '送修人',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(detail.senderUsername ?? '-'),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '维修人',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(
                            detail.repairOperatorUsername ?? '-',
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '生产数量',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText('${detail.productionQuantity}'),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '送修时间',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(
                            _formatDateTime(detail.repairTime),
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 0),
                          child: Text(
                            '完成时间',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 0),
                          child: SelectableText(
                            _formatDateTime(detail.completedAt),
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _buildTextSection(
                    '缺陷现象',
                    detail.defectRows
                        .map(
                          (item) => _defectTraceText(item).isEmpty
                              ? '• ${item.phenomenon}（${item.quantity}件）'
                              : '• ${item.phenomenon}（${item.quantity}件）\n  关联${_defectTraceText(item)}',
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _buildTextSection(
                    '维修原因',
                    detail.causeRows
                        .map(
                          (item) =>
                              '• ${item.phenomenon} → ${item.reason}（${item.quantity}件${item.isScrap ? '，报废' : ''}）',
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _buildTextSection(
                    '回流分配',
                    detail.returnRoutes
                        .map(
                          (item) =>
                              '• ${item.targetProcessName}（${item.returnQuantity}件）',
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _buildTextSection(
                    '相关事件记录',
                    detail.eventLogs
                        .map(
                          (item) =>
                              '• ${_formatDateTime(item.createdAt)} | ${item.eventTitle}'
                              '${(item.eventDetail ?? '').trim().isEmpty ? '' : ' | ${item.eventDetail}'}'
                              '${(item.orderCode ?? '').trim().isEmpty ? '' : ' | ${item.orderCode}'}'
                              '${(item.processCode ?? '').trim().isEmpty ? '' : ' | ${item.processCode}'}'
                              '${(item.orderStatus ?? '').trim().isEmpty ? '' : ' | ${item.orderStatus}'}'
                              '${(item.payloadJson ?? '').trim().isEmpty ? '' : '\n  载荷：${item.payloadJson}'}',
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
    );
  }
}
