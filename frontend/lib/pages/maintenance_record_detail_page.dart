import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import 'maintenance_execution_detail_page.dart';

class MaintenanceRecordDetailPage extends StatefulWidget {
  const MaintenanceRecordDetailPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.recordId,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int recordId;

  @override
  State<MaintenanceRecordDetailPage> createState() => _MaintenanceRecordDetailPageState();
}

class _MaintenanceRecordDetailPageState extends State<MaintenanceRecordDetailPage> {
  late final EquipmentService _service;
  bool _loading = true;
  String _message = '';
  MaintenanceRecordDetail? _detail;

  @override
  void initState() {
    super.initState();
    _service = EquipmentService(widget.session);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final detail = await _service.getRecordDetail(recordId: widget.recordId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() => _message = error is ApiException ? error.message : error.toString());
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  Future<void> _openAttachment(String urlText) async {
    final uri = Uri.tryParse(urlText.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label：', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text('保养记录详情 #${widget.recordId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? Center(child: Text(_message.isEmpty ? '加载失败' : _message))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  _row('设备', detail.equipmentName),
                  if ((detail.sourceEquipmentCode ?? '').trim().isNotEmpty) _row('设备编号', detail.sourceEquipmentCode!),
                  _row('项目', detail.itemName),
                  if ((detail.sourceItemName ?? '').trim().isNotEmpty) _row('项目快照', detail.sourceItemName!),
                  _row('工单编号', '#${detail.workOrderId}'),
                  _row('到期日期', _formatDate(detail.dueDate)),
                  _row('完成时间', _formatDateTime(detail.completedAt)),
                  _row('执行人', detail.executorUsername ?? '-'),
                  _row('结果摘要', detail.resultSummary),
                  _row('备注', detail.resultRemark ?? '-'),
                  if (detail.sourcePlanCycleDays != null) _row('计划周期(天)', '${detail.sourcePlanCycleDays}'),
                  if (detail.sourcePlanStartDate != null) _row('计划起始日期', _formatDate(detail.sourcePlanStartDate!)),
                  if (detail.attachmentLink?.trim().isNotEmpty == true)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openAttachment(detail.attachmentLink!),
                        icon: const Icon(Icons.attach_file),
                        label: const Text('查看附件'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MaintenanceExecutionDetailPage(
                              session: widget.session,
                              onLogout: widget.onLogout,
                              workOrderId: detail.workOrderId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('查看来源工单'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
