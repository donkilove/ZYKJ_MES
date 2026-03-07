import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';

class ProductionAssistApprovalPage extends StatefulWidget {
  const ProductionAssistApprovalPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canReview,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canReview;

  @override
  State<ProductionAssistApprovalPage> createState() =>
      _ProductionAssistApprovalPageState();
}

class _ProductionAssistApprovalPageState
    extends State<ProductionAssistApprovalPage> {
  late final ProductionService _service;

  bool _loading = false;
  bool _acting = false;
  String _message = '';
  String _statusFilter = 'pending';
  int _total = 0;
  List<AssistAuthorizationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _service = ProductionService(widget.session);
    _loadRows();
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  Future<void> _loadRows() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.listAssistAuthorizations(
        page: 1,
        pageSize: 200,
        status: _statusFilter,
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
        _message = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reviewItem(AssistAuthorizationItem item, bool approve) async {
    if (!widget.canReview || item.status != 'pending') {
      return;
    }
    final remarkController = TextEditingController();
    try {
      final confirmed = await showLockedFormDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(approve ? '通过代班申请' : '拒绝代班申请'),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: remarkController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '审批备注（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确认'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }

      setState(() {
        _acting = true;
      });
      try {
        await _service.reviewAssistAuthorization(
          authorizationId: item.id,
          approve: approve,
          reviewRemark: remarkController.text.trim().isEmpty
              ? null
              : remarkController.text.trim(),
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? '审批通过' : '已拒绝申请')),
        );
        await _loadRows();
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
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      } finally {
        if (mounted) {
          setState(() {
            _acting = false;
          });
        }
      }
    } finally {
      remarkController.dispose();
    }
  }

  Widget _buildActionCell(AssistAuthorizationItem item) {
    if (!widget.canReview || item.status != 'pending') {
      return const Text('-');
    }
    final disabled = _acting || _loading;
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: disabled ? null : () => _reviewItem(item, false),
          child: const Text('拒绝'),
        ),
        FilledButton(
          onPressed: disabled ? null : () => _reviewItem(item, true),
          child: const Text('通过'),
        ),
      ],
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
                '代班审批',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: '状态筛选',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('待审批')),
                    DropdownMenuItem(value: 'approved', child: Text('已通过')),
                    DropdownMenuItem(value: 'rejected', child: Text('已拒绝')),
                    DropdownMenuItem(value: 'consumed', child: Text('已消耗')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null || value == _statusFilter) {
                            return;
                          }
                          setState(() {
                            _statusFilter = value;
                          });
                          _loadRows();
                        },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadRows,
                icon: const Icon(Icons.refresh),
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
          if (!widget.canReview)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '当前账号无审批权限',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('暂无代班申请'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('订单号')),
                          DataColumn(label: Text('工序')),
                          DataColumn(label: Text('目标操作员')),
                          DataColumn(label: Text('申请人')),
                          DataColumn(label: Text('代班人')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('申请时间')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.orderCode)),
                              DataCell(Text(item.processName)),
                              DataCell(Text(item.targetOperatorUsername)),
                              DataCell(Text(item.requesterUsername)),
                              DataCell(Text(item.helperUsername)),
                              DataCell(
                                Text(assistAuthorizationStatusLabel(item.status)),
                              ),
                              DataCell(Text(_formatDateTime(item.createdAt))),
                              DataCell(_buildActionCell(item)),
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
