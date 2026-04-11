import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_execution_detail_page.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_record_detail_page.dart';

class EquipmentDetailPage extends StatefulWidget {
  const EquipmentDetailPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.equipmentId,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int equipmentId;
  final EquipmentService? service;

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  late final EquipmentService _service;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _plansSectionKey = GlobalKey();
  final GlobalKey _workOrdersSectionKey = GlobalKey();
  final GlobalKey _recordsSectionKey = GlobalKey();
  bool _loading = true;
  String _message = '';
  EquipmentDetailResult? _detail;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EquipmentService(widget.session);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final detail = await _service.getEquipmentDetail(
        equipmentId: widget.equipmentId,
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

  Future<void> _scrollToSection(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  List<String> _buildRiskMessages(EquipmentDetailResult detail) {
    final messages = <String>[];
    if (detail.pendingWorkOrderCount > 0) {
      messages.add(
        '当前有${detail.pendingWorkOrderCount}个待执行工单未收口，调整设备前请先核对到期任务与现场状态。',
      );
    } else if (detail.pendingWorkOrdersScopeLimited) {
      messages.add('待执行工单仅展示当前权限范围内数据，不能据此判断设备已无执行阻塞。');
    } else {
      messages.add('当前没有待执行工单，设备变更前的执行阻塞风险较低。');
    }

    if (detail.activePlanCount > 0) {
      messages.add('设备仍挂接${detail.activePlanCount}个活跃保养计划，停机或迁移前需同步确认后续排程。');
    } else if (detail.activePlansScopeLimited) {
      messages.add('活跃计划仅展示当前权限范围内数据，如需完整排程请联系具备相应权限的人员复核。');
    } else {
      messages.add('当前没有活跃保养计划，需确认是否存在保养提醒缺口。');
    }

    if (detail.recentRecords.isEmpty) {
      messages.add(
        detail.recentRecordsScopeLimited
            ? '最近记录仅展示当前权限范围内数据，无法直接据此判断是否长期未执行保养。'
            : '最近暂无保养记录，建议确认是否长期未执行点检或保养。',
      );
    } else {
      final latestRecord = detail.recentRecords.first;
      messages.add(
        '最近一次记录为${_formatDate(latestRecord.completedAt)}的“${latestRecord.itemName}”，结果：${latestRecord.resultSummary.isEmpty ? '未填写' : latestRecord.resultSummary}。',
      );
    }
    return messages;
  }

  Widget _buildRiskOverview(EquipmentDetailResult detail) {
    final theme = Theme.of(context);
    final riskMessages = _buildRiskMessages(detail);
    final latestRecord = detail.recentRecords.isEmpty
        ? null
        : detail.recentRecords.first;
    return Card(
      color: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '设备风险提示',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '请先确认待办任务、计划排程与最近执行结果，再进行设备调整。',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.activePlansScopeLimited ||
                detail.pendingWorkOrdersScopeLimited ||
                detail.recentRecordsScopeLimited)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '当前详情仅展示你在计划、执行与记录范围内可见的数据，不能替代全量排程复核。',
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('待执行工单 ${detail.pendingWorkOrderCount}')),
                Chip(label: Text('活跃计划 ${detail.activePlanCount}')),
                Chip(
                  label: Text(
                    latestRecord == null
                        ? '最近记录 暂无'
                        : '最近记录 ${_formatDate(latestRecord.completedAt)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...riskMessages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle, size: 8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(message)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  key: const Key('equipment-detail-shortcut-work-orders'),
                  onPressed: () => _scrollToSection(_workOrdersSectionKey),
                  icon: const Icon(Icons.assignment_late_outlined),
                  label: const Text('查看工单'),
                ),
                OutlinedButton.icon(
                  key: const Key('equipment-detail-shortcut-records'),
                  onPressed: () => _scrollToSection(_recordsSectionKey),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('查看记录'),
                ),
                OutlinedButton.icon(
                  key: const Key('equipment-detail-shortcut-plans'),
                  onPressed: () => _scrollToSection(_plansSectionKey),
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('查看计划'),
                ),
              ],
            ),
          ],
        ),
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
                controller: _scrollController,
                children: [
                  _buildRiskOverview(detail),
                  const SizedBox(height: 16),
                  _row('设备编号', detail.code),
                  _row('设备名称', detail.name),
                  _row('型号', detail.model.isEmpty ? '-' : detail.model),
                  _row('位置', detail.location.isEmpty ? '-' : detail.location),
                  _row(
                    '负责人',
                    detail.ownerName.isEmpty ? '-' : detail.ownerName,
                  ),
                  _row('状态', detail.isEnabled ? '启用' : '停用'),
                  _row('备注', detail.remark.isEmpty ? '-' : detail.remark),
                  _row('启用计划数', '${detail.activePlanCount}'),
                  _row('待执行工单数', '${detail.pendingWorkOrderCount}'),
                  const Divider(height: 24),
                  Text(
                    '关联计划',
                    key: _plansSectionKey,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (detail.activePlans.isEmpty)
                    Text(
                      detail.activePlansScopeLimited
                          ? '当前权限范围内暂无可见启用保养计划'
                          : '暂无启用保养计划',
                    )
                  else
                    ...detail.activePlans.map(
                      (plan) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${plan.itemName} / ${plan.executionProcessName}',
                        ),
                        subtitle: Text(
                          '下次到期：${_formatDate(plan.nextDueDate)}｜默认执行人：${plan.defaultExecutorUsername ?? '-'}',
                        ),
                      ),
                    ),
                  const Divider(height: 24),
                  Text(
                    '未完成工单',
                    key: _workOrdersSectionKey,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (detail.pendingWorkOrders.isEmpty)
                    Text(
                      detail.pendingWorkOrdersScopeLimited
                          ? '当前权限范围内暂无可见未完成工单'
                          : '暂无未完成工单',
                    )
                  else
                    ...detail.pendingWorkOrders.map(
                      (order) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('#${order.id} ${order.itemName}'),
                        subtitle: Text(
                          '工段：${order.sourceExecutionProcessCode ?? '-'}｜到期：${_formatDate(order.dueDate)}｜状态：${order.status}',
                        ),
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
                  Text(
                    '最近保养记录',
                    key: _recordsSectionKey,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (detail.recentRecords.isEmpty)
                    Text(
                      detail.recentRecordsScopeLimited
                          ? '当前权限范围内暂无可见保养记录'
                          : '暂无保养记录',
                    )
                  else
                    ...detail.recentRecords.map(
                      (record) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(record.itemName),
                        subtitle: Text(
                          '完成：${_formatDate(record.completedAt)}｜结果：${record.resultSummary}｜执行人：${record.executorUsername ?? '-'}',
                        ),
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
