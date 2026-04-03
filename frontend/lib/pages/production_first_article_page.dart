import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';

class ProductionFirstArticlePage extends StatefulWidget {
  const ProductionFirstArticlePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.order,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final MyOrderItem order;
  final ProductionService? service;

  @override
  State<ProductionFirstArticlePage> createState() =>
      _ProductionFirstArticlePageState();
}

class _ProductionFirstArticlePageState
    extends State<ProductionFirstArticlePage> {
  late final ProductionService _service;
  late final DateTime _firstArticleTime;
  final TextEditingController _checkContentController = TextEditingController();
  final TextEditingController _testValueController = TextEditingController();
  final TextEditingController _verificationCodeController =
      TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  bool _loading = false;
  bool _submitting = false;
  String _message = '';
  String _result = 'passed';
  FirstArticleTemplateItem? _selectedTemplate;
  List<FirstArticleTemplateItem> _templates = const [];
  List<FirstArticleParticipantOptionItem> _participantOptions = const [];
  List<FirstArticleParticipantOptionItem> _selectedParticipants = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _firstArticleTime = DateTime.now();
    _loadInitialData();
  }

  @override
  void dispose() {
    _checkContentController.dispose();
    _testValueController.dispose();
    _verificationCodeController.dispose();
    _remarkController.dispose();
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final templates = await _service.listFirstArticleTemplates(
        orderId: widget.order.orderId,
        orderProcessId: widget.order.currentProcessId,
      );
      final participants = await _service.listFirstArticleParticipantOptions(
        orderId: widget.order.orderId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _templates = templates.items;
        _participantOptions = participants.items;
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
        _message = '加载首件辅助数据失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectTemplate() async {
    if (_templates.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前工序暂无可用首件模板')));
      return;
    }
    final selected = await showLockedFormDialog<FirstArticleTemplateItem>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择首件模板'),
        content: SizedBox(
          width: 560,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _templates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _templates[index];
              final isSelected = item.id == _selectedTemplate?.id;
              return ListTile(
                selected: isSelected,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                onTap: () => Navigator.of(dialogContext).pop(item),
                title: Text(item.templateName),
                subtitle: Text(
                  '检验内容：${(item.checkContent ?? '').trim().isEmpty ? '-' : item.checkContent}\n'
                  '测试值：${(item.testValue ?? '').trim().isEmpty ? '-' : item.testValue}',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _selectedTemplate = selected;
      _checkContentController.text = selected.checkContent ?? '';
      _testValueController.text = selected.testValue ?? '';
    });
  }

  Future<void> _showParametersDialog() async {
    try {
      final result = await _service.getFirstArticleParameters(
        orderId: widget.order.orderId,
        orderProcessId: widget.order.currentProcessId,
      );
      if (!mounted) {
        return;
      }
      await showLockedFormDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('首件参数查看'),
          content: SizedBox(
            width: 760,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('产品：${result.productName}'),
                Text('参数范围：${result.parameterScope}'),
                Text('版本：${result.versionLabel}'),
                Text('生命周期：${result.lifecycleStatus}'),
                const SizedBox(height: 12),
                Flexible(
                  child: result.items.isEmpty
                      ? const Center(child: Text('暂无参数'))
                      : AdaptiveTableContainer(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('名称')),
                              DataColumn(label: Text('分类')),
                              DataColumn(label: Text('类型')),
                              DataColumn(label: Text('值')),
                              DataColumn(label: Text('说明')),
                            ],
                            rows: result.items.map((item) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(item.name)),
                                  DataCell(Text(item.category)),
                                  DataCell(Text(item.type)),
                                  DataCell(Text(item.value)),
                                  DataCell(Text(item.description)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
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
    }
  }

  Future<void> _selectParticipants() async {
    if (_participantOptions.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可选参与操作员')));
      return;
    }
    final selectedIds = await showLockedFormDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
        final draftIds = _selectedParticipants.map((item) => item.id).toSet();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('添加参与操作员'),
            content: SizedBox(
              width: 560,
              child: ListView(
                shrinkWrap: true,
                children: _participantOptions.map((item) {
                  return CheckboxListTile(
                    value: draftIds.contains(item.id),
                    title: Text(item.displayName),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          draftIds.add(item.id);
                        } else {
                          draftIds.remove(item.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(draftIds),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );
    if (selectedIds == null || !mounted) {
      return;
    }
    final selected = _participantOptions
        .where((item) => selectedIds.contains(item.id))
        .toList();
    setState(() {
      _selectedParticipants = selected;
    });
  }

  Future<void> _submit() async {
    final checkContent = _checkContentController.text.trim();
    final testValue = _testValueController.text.trim();
    final verificationCode = _verificationCodeController.text.trim();
    final remark = _remarkController.text.trim();
    if (checkContent.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入首件内容')));
      return;
    }
    if (testValue.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入首件测试值')));
      return;
    }
    if (verificationCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入首件检验码')));
      return;
    }

    setState(() {
      _submitting = true;
      _message = '';
    });
    try {
      await _service.submitFirstArticle(
        orderId: widget.order.orderId,
        request: FirstArticleSubmitRequestInput(
          orderProcessId: widget.order.currentProcessId,
          pipelineInstanceId: widget.order.pipelineInstanceId,
          templateId: _selectedTemplate?.id,
          checkContent: checkContent,
          testValue: testValue,
          result: _result,
          participantUserIds: _selectedParticipants
              .map((item) => item.id)
              .toList(),
          verificationCode: verificationCode,
          remark: remark.isEmpty ? null : remark,
          effectiveOperatorUserId: widget.order.operatorUserId,
          assistAuthorizationId: widget.order.assistAuthorizationId,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '提交首件失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _buildInfoField(String label, String value) {
    return SizedBox(
      width: 260,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(value.isEmpty ? '-' : value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(title: Text('首件录入 - ${order.orderCode}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _message,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '基础信息',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _buildInfoField('产品型号', order.productName),
                                    _buildInfoField(
                                      '所属工序',
                                      order.currentProcessName,
                                    ),
                                    _buildInfoField(
                                      '首件时间',
                                      _formatDateTime(_firstArticleTime),
                                    ),
                                    _buildInfoField(
                                      '当前操作员',
                                      order.operatorUsername ?? '-',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _selectTemplate,
                                      icon: const Icon(
                                        Icons.description_outlined,
                                      ),
                                      label: Text(
                                        _selectedTemplate == null
                                            ? '首件模板'
                                            : '模板：${_selectedTemplate!.templateName}',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _showParametersDialog,
                                      icon: const Icon(Icons.tune_outlined),
                                      label: const Text('查看参数'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _selectParticipants,
                                      icon: const Icon(
                                        Icons.group_add_outlined,
                                      ),
                                      label: const Text('添加操作员'),
                                    ),
                                  ],
                                ),
                                if (_selectedParticipants.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _selectedParticipants.map((item) {
                                      return Chip(
                                        label: Text(item.displayName),
                                        onDeleted: () {
                                          setState(() {
                                            _selectedParticipants =
                                                _selectedParticipants
                                                    .where(
                                                      (entry) =>
                                                          entry.id != item.id,
                                                    )
                                                    .toList();
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '检验内容',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _checkContentController,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: '首件内容',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _testValueController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: '首件测试值',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '检验结果',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment<String>(
                                      value: 'passed',
                                      label: Text('合格'),
                                    ),
                                    ButtonSegment<String>(
                                      value: 'failed',
                                      label: Text('不合格'),
                                    ),
                                  ],
                                  selected: {_result},
                                  onSelectionChanged: (selection) {
                                    setState(() {
                                      _result = selection.first;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _verificationCodeController,
                                  decoration: const InputDecoration(
                                    labelText: '首件检验码',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _remarkController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: '备注',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('取消首件'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _submitting ? null : _submit,
                              child: Text(_submitting ? '提交中...' : '提交首件'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
