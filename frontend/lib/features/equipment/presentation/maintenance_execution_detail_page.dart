import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_record_detail_page.dart';

class MaintenanceExecutionDetailPage extends StatefulWidget {
  const MaintenanceExecutionDetailPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.workOrderId,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int workOrderId;
  final EquipmentService? service;

  @override
  State<MaintenanceExecutionDetailPage> createState() =>
      _MaintenanceExecutionDetailPageState();
}

class _MaintenanceExecutionDetailPageState
    extends State<MaintenanceExecutionDetailPage> {
  late final EquipmentService _service;
  bool _loading = true;
  String _message = '';
  MaintenanceWorkOrderDetail? _detail;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EquipmentService(widget.session);
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
    return Scaffold(
      appBar: AppBar(title: Text('保养执行详情 #${widget.workOrderId}')),
      body: _loading
          ? const MesLoadingState(label: '保养执行详情加载中...')
          : detail == null
          ? Center(child: Text(_message.isEmpty ? '加载失败' : _message))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
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
                  _row('到期日期', _formatDate(detail.dueDate)),
                  _row('状态', _statusLabel(detail.status)),
                  _row('执行人', detail.executorUsername ?? '-'),
                  _row('开始时间', _formatDateTime(detail.startedAt)),
                  _row('完成时间', _formatDateTime(detail.completedAt)),
                  _row('结果摘要', detail.resultSummary ?? '-'),
                  _row('备注', detail.resultRemark ?? '-'),
                  if (detail.attachmentLink?.trim().isNotEmpty == true)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MaintenanceAttachmentAction(
                        attachmentLink: detail.attachmentLink,
                        attachmentName: detail.attachmentName,
                        onOpen: openMaintenanceAttachment,
                      ),
                    ),
                  if (detail.recordId != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
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
                    ),
                ],
              ),
            ),
    );
  }
}
