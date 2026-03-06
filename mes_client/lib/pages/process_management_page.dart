import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../widgets/locked_form_dialog.dart';

enum _StageAction { edit, toggle, delete }

enum _ProcessAction { edit, toggle, delete }

class ProcessManagementPage extends StatefulWidget {
  const ProcessManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<ProcessManagementPage> createState() => _ProcessManagementPageState();
}

class _ProcessManagementPageState extends State<ProcessManagementPage> {
  late final CraftService _service;

  bool _loading = false;
  String _message = '';
  List<CraftStageItem> _stages = const [];
  List<CraftProcessItem> _processes = const [];

  @override
  void initState() {
    super.initState();
    _service = CraftService(widget.session);
    _loadData();
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

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final stageResult = await _service.listStages(
        pageSize: 500,
        enabled: null,
      );
      final processResult = await _service.listProcesses(
        pageSize: 500,
        enabled: null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _stages = [...stageResult.items]
          ..sort((a, b) {
            final orderCompare = a.sortOrder.compareTo(b.sortOrder);
            if (orderCompare != 0) {
              return orderCompare;
            }
            return a.id.compareTo(b.id);
          });
        final stageSortOrderById = <int, int>{
          for (final item in _stages) item.id: item.sortOrder,
        };
        const missingStageSortOrder = 1 << 30;
        _processes = [...processResult.items]
          ..sort((a, b) {
            final stageOrderCompare =
                (stageSortOrderById[a.stageId] ?? missingStageSortOrder)
                    .compareTo(
                      stageSortOrderById[b.stageId] ?? missingStageSortOrder,
                    );
            if (stageOrderCompare != 0) {
              return stageOrderCompare;
            }
            final codeCompare = a.code.compareTo(b.code);
            if (codeCompare != 0) {
              return codeCompare;
            }
            return a.id.compareTo(b.id);
          });
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
        _message = '加载工艺数据失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showStageDialog({CraftStageItem? existing}) async {
    final isEdit = existing != null;
    final codeController = TextEditingController(text: existing?.code ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final sortController = TextEditingController(
      text: (existing?.sortOrder ?? 0).toString(),
    );
    bool isEnabled = existing?.isEnabled ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? '编辑工段' : '新增工段'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: '工段编码',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入工段编码';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '工段名称',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入工段名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: sortController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '排序',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (int.tryParse(value?.trim() ?? '') == null) {
                            return '排序必须为数字';
                          }
                          return null;
                        },
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('启用'),
                          value: isEnabled,
                          onChanged: (value) {
                            setDialogState(() {
                              isEnabled = value;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    final sortOrder = int.parse(sortController.text.trim());
                    try {
                      if (isEdit) {
                        await _service.updateStage(
                          stageId: existing.id,
                          code: codeController.text.trim(),
                          name: nameController.text.trim(),
                          sortOrder: sortOrder,
                          isEnabled: isEnabled,
                        );
                      } else {
                        await _service.createStage(
                          code: codeController.text.trim(),
                          name: nameController.text.trim(),
                          sortOrder: sortOrder,
                        );
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (error) {
                      if (_isUnauthorized(error)) {
                        widget.onLogout();
                        return;
                      }
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(_errorMessage(error))),
                        );
                      }
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    nameController.dispose();
    sortController.dispose();

    if (saved == true) {
      await _loadData();
    }
  }

  CraftStageItem _stageById(int stageId) {
    return _stages.firstWhere((item) => item.id == stageId);
  }

  String _extractSerialFromCode({
    required String code,
    required String stageCode,
  }) {
    final prefix = '$stageCode-';
    if (!code.startsWith(prefix)) {
      return '';
    }
    final serial = code.substring(prefix.length);
    if (serial.length != 2 || int.tryParse(serial) == null || serial == '00') {
      return '';
    }
    return serial;
  }

  Future<void> _showProcessDialog({CraftProcessItem? existing}) async {
    if (_stages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先新增工段')));
      return;
    }

    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    var selectedStageId = existing?.stageId ?? _stages.first.id;
    bool isEnabled = existing?.isEnabled ?? true;
    final formKey = GlobalKey<FormState>();

    String initialSerial = '';
    bool legacyCodeInvalid = false;
    if (existing != null && existing.stageId != null) {
      CraftStageItem? stage;
      for (final item in _stages) {
        if (item.id == existing.stageId) {
          stage = item;
          break;
        }
      }
      if (stage != null) {
        initialSerial = _extractSerialFromCode(
          code: existing.code,
          stageCode: stage.code,
        );
        legacyCodeInvalid = initialSerial.isEmpty;
      }
    }
    final serialController = TextEditingController(text: initialSerial);

    final saved = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final stage = _stageById(selectedStageId);
            final serialText = serialController.text.trim();
            final fullCodePreview = serialText.isEmpty
                ? '${stage.code}-__'
                : '${stage.code}-$serialText';
            return AlertDialog(
              title: Text(isEdit ? '编辑工序' : '新增工序'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedStageId,
                        decoration: const InputDecoration(
                          labelText: '所属工段',
                          border: OutlineInputBorder(),
                        ),
                        items: _stages
                            .map(
                              (entry) => DropdownMenuItem<int>(
                                value: entry.id,
                                child: Text('${entry.name} (${entry.code})'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedStageId = value;
                            serialController.clear();
                            legacyCodeInvalid = false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: serialController,
                        decoration: const InputDecoration(
                          labelText: '工序编码序号（两位）',
                          hintText: '例如 01',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                        validator: (value) {
                          final serial = (value ?? '').trim();
                          if (serial.isEmpty) {
                            return '请输入两位序号';
                          }
                          if (serial.length != 2 ||
                              int.tryParse(serial) == null) {
                            return '序号必须是两位数字';
                          }
                          if (serial == '00') {
                            return '序号必须是 01-99';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '完整编码预览：$fullCodePreview',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (legacyCodeInvalid) ...[
                        const SizedBox(height: 8),
                        Text(
                          '历史编码不符合新规则，请按“工段编码-两位序号”重新填写。',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '小工序名称',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入小工序名称';
                          }
                          return null;
                        },
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('启用'),
                          value: isEnabled,
                          onChanged: (value) {
                            setDialogState(() {
                              isEnabled = value;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    final serial = serialController.text.trim();
                    final code = '${stage.code}-$serial';
                    try {
                      if (isEdit) {
                        await _service.updateProcess(
                          processId: existing.id,
                          code: code,
                          name: nameController.text.trim(),
                          stageId: selectedStageId,
                          isEnabled: isEnabled,
                        );
                      } else {
                        await _service.createProcess(
                          code: code,
                          name: nameController.text.trim(),
                          stageId: selectedStageId,
                        );
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (error) {
                      if (_isUnauthorized(error)) {
                        widget.onLogout();
                        return;
                      }
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(_errorMessage(error))),
                        );
                      }
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    serialController.dispose();

    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _handleStageAction(
    _StageAction action,
    CraftStageItem item,
  ) async {
    switch (action) {
      case _StageAction.edit:
        await _showStageDialog(existing: item);
        return;
      case _StageAction.toggle:
        try {
          await _service.updateStage(
            stageId: item.id,
            code: item.code,
            name: item.name,
            sortOrder: item.sortOrder,
            isEnabled: !item.isEnabled,
          );
          await _loadData();
        } catch (error) {
          if (_isUnauthorized(error)) {
            widget.onLogout();
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
          }
        }
        return;
      case _StageAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除工段'),
            content: Text('确认删除工段 ${item.name} 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
        try {
          await _service.deleteStage(stageId: item.id);
          await _loadData();
        } catch (error) {
          if (_isUnauthorized(error)) {
            widget.onLogout();
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
          }
        }
        return;
    }
  }

  Future<void> _handleProcessAction(
    _ProcessAction action,
    CraftProcessItem item,
  ) async {
    switch (action) {
      case _ProcessAction.edit:
        await _showProcessDialog(existing: item);
        return;
      case _ProcessAction.toggle:
        try {
          await _service.updateProcess(
            processId: item.id,
            code: item.code,
            name: item.name,
            stageId: item.stageId ?? 0,
            isEnabled: !item.isEnabled,
          );
          await _loadData();
        } catch (error) {
          if (_isUnauthorized(error)) {
            widget.onLogout();
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
          }
        }
        return;
      case _ProcessAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除小工序'),
            content: Text('确认删除小工序 ${item.name} 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
        try {
          await _service.deleteProcess(processId: item.id);
          await _loadData();
        } catch (error) {
          if (_isUnauthorized(error)) {
            widget.onLogout();
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
          }
        }
        return;
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
                '工序管理',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _loading ? null : () => _showStageDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增工段'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : () => _showProcessDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增工序'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadData,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
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
                : Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '工段列表',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _stages.isEmpty
                                      ? const Center(child: Text('暂无工段'))
                                      : ListView.separated(
                                          itemCount: _stages.length,
                                          separatorBuilder: (context, index) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final item = _stages[index];
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 12,
                                                  ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(item.code),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(item.name),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      '${item.sortOrder}',
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      item.isEnabled
                                                          ? '启用'
                                                          : '停用',
                                                    ),
                                                  ),
                                                  Container(
                                                    alignment: Alignment.center,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: PopupMenuButton<_StageAction>(
                                                      color: theme
                                                          .colorScheme
                                                          .primaryContainer,
                                                      onSelected: (action) {
                                                        _handleStageAction(
                                                          action,
                                                          item,
                                                        );
                                                      },
                                                      itemBuilder: (context) =>
                                                          const [
                                                            PopupMenuItem(
                                                              value:
                                                                  _StageAction
                                                                      .edit,
                                                              child: Text('编辑'),
                                                            ),
                                                            PopupMenuItem(
                                                              value:
                                                                  _StageAction
                                                                      .toggle,
                                                              child: Text(
                                                                '启用/停用',
                                                              ),
                                                            ),
                                                            PopupMenuItem(
                                                              value:
                                                                  _StageAction
                                                                      .delete,
                                                              child: Text('删除'),
                                                            ),
                                                          ],
                                                      child: Text(
                                                        '操作',
                                                        style: TextStyle(
                                                          color: theme
                                                              .colorScheme
                                                              .onPrimary,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '工序列表',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _processes.isEmpty
                                      ? const Center(child: Text('暂无小工序'))
                                      : ListView.separated(
                                          itemCount: _processes.length,
                                          separatorBuilder: (context, index) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final item = _processes[index];
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 12,
                                                  ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      item.stageName ?? '-',
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(item.code),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(item.name),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      item.isEnabled
                                                          ? '启用'
                                                          : '停用',
                                                    ),
                                                  ),
                                                  Container(
                                                    alignment: Alignment.center,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: PopupMenuButton<_ProcessAction>(
                                                      color: theme
                                                          .colorScheme
                                                          .primaryContainer,
                                                      onSelected: (action) {
                                                        _handleProcessAction(
                                                          action,
                                                          item,
                                                        );
                                                      },
                                                      itemBuilder: (context) =>
                                                          const [
                                                            PopupMenuItem(
                                                              value:
                                                                  _ProcessAction
                                                                      .edit,
                                                              child: Text('编辑'),
                                                            ),
                                                            PopupMenuItem(
                                                              value:
                                                                  _ProcessAction
                                                                      .toggle,
                                                              child: Text(
                                                                '启用/停用',
                                                              ),
                                                            ),
                                                            PopupMenuItem(
                                                              value:
                                                                  _ProcessAction
                                                                      .delete,
                                                              child: Text('删除'),
                                                            ),
                                                          ],
                                                      child: Text(
                                                        '操作',
                                                        style: TextStyle(
                                                          color: theme
                                                              .colorScheme
                                                              .onPrimary,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
