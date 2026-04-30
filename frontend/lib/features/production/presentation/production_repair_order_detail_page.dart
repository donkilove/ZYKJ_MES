import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/services/repair_scrap_service.dart';

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

  String _defectTraceText(RepairDefectPhenomenonDetailItem item) {
    final parts = <String>[];
    if (item.productionRecordId != null) {
      parts.add('报工记录#${item.productionRecordId}');
    }
    if (item.productionRecordType != null && item.productionRecordType!.trim().isNotEmpty) {
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
          ? const MesLoadingState(label: '维修详情加载中...')
          : detail == null
          ? MesErrorState(
              message: _message.isEmpty ? '加载失败' : _message,
              onRetry: _load,
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  MesSectionCard(
                    title: '基础信息',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                      ],
                    ),
                  ),
                  if (detail.defectRows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    MesSectionCard(
                      title: '缺陷现象',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: detail.defectRows.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _defectTraceText(item).isEmpty
                                  ? '• ${item.phenomenon}（${item.quantity}件）'
                                  : '• ${item.phenomenon}（${item.quantity}件）\n  关联${_defectTraceText(item)}',
                            ),
                          ),
                        ).toList(),
                      ),
                    ),
                  ],
                  if (detail.causeRows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    MesSectionCard(
                      title: '维修原因',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: detail.causeRows.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${item.phenomenon} → ${item.reason}（${item.quantity}件${item.isScrap ? '，报废' : ''}）',
                            ),
                          ),
                        ).toList(),
                      ),
                    ),
                  ],
                  if (detail.returnRoutes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    MesSectionCard(
                      title: '回流分配',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: detail.returnRoutes.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${item.targetProcessName}（${item.returnQuantity}件）',
                            ),
                          ),
                        ).toList(),
                      ),
                    ),
                  ],
                  if (detail.eventLogs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    MesSectionCard(
                      title: '相关事件记录',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: detail.eventLogs.map(
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
                        ).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
