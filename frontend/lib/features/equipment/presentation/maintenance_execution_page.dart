import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_execution_detail_page.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/core/widgets/simple_pagination_bar.dart';

class MaintenanceExecutionPage extends StatefulWidget {
  const MaintenanceExecutionPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canExecute,
    this.jumpPayloadJson,
    this.equipmentService,
    this.craftService,
    this.detailPageBuilder,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExecute;
  final String? jumpPayloadJson;
  final EquipmentService? equipmentService;
  final CraftService? craftService;
  final Widget Function(BuildContext context, int workOrderId)?
  detailPageBuilder;

  @override
  State<MaintenanceExecutionPage> createState() =>
      _MaintenanceExecutionPageState();
}

class _MaintenanceExecutionPageState extends State<MaintenanceExecutionPage> {
  static const int _pageSize = 30;

  late final EquipmentService _equipmentService;
  late final CraftService _craftService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  int _page = 1;
  List<MaintenanceWorkOrderItem> _items = const [];
  String? _statusFilter;
  bool _mineOnly = false;
  DateTime? _dueDateStart;
  DateTime? _dueDateEnd;
  String? _stageCodeFilter;
  List<CraftStageItem> _stages = const [];
  String? _lastHandledJumpPayloadJson;

  @override
  void initState() {
    super.initState();
    _equipmentService =
        widget.equipmentService ?? EquipmentService(widget.session);
    _craftService = widget.craftService ?? CraftService(widget.session);
    _loadStages();
    _loadItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeJumpPayload(widget.jumpPayloadJson);
    });
  }

  @override
  void didUpdateWidget(covariant MaintenanceExecutionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jumpPayloadJson != oldWidget.jumpPayloadJson) {
      _consumeJumpPayload(widget.jumpPayloadJson);
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadStages() async {
    try {
      final result = await _craftService.listStages(enabled: true);
      if (mounted) {
        setState(() => _stages = result.items);
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

  Widget _buildStageDropdownText(String text) {
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  int get _totalPages {
    final pages = (_total + _pageSize - 1) ~/ _pageSize;
    return pages > 0 ? pages : 1;
  }

  Future<DateTime?> _pickDate({required DateTime initialDate}) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
  }

  Future<void> _loadItems({int? page}) async {
    final targetPage = page ?? _page;
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _equipmentService.listExecutions(
        page: targetPage,
        pageSize: _pageSize,
        keyword: _keywordController.text.trim(),
        status: _statusFilter,
        mineOnly: _mineOnly,
        dueDateStart: _dueDateStart,
        dueDateEnd: _dueDateEnd,
        stageCode: _stageCodeFilter,
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
        _message = '加载保养执行失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _startExecution(MaintenanceWorkOrderItem item) async {
    try {
      await _equipmentService.startExecution(workOrderId: item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已开始执行')));
      }
      await _loadItems();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('开始执行失败：${_errorMessage(error)}')));
    }
  }

  Future<void> _completeExecution(MaintenanceWorkOrderItem item) async {
    if (!mounted) {
      return;
    }
    final pageContext = context;
    final remarkController = TextEditingController();
    final attachmentController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedSummary = '完成';

    final confirmed = await showMesLockedFormDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogBuildContext, setDialogState) {
            final needExceptionReport = selectedSummary == '失败';
            return AlertDialog(
              title: const Text('完成保养执行'),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedSummary,
                          decoration: const InputDecoration(
                            labelText: '结果摘要',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem<String>(
                              value: '完成',
                              child: Text('完成'),
                            ),
                            DropdownMenuItem<String>(
                              value: '失败',
                              child: Text('失败'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              selectedSummary = value;
                              if (selectedSummary != '失败') {
                                remarkController.clear();
                              }
                            });
                          },
                        ),
                        if (needExceptionReport) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: remarkController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: '异常上报',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (selectedSummary == '失败' &&
                                  (value == null || value.trim().isEmpty)) {
                                return '结果摘要为失败时必须填写异常上报';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: attachmentController,
                          decoration: const InputDecoration(
                            labelText: '附件地址（可选，支持下载链接或 UNC 路径）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogBuildContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    Navigator.of(dialogBuildContext).pop(true);
                  },
                  child: const Text('提交'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        remarkController.dispose();
        attachmentController.dispose();
      });
      return;
    }

    try {
      await _equipmentService.completeExecution(
        workOrderId: item.id,
        resultSummary: selectedSummary,
        resultRemark: selectedSummary == '失败'
            ? remarkController.text.trim()
            : null,
        attachmentLink: attachmentController.text.trim().isEmpty
            ? null
            : attachmentController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已完成执行')));
      }
      await _loadItems();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('完成执行失败：${_errorMessage(error)}')));
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        remarkController.dispose();
        attachmentController.dispose();
      });
    }
  }

  Future<void> _cancelExecution(MaintenanceWorkOrderItem item) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消工单'),
        content: Text('确认取消工单"${item.equipmentName} / ${item.itemName}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _equipmentService.cancelExecution(workOrderId: item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('工单已取消')));
      }
      await _loadItems();
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('取消工单失败：${_errorMessage(error)}')));
    }
  }

  Future<void> _showDetail(MaintenanceWorkOrderItem item) async {
    await _showDetailById(item.id);
  }

  Future<void> _showDetailById(int workOrderId) async {
    final detailPage =
        widget.detailPageBuilder?.call(context, workOrderId) ??
        MaintenanceExecutionDetailPage(
          session: widget.session,
          onLogout: widget.onLogout,
          workOrderId: workOrderId,
          service: _equipmentService,
        );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => detailPage));
  }

  void _consumeJumpPayload(String? rawPayload) {
    if (!mounted ||
        rawPayload == null ||
        rawPayload.trim().isEmpty ||
        rawPayload == _lastHandledJumpPayloadJson) {
      return;
    }
    try {
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      final dashboardFilter =
          (payload['dashboard_filter'] as String? ?? '').trim();
      if (dashboardFilter == 'overdue') {
        _lastHandledJumpPayloadJson = rawPayload;
        setState(() {
          _statusFilter = 'overdue';
          _page = 1;
        });
        _loadItems(page: 1);
        return;
      }
      final action = (payload['action'] as String? ?? '').trim();
      final rawWorkOrderId = payload['work_order_id'];
      final workOrderId = rawWorkOrderId is int
          ? rawWorkOrderId
          : int.tryParse('${rawWorkOrderId ?? ''}');
      if (action != 'detail' || workOrderId == null || workOrderId <= 0) {
        return;
      }
      _lastHandledJumpPayloadJson = rawPayload;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showDetailById(workOrderId);
      });
    } catch (_) {}
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
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
              Expanded(
                child: CrudPageHeader(
                  title: '保养执行',
                  onRefresh: _loading ? null : () => _loadItems(page: _page),
                ),
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
                  onSubmitted: (_) => _loadItems(page: 1),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickDate(
                    initialDate: _dueDateStart ?? DateTime.now(),
                  );
                  if (!mounted) return;
                  if (picked != null) setState(() => _dueDateStart = picked);
                },
                icon: const Icon(Icons.event),
                label: Text(
                  _dueDateStart == null ? '到期开始' : _formatDate(_dueDateStart!),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickDate(
                    initialDate: _dueDateEnd ?? DateTime.now(),
                  );
                  if (!mounted) return;
                  if (picked != null) setState(() => _dueDateEnd = picked);
                },
                icon: const Icon(Icons.event_available),
                label: Text(
                  _dueDateEnd == null ? '到期结束' : _formatDate(_dueDateEnd!),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : () => _loadItems(page: 1),
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String?>(
                  initialValue: _statusFilter,
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('全部状态')),
                    DropdownMenuItem<String?>(
                      value: 'pending',
                      child: Text('待执行'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'in_progress',
                      child: Text('执行中'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'overdue',
                      child: Text('已逾期'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'done',
                      child: Text('已完成'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'cancelled',
                      child: Text('已取消'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                  },
                  decoration: const InputDecoration(
                    labelText: '状态',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_stages.isNotEmpty)
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _stageCodeFilter,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          '全部工段',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ..._stages.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.code,
                          child: _buildStageDropdownText(s.name),
                        ),
                      ),
                    ],
                    selectedItemBuilder: (context) {
                      return [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStageDropdownText('全部工段'),
                        ),
                        ..._stages.map(
                          (s) => Align(
                            alignment: Alignment.centerLeft,
                            child: _buildStageDropdownText(s.name),
                          ),
                        ),
                      ];
                    },
                    onChanged: (value) {
                      setState(() => _stageCodeFilter = value);
                    },
                    decoration: const InputDecoration(
                      labelText: '工段',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Row(
                children: [
                  const Text('仅看我的任务'),
                  Switch(
                    value: _mineOnly,
                    onChanged: (v) => setState(() => _mineOnly = v),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              if (_dueDateStart != null ||
                  _dueDateEnd != null ||
                  _stageCodeFilter != null)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _dueDateStart = null;
                            _dueDateEnd = null;
                            _stageCodeFilter = null;
                          });
                          _loadItems(page: 1);
                        },
                  child: const Text('清空筛选'),
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
            child: CrudListTableSection(
              loading: _loading,
              isEmpty: _items.isEmpty,
              emptyText: '暂无执行单',
              enableUnifiedHeaderStyle: true,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('工单编号')),
                  DataColumn(label: Text('设备')),
                  DataColumn(label: Text('项目')),
                  DataColumn(label: Text('到期日期')),
                  DataColumn(label: Text('状态')),
                  DataColumn(label: Text('执行人')),
                  DataColumn(label: Text('开始时间')),
                  DataColumn(label: Text('完成时间')),
                  DataColumn(label: Text('结果摘要')),
                  DataColumn(label: Text('操作')),
                ],
                rows: _items.map((item) {
                  final canStart =
                      widget.canExecute &&
                      (item.status == 'pending' || item.status == 'overdue');
                  final canComplete =
                      widget.canExecute && item.status == 'in_progress';
                  final canCancel =
                      widget.canExecute &&
                      (item.status == 'pending' ||
                          item.status == 'overdue' ||
                          item.status == 'in_progress');
                  return DataRow(
                    cells: [
                      DataCell(Text('#${item.id}')),
                      DataCell(Text(item.equipmentName)),
                      DataCell(Text(item.itemName)),
                      DataCell(Text(_formatDate(item.dueDate))),
                      DataCell(Text(_statusLabel(item.status))),
                      DataCell(Text(item.executorUsername ?? '-')),
                      DataCell(
                        Text(
                          item.startedAt != null
                              ? _formatDateTime(item.startedAt!)
                              : '-',
                        ),
                      ),
                      DataCell(
                        Text(
                          item.completedAt != null
                              ? _formatDateTime(item.completedAt!)
                              : '-',
                        ),
                      ),
                      DataCell(Text(item.resultSummary ?? '-')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              key: Key(
                                'maintenance-execution-start-${item.id}',
                              ),
                              onPressed: canStart
                                  ? () => _startExecution(item)
                                  : null,
                              child: const Text('开始执行'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              key: Key(
                                'maintenance-execution-complete-${item.id}',
                              ),
                              onPressed: canComplete
                                  ? () => _completeExecution(item)
                                  : null,
                              child: const Text('完成执行'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              key: Key(
                                'maintenance-execution-cancel-${item.id}',
                              ),
                              onPressed: canCancel
                                  ? () => _cancelExecution(item)
                                  : null,
                              child: const Text('取消'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              key: Key(
                                'maintenance-execution-detail-${item.id}',
                              ),
                              onPressed: () => _showDetail(item),
                              child: const Text('详情'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SimplePaginationBar(
            page: _page,
            totalPages: _totalPages,
            total: _total,
            loading: _loading,
            onPrevious: () => _loadItems(page: _page - 1),
            onNext: () => _loadItems(page: _page + 1),
          ),
        ],
      ),
    );
  }
}
