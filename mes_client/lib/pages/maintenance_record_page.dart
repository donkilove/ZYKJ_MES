import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';

class MaintenanceRecordPage extends StatefulWidget {
  const MaintenanceRecordPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<MaintenanceRecordPage> createState() => _MaintenanceRecordPageState();
}

class _MaintenanceRecordPageState extends State<MaintenanceRecordPage> {
  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<MaintenanceRecordItem> _items = const [];
  DateTime? _startDate;
  DateTime? _endDate;
  String? _resultSummaryFilter;

  @override
  void initState() {
    super.initState();
    _equipmentService = EquipmentService(widget.session);
    _loadItems();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
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
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000, 1, 1),
      lastDate: lastDate ?? DateTime(2100, 12, 31),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _equipmentService.listRecords(
        page: 1,
        pageSize: 200,
        keyword: _keywordController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        resultSummary: _resultSummaryFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = result.items;
        _total = result.total;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载保养记录失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showDetail(MaintenanceRecordItem item) async {
    if (!mounted) return;
    setState(() => _loading = true);
    MaintenanceRecordDetail? detail;
    try {
      detail = await _equipmentService.getRecordDetail(recordId: item.id);
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载详情失败：${_errorMessage(error)}')),
      );
      setState(() => _loading = false);
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('保养记录详情 #${detail!.id}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('设备', detail.equipmentName),
                if (detail.sourceEquipmentCode != null)
                  _detailRow('设备编号', detail.sourceEquipmentCode!),
                _detailRow('项目', detail.itemName),
                _detailRow('到期日期', _formatDate(detail.dueDate)),
                _detailRow('完成时间', _formatDateTime(detail.completedAt)),
                _detailRow('执行人', detail.executorUsername ?? '-'),
                _detailRow('结果摘要', detail.resultSummary),
                if (detail.resultRemark != null)
                  _detailRow('备注', detail.resultRemark!),
                if (detail.attachmentLink != null)
                  _detailRow('附件链接', detail.attachmentLink!),
                if (detail.sourcePlanCycleDays != null)
                  _detailRow('计划周期(天)', '${detail.sourcePlanCycleDays}'),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label：', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '保养记录',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadItems,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '搜索设备/项目/结果',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadItems(),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickDate(
                    initialDate: _startDate ?? DateTime.now(),
                  );
                  if (!mounted) {
                    return;
                  }
                  if (picked != null) {
                    setState(() {
                      _startDate = picked;
                    });
                  }
                },
                icon: const Icon(Icons.event),
                label: Text(
                  _startDate == null ? '开始日期' : _formatDate(_startDate!),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickDate(
                    initialDate: _endDate ?? DateTime.now(),
                  );
                  if (!mounted) {
                    return;
                  }
                  if (picked != null) {
                    setState(() {
                      _endDate = picked;
                    });
                  }
                },
                icon: const Icon(Icons.event_available),
                label: Text(_endDate == null ? '结束日期' : _formatDate(_endDate!)),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _loadItems,
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        _loadItems();
                      },
                child: const Text('清空日期'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String?>(
                  initialValue: _resultSummaryFilter,
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('全部结果')),
                    DropdownMenuItem<String?>(value: '完成', child: Text('完成')),
                    DropdownMenuItem<String?>(value: '失败', child: Text('失败')),
                  ],
                  onChanged: (value) {
                    setState(() => _resultSummaryFilter = value);
                  },
                  decoration: const InputDecoration(
                    labelText: '结果',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('总数：$_total', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('暂无保养记录'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('完成时间')),
                          DataColumn(label: Text('设备')),
                          DataColumn(label: Text('项目')),
                          DataColumn(label: Text('执行人')),
                          DataColumn(label: Text('结果摘要')),
                          DataColumn(label: Text('备注')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(_formatDateTime(item.completedAt)),
                              ),
                              DataCell(Text(item.equipmentName)),
                              DataCell(Text(item.itemName)),
                              DataCell(Text(item.executorUsername ?? '-')),
                              DataCell(Text(item.resultSummary)),
                              DataCell(Text(item.resultRemark ?? '-')),
                              DataCell(
                                TextButton(
                                  onPressed: () => _showDetail(item),
                                  child: const Text('详情'),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
