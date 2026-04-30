import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/services/repair_scrap_service.dart';
import 'package:mes_client/features/production/presentation/production_repair_order_detail_page.dart';

class ProductionScrapStatisticsDetailPage extends StatefulWidget {
  const ProductionScrapStatisticsDetailPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.scrapId,
    this.orderCode,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int scrapId;
  final String? orderCode;
  final RepairScrapService? service;

  @override
  State<ProductionScrapStatisticsDetailPage> createState() =>
      _ProductionScrapStatisticsDetailPageState();
}

class _ProductionScrapStatisticsDetailPageState
    extends State<ProductionScrapStatisticsDetailPage> {
  late final RepairScrapService _service;

  bool _loading = true;
  String _message = '';
  ScrapStatisticsItem? _detail;

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
      final detail = await _service.getScrapStatisticsDetail(
        scrapId: widget.scrapId,
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

  Widget _detailRow(String label, String value) {
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

  Future<void> _openRepairDetail(ScrapRelatedRepairOrderItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductionRepairOrderDetailPage(
          session: widget.session,
          onLogout: widget.onLogout,
          repairOrderId: item.id,
          repairOrderCode: item.repairOrderCode,
          service: _service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final title = widget.orderCode ?? detail?.orderCode ?? '#${widget.scrapId}';
    return Scaffold(
      appBar: AppBar(title: Text('报废详情 - $title')),
      body: _loading
          ? const MesLoadingState(label: '报废详情加载中...')
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
                        _detailRow('订单号', detail.orderCode ?? '-'),
                        _detailRow('产品', detail.productName ?? '-'),
                        _detailRow('工序', detail.processName ?? '-'),
                        _detailRow('工序编码', detail.processCode ?? '-'),
                        _detailRow('报废原因', detail.scrapReason),
                        _detailRow('报废数量', '${detail.scrapQuantity}'),
                        _detailRow('进度', scrapProgressLabel(detail.progress)),
                        _detailRow('最近报废时间', _formatDateTime(detail.lastScrapTime)),
                        _detailRow('申请时间', _formatDateTime(detail.appliedAt)),
                        _detailRow('创建时间', _formatDateTime(detail.createdAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  MesSectionCard(
                    title: '关联维修工单',
                    child: detail.relatedRepairOrders.isEmpty
                        ? const MesEmptyState(title: '暂无关联维修工单')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: detail.relatedRepairOrders.map(
                              (repair) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(repair.repairOrderCode),
                                subtitle: Text(
                                  '${repairOrderStatusLabel(repair.status)} | 送修:${repair.repairQuantity} 已修:${repair.repairedQuantity} 报废:${repair.scrapQuantity}\n${_formatDateTime(repair.repairTime)}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openRepairDetail(repair),
                              ),
                            ).toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  MesSectionCard(
                    title: '相关日志',
                    child: detail.relatedEventLogs.isEmpty
                        ? const MesEmptyState(title: '暂无相关日志')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: detail.relatedEventLogs.map(
                              (event) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${_formatDateTime(event.createdAt)} | ${event.eventTitle}'
                                  '${(event.eventDetail ?? '').trim().isEmpty ? '' : ' | ${event.eventDetail!.trim()}'}'
                                  '${(event.orderCode ?? '').trim().isEmpty ? '' : ' | ${event.orderCode}'}'
                                  '${(event.processCode ?? '').trim().isEmpty ? '' : ' | ${event.processCode}'}'
                                  '${(event.orderStatus ?? '').trim().isEmpty ? '' : ' | ${event.orderStatus}'}'
                                  '${(event.payloadJson ?? '').trim().isEmpty ? '' : '\n载荷：${event.payloadJson!.trim()}'}',
                                ),
                              ),
                            ).toList(),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
