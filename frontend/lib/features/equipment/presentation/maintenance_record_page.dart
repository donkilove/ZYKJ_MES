import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_record_detail_page.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';

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
  static const int _pageSize = 30;

  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  int _page = 1;
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
      final results = await Future.wait<Object>([
        _equipmentService.listEquipment(page: 1, pageSize: 500),
        _equipmentService.listAllOwners(),
      ]);
      final result = results[0] as EquipmentLedgerListResult;
      final owners = results[1] as List<EquipmentOwnerOption>;
      if (mounted) {
        setState(() {
          _equipmentList = result.items;
          _ownerOptions = owners;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载保养记录筛选项失败：${_errorMessage(error)}';
      });
    }
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

  int get _totalPages {
    final pages = (_total + _pageSize - 1) ~/ _pageSize;
    return pages > 0 ? pages : 1;
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

  Future<void> _loadItems({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final keyword = _keywordController.text.trim().isNotEmpty
          ? _keywordController.text.trim()
          : null;
      final result = await _equipmentService.listRecords(
        page: targetPage,
        pageSize: _pageSize,
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
        _page = targetPage;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtersToolbar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索设备/项目/结果',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _loadItems(page: 1),
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
              onPressed: _loading ? null : () => _loadItems(page: 1),
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
                      _loadItems(page: 1);
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
      ],
    );

    return MesCrudPageScaffold(
      header: MesRefreshPageHeader(
        title: '保养记录',
        onRefresh: _loading ? null : () => _loadItems(page: _page),
      ),
      filters: filtersToolbar,
      banner: _message.isEmpty
          ? null
          : Text(
              _message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
      content: CrudListTableSection(
        loading: _loading,
        isEmpty: _items.isEmpty,
        emptyText: '暂无保养记录',
        enableUnifiedHeaderStyle: true,
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
                    attachmentName: item.attachmentName,
                    onOpen: widget.onOpenAttachment,
                    showAttachmentName: false,
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
      pagination: MesPaginationBar(
        page: _page,
        totalPages: _totalPages,
        total: _total,
        loading: _loading,
        onPrevious: () => _loadItems(page: _page - 1),
        onNext: () => _loadItems(page: _page + 1),
      ),
    );
  }
}
