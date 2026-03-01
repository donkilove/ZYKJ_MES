import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';

class MaintenanceExecutionPage extends StatefulWidget {
  const MaintenanceExecutionPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canExecute,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExecute;

  @override
  State<MaintenanceExecutionPage> createState() => _MaintenanceExecutionPageState();
}

class _MaintenanceExecutionPageState extends State<MaintenanceExecutionPage> {
  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<MaintenanceWorkOrderItem> _items = const [];

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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  Future<void> _loadItems() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _equipmentService.listExecutions(
        page: 1,
        pageSize: 200,
        keyword: _keywordController.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已开始执行')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始执行失败：${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _completeExecution(MaintenanceWorkOrderItem item) async {
    if (!mounted) {
      return;
    }
    final pageContext = context;
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedSummary = '完成';

    final confirmed = await showDialog<bool>(
      context: pageContext,
      barrierDismissible: false,
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
      remarkController.dispose();
      return;
    }

    try {
      await _equipmentService.completeExecution(
        workOrderId: item.id,
        resultSummary: selectedSummary,
        resultRemark: selectedSummary == '失败' ? remarkController.text.trim() : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已完成执行')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('完成执行失败：${_errorMessage(error)}')),
      );
    } finally {
      remarkController.dispose();
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
                '保养执行',
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
              FilledButton.icon(
                onPressed: _loading ? null : _loadItems,
                icon: const Icon(Icons.search),
                label: const Text('查询'),
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
                ? const Center(child: Text('暂无执行单'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('设备')),
                          DataColumn(label: Text('项目')),
                          DataColumn(label: Text('到期日期')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('执行人')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          final canStart = widget.canExecute &&
                              (item.status == 'pending' || item.status == 'overdue');
                          final canComplete = widget.canExecute && item.status == 'in_progress';
                          return DataRow(
                            cells: [
                              DataCell(Text(item.equipmentName)),
                              DataCell(Text(item.itemName)),
                              DataCell(Text(_formatDate(item.dueDate))),
                              DataCell(Text(_statusLabel(item.status))),
                              DataCell(Text(item.executorUsername ?? '-')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: canStart ? () => _startExecution(item) : null,
                                      child: const Text('开始执行'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: canComplete ? () => _completeExecution(item) : null,
                                      child: const Text('完成执行'),
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
          ),
        ],
      ),
    );
  }
}
