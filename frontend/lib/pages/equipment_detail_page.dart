import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import 'maintenance_execution_detail_page.dart';
import 'maintenance_record_detail_page.dart';

class EquipmentDetailPage extends StatefulWidget {
  const EquipmentDetailPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.equipmentId,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int equipmentId;

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  late final EquipmentService _service;
  bool _loading = true;
  String _message = '';
  EquipmentDetailResult? _detail;

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
      final detail = await _service.getEquipmentDetail(equipmentId: widget.equipmentId);
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
      appBar: AppBar(title: Text('设备详情 #${widget.equipmentId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? Center(child: Text(_message.isEmpty ? '加载失败' : _message))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  _row('设备编号', detail.code),
                  _row('设备名称', detail.name),
                  _row('型号', detail.model.isEmpty ? '-' : detail.model),
                  _row('位置', detail.location.isEmpty ? '-' : detail.location),
                  _row('负责人', detail.ownerName.isEmpty ? '-' : detail.ownerName),
                  _row('状态', detail.isEnabled ? '启用' : '停用'),
                  _row('备注', detail.remark.isEmpty ? '-' : detail.remark),
                  _row('启用计划数', '${detail.activePlanCount}'),
                  _row('待执行工单数', '${detail.pendingWorkOrderCount}'),
                  if (detail.pendingWorkOrderCount > 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('风险提示：当前仍有待执行工单，请谨慎调整设备信息。'),
                    ),
                  const Divider(height: 24),
                  const Text('关联计划', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (detail.activePlans.isEmpty)
                    const Text('暂无启用保养计划')
                  else
                    ...detail.activePlans.map(
                      (plan) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${plan.itemName} / ${plan.executionProcessName}'),
                        subtitle: Text('下次到期：${_formatDate(plan.nextDueDate)}｜默认执行人：${plan.defaultExecutorUsername ?? '-'}'),
                      ),
                    ),
                  const Divider(height: 24),
                  const Text('未完成工单', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (detail.pendingWorkOrders.isEmpty)
                    const Text('暂无未完成工单')
                  else
                    ...detail.pendingWorkOrders.map(
                      (order) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('#${order.id} ${order.itemName}'),
                        subtitle: Text('工段：${order.sourceExecutionProcessCode ?? '-'}｜到期：${_formatDate(order.dueDate)}｜状态：${order.status}'),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MaintenanceExecutionDetailPage(
                                  session: widget.session,
                                  onLogout: widget.onLogout,
                                  workOrderId: order.id,
                                ),
                              ),
                            );
                          },
                          child: const Text('查看'),
                        ),
                      ),
                    ),
                  const Divider(height: 24),
                  const Text('最近保养记录', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (detail.recentRecords.isEmpty)
                    const Text('暂无保养记录')
                  else
                    ...detail.recentRecords.map(
                      (record) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(record.itemName),
                        subtitle: Text('完成：${_formatDate(record.completedAt)}｜结果：${record.resultSummary}｜执行人：${record.executorUsername ?? '-'}'),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MaintenanceRecordDetailPage(
                                  session: widget.session,
                                  onLogout: widget.onLogout,
                                  recordId: record.id,
                                ),
                              ),
                            );
                          },
                          child: const Text('查看'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
