import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import 'maintenance_record_detail_page.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';

class MaintenanceRecordPage extends StatefulWidget {
  const MaintenanceRecordPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.equipmentService,
    this.onOpenAttachment,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final EquipmentService? equipmentService;
  final MaintenanceAttachmentOpenCallback? onOpenAttachment;

  @override
  State<MaintenanceRecordPage> createState() => _MaintenanceRecordPageState();
}

class _MaintenanceRecordPageState extends State<MaintenanceRecordPage> {
  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String _message = '';
  int _total = 0;
  List<MaintenanceRecordItem> _items = const [];
  DateTime? _startDate;
  DateTime? _endDate;
  String? _resultSummaryFilter;
  List<EquipmentLedgerItem> _equipmentList = const [];
  List<EquipmentOwnerOption> _ownerOptions = const [];
  int? _equipmentIdFilter;
  int? _executorIdFilter;

  @override
  void initState() {
    super.initState();
    _equipmentService =
        widget.equipmentService ?? EquipmentService(widget.session);
    _loadEquipmentList();
    _loadItems();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadEquipmentList() async {
    try {
      final result = await _equipmentService.listEquipment(
        page: 1,
        pageSize: 500,
      );
      final owners = await _equipmentService.listAllOwners();
      if (mounted) {
        setState(() {
          _equipmentList = result.items;
          _ownerOptions = owners;
        });
      }
    } catch (_) {}
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
      final keyword = _keywordController.text.trim().isNotEmpty
          ? _keywordController.text.trim()
          : null;
      final result = await _equipmentService.listRecords(
        page: 1,
        pageSize: 200,
        keyword: keyword,
        executorId: _executorIdFilter,
        startDate: _startDate,
        endDate: _endDate,
        resultSummary: _resultSummaryFilter,
        equipmentId: _equipmentIdFilter,
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaintenanceRecordDetailPage(
          session: widget.session,
          onLogout: widget.onLogout,
          recordId: item.id,
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final csvBase64 = await _equipmentService.exportMaintenanceRecords(
        keyword: _keywordController.text.trim().isNotEmpty
            ? _keywordController.text.trim()
            : null,
        executorId: _executorIdFilter,
        startDate: _startDate,
        endDate: _endDate,
        resultSummary: _resultSummaryFilter,
        equipmentId: _equipmentIdFilter,
      );
      if (!mounted) return;
      if (csvBase64.isEmpty) {
        setState(() => _message = '导出失败：服务端返回空数据');
        return;
      }
      final bytes = base64Decode(csvBase64);
      final location = await getSaveLocation(
        suggestedName: 'maintenance_records.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) return;
      await XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: 'maintenance_records.csv',
      ).saveTo(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出成功：${location.path}')));
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() => _message = '导出失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton.icon(
                  onPressed: (_loading || _exporting) ? null : _exportCsv,
                  icon: const Icon(Icons.download),
                  label: const Text('导出'),
                ),
              ),
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
              if (_ownerOptions.isNotEmpty)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _executorIdFilter,
                    decoration: const InputDecoration(
                      labelText: '执行人',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('全部执行人'),
                      ),
                      ..._ownerOptions.map(
                        (owner) => DropdownMenuItem<int?>(
                          value: owner.userId,
                          child: Text(owner.displayName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _executorIdFilter = value);
                    },
                  ),
                ),
              if (_ownerOptions.isNotEmpty) const SizedBox(width: 12),
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
                          _executorIdFilter = null;
                          _equipmentIdFilter = null;
                          _resultSummaryFilter = null;
                        });
                        _loadItems();
                      },
                child: const Text('清空筛选'),
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
              if (_equipmentList.isNotEmpty) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _equipmentIdFilter,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('全部设备'),
                      ),
                      ..._equipmentList.map(
                        (e) => DropdownMenuItem<int?>(
                          value: e.id,
                          child: Text(e.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _equipmentIdFilter = value);
                    },
                    decoration: const InputDecoration(
                      labelText: '设备',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
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
                          DataColumn(label: Text('记录编号')),
                          DataColumn(label: Text('工单编号')),
                          DataColumn(label: Text('设备')),
                          DataColumn(label: Text('项目')),
                          DataColumn(label: Text('到期日期')),
                          DataColumn(label: Text('执行人')),
                          DataColumn(label: Text('完成时间')),
                          DataColumn(label: Text('结果摘要')),
                          DataColumn(label: Text('备注')),
                          DataColumn(label: Text('附件')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text('#${item.id}')),
                              DataCell(Text('#${item.workOrderId}')),
                              DataCell(Text(item.equipmentName)),
                              DataCell(Text(item.itemName)),
                              DataCell(Text(_formatDate(item.dueDate))),
                              DataCell(Text(item.executorUsername ?? '-')),
                              DataCell(Text(_formatDateTime(item.completedAt))),
                              DataCell(Text(item.resultSummary)),
                              DataCell(Text(item.resultRemark ?? '-')),
                              DataCell(
                                MaintenanceAttachmentAction(
                                  attachmentLink: item.attachmentLink,
                                  onOpen: widget.onOpenAttachment,
                                ),
                              ),
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
