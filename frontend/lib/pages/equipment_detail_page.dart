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
  static const double _desktopBreakpoint = 1200;

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

  Widget _metricTile(String label, String value, IconData icon) {
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
                    fontSize: 22,
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
    required Widget child,
    Key? sectionKey,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          key: sectionKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryWorkbench(EquipmentDetailResult detail) {
    final latestRecord = detail.recentRecords.isEmpty
        ? null
        : detail.recentRecords.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 320,
                    maxWidth: 520,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('编号 ${detail.code}')),
                          Chip(
                            label: Text(
                              detail.isEnabled ? '设备状态 启用' : '设备状态 停用',
                            ),
                          ),
                          Chip(
                            label: Text(
                              '位置 ${detail.location.isEmpty ? '-' : detail.location}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _metricTile(
                  '启用计划数',
                  '${detail.activePlanCount}',
                  Icons.event_note_outlined,
                ),
                _metricTile(
                  '待执行工单数',
                  '${detail.pendingWorkOrderCount}',
                  Icons.assignment_late_outlined,
                ),
                _metricTile(
                  '最近保养时间',
                  latestRecord == null
                      ? '暂无'
                      : _formatDate(latestRecord.completedAt),
                  Icons.fact_check_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
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

  Widget _buildBasicInfoCard(EquipmentDetailResult detail) {
    final rows = [
      _row('设备编号', detail.code),
      _row('设备名称', detail.name),
      _row('型号', detail.model.isEmpty ? '-' : detail.model),
      _row('位置', detail.location.isEmpty ? '-' : detail.location),
      _row('负责人', detail.ownerName.isEmpty ? '-' : detail.ownerName),
      _row('状态', detail.isEnabled ? '启用' : '停用'),
      _row('创建时间', _formatDate(detail.createdAt)),
      _row('更新时间', _formatDate(detail.updatedAt)),
      _row('备注', detail.remark.isEmpty ? '-' : detail.remark),
    ];
    return _sectionCard(
      title: '基础信息',
      subtitle: '保留原业务字段，只调整为桌面详情卡布局。',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          if (!wide) {
            return Column(children: rows);
          }
          return Wrap(
            spacing: 24,
            runSpacing: 0,
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
    );
  }

  Widget _buildPlanList(EquipmentDetailResult detail) {
    if (detail.activePlans.isEmpty) {
      return Text(
        detail.activePlansScopeLimited ? '当前权限范围内暂无可见启用保养计划' : '暂无启用保养计划',
      );
    }
    return Column(
      children: detail.activePlans
          .map(
            (plan) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: ListTile(
                title: Text('${plan.itemName} / ${plan.executionProcessName}'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '下次到期：${_formatDate(plan.nextDueDate)}｜默认执行人：${plan.defaultExecutorUsername ?? '-'}',
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildWorkOrderList(EquipmentDetailResult detail) {
    if (detail.pendingWorkOrders.isEmpty) {
      return Text(
        detail.pendingWorkOrdersScopeLimited ? '当前权限范围内暂无可见未完成工单' : '暂无未完成工单',
      );
    }
    return Column(
      children: detail.pendingWorkOrders
          .map(
            (order) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: ListTile(
                title: Text('#${order.id} ${order.itemName}'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '工段：${order.sourceExecutionProcessCode ?? '-'}｜到期：${_formatDate(order.dueDate)}｜状态：${order.status}',
                  ),
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
          )
          .toList(),
    );
  }

  Widget _buildRecordList(EquipmentDetailResult detail) {
    if (detail.recentRecords.isEmpty) {
      return Text(
        detail.recentRecordsScopeLimited ? '当前权限范围内暂无可见保养记录' : '暂无保养记录',
      );
    }
    return Column(
      children: detail.recentRecords
          .map(
            (record) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: ListTile(
                title: Text(record.itemName),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '完成：${_formatDate(record.completedAt)}｜结果：${record.resultSummary}｜执行人：${record.executorUsername ?? '-'}',
                  ),
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
          )
          .toList(),
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
                child: const Text('当前详情仅展示你在计划、执行与记录范围内可见的数据，不能替代全量排程复核。'),
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
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
                final riskCard = _buildRiskOverview(detail);
                final basicInfoCard = _buildBasicInfoCard(detail);
                final plansCard = _sectionCard(
                  title: '关联计划',
                  sectionKey: _plansSectionKey,
                  subtitle: '保留原有查看口径，强化桌面场景的摘要式浏览。',
                  child: _buildPlanList(detail),
                );
                final workOrdersCard = _sectionCard(
                  title: '未完成工单',
                  sectionKey: _workOrdersSectionKey,
                  child: _buildWorkOrderList(detail),
                );
                final recordsCard = _sectionCard(
                  title: '最近保养记录',
                  sectionKey: _recordsSectionKey,
                  child: _buildRecordList(detail),
                );

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      _buildSummaryWorkbench(detail),
                      const SizedBox(height: 16),
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: basicInfoCard),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: riskCard),
                          ],
                        )
                      else ...[
                        basicInfoCard,
                        const SizedBox(height: 16),
                        riskCard,
                      ],
                      const SizedBox(height: 16),
                      plansCard,
                      const SizedBox(height: 16),
                      workOrdersCard,
                      const SizedBox(height: 16),
                      recordsCard,
                    ],
                  ),
                );
              },
            ),
    );
  }
}
