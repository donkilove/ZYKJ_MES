import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import 'maintenance_record_detail_page.dart';

class MaintenanceExecutionDetailPage extends StatefulWidget {
  const MaintenanceExecutionDetailPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.workOrderId,
    this.equipmentService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int workOrderId;
  final EquipmentService? equipmentService;

  @override
  State<MaintenanceExecutionDetailPage> createState() =>
      _MaintenanceExecutionDetailPageState();
}

class _MaintenanceExecutionDetailPageState
    extends State<MaintenanceExecutionDetailPage> {
  static const double _desktopBreakpoint = 1200;

  late final EquipmentService _service;
  bool _loading = true;
  String _message = '';
  MaintenanceWorkOrderDetail? _detail;

  @override
  void initState() {
    super.initState();
    _service = widget.equipmentService ?? EquipmentService(widget.session);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final detail = await _service.getWorkOrderDetail(
        workOrderId: widget.workOrderId,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(
        () =>
            _message = error is ApiException ? error.message : error.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待执行';
      case 'in_progress':
        return '执行中';
      case 'overdue':
        return '已逾期';
      case 'done':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }

  String _nonEmptyOrDash(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '-' : normalized;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }

  Widget _statusCard(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> rows,
    String? subtitle,
    Widget? footer,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return Column(children: rows);
                }
                return Wrap(
                  spacing: 24,
                  children: rows
                      .map(
                        (row) => SizedBox(
                          width: (constraints.maxWidth - 24) / 2,
                          child: row,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            if (footer != null) ...[const SizedBox(height: 16), footer],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text('保养执行详情 #${widget.workOrderId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? Center(child: Text(_message.isEmpty ? '加载失败' : _message))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
                final overviewCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.itemName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text('工单 #${detail.id}')),
                            Chip(label: Text('设备 ${detail.equipmentName}')),
                            Chip(
                              label: Text('状态 ${_statusLabel(detail.status)}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _statusCard(
                              '到期日期',
                              _formatDate(detail.dueDate),
                              Icons.event_outlined,
                            ),
                            _statusCard(
                              '执行人',
                              _nonEmptyOrDash(detail.executorUsername),
                              Icons.person_outline,
                            ),
                            _statusCard(
                              '完成时间',
                              _formatDateTime(detail.completedAt),
                              Icons.fact_check_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

                final sourceCard = _sectionCard(
                  title: '来源信息',
                  subtitle: '展示计划、设备与项目快照，便于桌面端并排核对。',
                  rows: [
                    _row('设备', detail.equipmentName),
                    _row('来源计划', _nonEmptyOrDash(detail.sourcePlanSummary)),
                    _row('设备快照', _nonEmptyOrDash(detail.sourceEquipmentName)),
                    _row(
                      '执行工段快照',
                      _nonEmptyOrDash(detail.sourceExecutionProcessCode),
                    ),
                    if ((detail.sourceEquipmentCode ?? '').trim().isNotEmpty)
                      _row('设备编号', detail.sourceEquipmentCode!),
                    _row('项目', detail.itemName),
                    if ((detail.sourceItemName ?? '').trim().isNotEmpty)
                      _row('项目快照', detail.sourceItemName!),
                  ],
                );

                final executionCard = _sectionCard(
                  title: '执行结果',
                  rows: [
                    _row('状态', _statusLabel(detail.status)),
                    _row('开始时间', _formatDateTime(detail.startedAt)),
                    _row('完成时间', _formatDateTime(detail.completedAt)),
                    _row('结果摘要', detail.resultSummary ?? '-'),
                    _row('备注', detail.resultRemark ?? '-'),
                  ],
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detail.attachmentLink?.trim().isNotEmpty == true)
                        MaintenanceAttachmentAction(
                          attachmentLink: detail.attachmentLink,
                          attachmentName: detail.attachmentName,
                          onOpen: openMaintenanceAttachment,
                        ),
                      if (detail.recordId != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MaintenanceRecordDetailPage(
                                  session: widget.session,
                                  onLogout: widget.onLogout,
                                  recordId: detail.recordId!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('查看生成记录'),
                        ),
                      ],
                    ],
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      overviewCard,
                      const SizedBox(height: 16),
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: sourceCard),
                            const SizedBox(width: 16),
                            Expanded(child: executionCard),
                          ],
                        )
                      else ...[
                        sourceCard,
                        const SizedBox(height: 16),
                        executionCard,
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
