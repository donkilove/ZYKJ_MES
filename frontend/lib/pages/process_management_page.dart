import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../widgets/crud_page_header.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/unified_list_table_header_style.dart';

enum _StageAction { edit, toggle, viewReference, delete }

enum _ProcessAction { edit, toggle, viewReference, delete }

class ProcessManagementPage extends StatefulWidget {
  const ProcessManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
    this.craftService,
    this.processId,
    this.jumpRequestId = 0,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;
  final CraftService? craftService;
  final int? processId;
  final int jumpRequestId;

  @override
  State<ProcessManagementPage> createState() => _ProcessManagementPageState();
}

class _ProcessManagementPageState extends State<ProcessManagementPage> {
  static const double _twoPaneBreakpoint = 1100;

  late final CraftService _service;

  bool _loading = false;
  String _message = '';
  List<CraftStageItem> _stages = const [];
  List<CraftProcessItem> _processes = const [];

  // 搜索/筛选
  final _stageSearchController = TextEditingController();
  final _processSearchController = TextEditingController();
  String _stageKeyword = '';
  String _processKeyword = '';
  int? _processStageFilter;
  int? _focusedProcessId;
  String _jumpNotice = '';
  int _lastHandledJumpRequestId = -1;

  @override
  void initState() {
    super.initState();
    _service = widget.craftService ?? CraftService(widget.session);
    _loadData();
  }

  @override
  void dispose() {
    _stageSearchController.dispose();
    _processSearchController.dispose();
    super.dispose();
  }

  List<CraftStageItem> get _filteredStages {
    var list = _stages;
    if (_stageKeyword.isNotEmpty) {
      final kw = _stageKeyword.toLowerCase();
      list = list
          .where(
            (s) =>
                s.code.toLowerCase().contains(kw) ||
                s.name.toLowerCase().contains(kw),
          )
          .toList();
    }
    return list;
  }

  List<CraftProcessItem> get _filteredProcesses {
    var list = _processes;
    if (_processStageFilter != null) {
      list = list.where((p) => p.stageId == _processStageFilter).toList();
    }
    if (_processKeyword.isNotEmpty) {
      final kw = _processKeyword.toLowerCase();
      list = list
          .where(
            (p) =>
                p.code.toLowerCase().contains(kw) ||
                p.name.toLowerCase().contains(kw) ||
                (p.stageName?.toLowerCase().contains(kw) ?? false),
          )
          .toList();
    }
    return list;
  }

  CraftProcessItem? get _focusedProcess {
    final focusedProcessId = _focusedProcessId;
    if (focusedProcessId == null) {
      return null;
    }
    for (final item in _processes) {
      if (item.id == focusedProcessId) {
        return item;
      }
    }
    return null;
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

  @override
  void didUpdateWidget(covariant ProcessManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jumpRequestId != oldWidget.jumpRequestId) {
      _tryApplyJumpTarget(force: true);
    }
  }

  void _tryApplyJumpTarget({bool force = false}) {
    if (!mounted) {
      return;
    }
    if (!force && widget.jumpRequestId == _lastHandledJumpRequestId) {
      return;
    }
    final processId = widget.processId;
    if (processId == null || processId <= 0) {
      _lastHandledJumpRequestId = widget.jumpRequestId;
      return;
    }
    CraftProcessItem? matched;
    for (final item in _processes) {
      if (item.id == processId) {
        matched = item;
        break;
      }
    }
    if (matched == null) {
      setState(() {
        _focusedProcessId = null;
        _jumpNotice = '未找到目标工序记录 #$processId';
      });
      _lastHandledJumpRequestId = widget.jumpRequestId;
      return;
    }
    setState(() {
      _processStageFilter = matched!.stageId;
      _processKeyword = '';
      _processSearchController.clear();
      _focusedProcessId = matched.id;
      _jumpNotice = '已定位工序 #${matched.id} ${matched.name}';
    });
    _lastHandledJumpRequestId = widget.jumpRequestId;
  }

  void _showNoPermission() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前账号没有操作权限')));
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final stageResult = await _service.listStages(pageSize: 500);
      final processResult = await _service.listProcesses(pageSize: 500);
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
        _tryApplyJumpTarget(force: true);
      }
    }
  }

  Future<void> _showStageDialog({CraftStageItem? existing}) async {
    if (!widget.canWrite) {
      _showNoPermission();
      return;
    }
    final isEdit = existing != null;
    final codeController = TextEditingController(text: existing?.code ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final sortController = TextEditingController(
      text: (existing?.sortOrder ?? 0).toString(),
    );
    final remarkController = TextEditingController(
      text: existing?.remark ?? '',
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarkController,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '备注（可选）',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
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
                          remark: remarkController.text.trim(),
                        );
                      } else {
                        await _service.createStage(
                          code: codeController.text.trim(),
                          name: nameController.text.trim(),
                          sortOrder: sortOrder,
                          remark: remarkController.text.trim(),
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
    if (!widget.canWrite) {
      _showNoPermission();
      return;
    }
    if (_stages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先新增工段')));
      return;
    }

    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final remarkController = TextEditingController(
      text: existing?.remark ?? '',
    );
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarkController,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '备注（可选）',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
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
                          remark: remarkController.text.trim(),
                        );
                      } else {
                        await _service.createProcess(
                          code: code,
                          name: nameController.text.trim(),
                          stageId: selectedStageId,
                          remark: remarkController.text.trim(),
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
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        await _showStageDialog(existing: item);
        return;
      case _StageAction.toggle:
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        try {
          await _service.updateStage(
            stageId: item.id,
            code: item.code,
            name: item.name,
            sortOrder: item.sortOrder,
            isEnabled: !item.isEnabled,
            remark: item.remark,
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
      case _StageAction.viewReference:
        _showStageReferenceDialog(item);
        return;
      case _StageAction.delete:
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        // 先加载引用分析
        List<_RefEntry> refs = [];
        try {
          final result = await _service.getStageReferences(stageId: item.id);
          refs = result.items
              .map(
                (e) => _RefEntry(
                  e.refType,
                  e.refName,
                  e.refCode ?? '#${e.refId}',
                  e.detail,
                ),
              )
              .toList();
        } catch (error) {
          if (_isUnauthorized(error)) {
            widget.onLogout();
            return;
          }
        }
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除工段'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('确认删除工段 ${item.name} 吗？'),
                  if (refs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '该工段存在 ${refs.length} 条引用关系：',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: refs.length,
                        itemBuilder: (context, index) {
                          final ref = refs[index];
                          return ListTile(
                            dense: true,
                            leading: Text(ref.refType),
                            title: Text(ref.refName),
                            subtitle: Text(ref.detail ?? ''),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        await _showProcessDialog(existing: item);
        return;
      case _ProcessAction.toggle:
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        try {
          await _service.updateProcess(
            processId: item.id,
            code: item.code,
            name: item.name,
            stageId: item.stageId ?? 0,
            isEnabled: !item.isEnabled,
            remark: item.remark,
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
      case _ProcessAction.viewReference:
        _showProcessReferenceDialog(item);
        return;
      case _ProcessAction.delete:
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        // 先加载引用分析
        List<_RefEntry> processRefs = [];
        try {
          final result = await _service.getProcessReferences(
            processId: item.id,
          );
          processRefs = result.items
              .map(
                (e) => _RefEntry(
                  e.refType,
                  e.refName,
                  e.refCode ?? '#${e.refId}',
                  e.detail,
                ),
              )
              .toList();
        } catch (error) {
          if (_isUnauthorized(error)) {
            widget.onLogout();
            return;
          }
        }
        if (!mounted) return;
        final processConfirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除工序'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('确认删除工序 ${item.name} 吗？'),
                  if (processRefs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '该工序存在 ${processRefs.length} 条引用关系：',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: processRefs.length,
                        itemBuilder: (context, index) {
                          final ref = processRefs[index];
                          return ListTile(
                            dense: true,
                            leading: Text(ref.refType),
                            title: Text(ref.refName),
                            subtitle: Text(ref.detail ?? ''),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
        if (processConfirmed != true) {
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

  void _showStageReferenceDialog(CraftStageItem stage) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ReferenceDialog(
        title: '工段引用分析：${stage.name}',
        loader: () => _service
            .getStageReferences(stageId: stage.id)
            .then(
              (r) => r.items
                  .map(
                    (e) => _RefEntry(
                      e.refType,
                      e.refName,
                      e.refCode ?? '#${e.refId}',
                      e.detail,
                    ),
                  )
                  .toList(),
            ),
      ),
    );
  }

  void _showProcessReferenceDialog(CraftProcessItem process) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ReferenceDialog(
        title: '工序引用分析：${process.name}',
        loader: () => _service
            .getProcessReferences(processId: process.id)
            .then(
              (r) => r.items
                  .map(
                    (e) => _RefEntry(
                      e.refType,
                      e.refName,
                      e.refCode ?? '#${e.refId}',
                      e.detail,
                    ),
                  )
                  .toList(),
            ),
      ),
    );
  }

  Widget _buildHeaderLabel(
    ThemeData theme,
    String text, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildCellText(
    String text, {
    TextAlign textAlign = TextAlign.start,
    TextStyle? style,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }

  Widget _buildToolbarSearchField({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, size: 16),
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        ).copyWith(hintText: hintText),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildListHeaderRow({
    required ThemeData theme,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildStageHeaderRow(ThemeData theme) {
    return _buildListHeaderRow(
      theme: theme,
      children: [
        Expanded(flex: 1, child: _buildHeaderLabel(theme, '工段编码')),
        Expanded(flex: 2, child: _buildHeaderLabel(theme, '工段名称')),
        Expanded(flex: 2, child: _buildHeaderLabel(theme, '备注')),
        Expanded(flex: 1, child: _buildHeaderLabel(theme, '排序')),
        Expanded(flex: 1, child: _buildHeaderLabel(theme, '状态')),
        Expanded(flex: 1, child: _buildHeaderLabel(theme, '关联工序数')),
        Expanded(flex: 1, child: _buildHeaderLabel(theme, '创建时间')),
        SizedBox(
          width: 64,
          child: _buildHeaderLabel(theme, '操作', textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _buildProcessHeaderRow(ThemeData theme) {
    return _buildListHeaderRow(
      theme: theme,
      children: [
        Expanded(flex: 2, child: _buildHeaderLabel(theme, '所属工段')),
        Expanded(flex: 1, child: _buildHeaderLabel(theme, '工序编码')),
        Expanded(flex: 2, child: _buildHeaderLabel(theme, '工序名称')),
        Expanded(flex: 2, child: _buildHeaderLabel(theme, '备注')),
        Expanded(flex: 1, child: _buildHeaderLabel(theme, '状态')),
        Expanded(flex: 1, child: _buildHeaderLabel(theme, '创建时间')),
        SizedBox(
          width: 64,
          child: _buildHeaderLabel(theme, '操作', textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _buildFocusedProcessBanner(ThemeData theme) {
    final process = _focusedProcess;
    if (_jumpNotice.isEmpty && process == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              process == null
                  ? _jumpNotice
                  : '$_jumpNotice，所属工段：${process.stageName ?? '-'}，编码：${process.code}',
            ),
          ),
          if (process != null)
            TextButton(
              onPressed: () => _showProcessReferenceDialog(process),
              child: const Text('查看引用'),
            ),
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
          CrudPageHeader(title: '工序管理', onRefresh: _loading ? null : _loadData),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: (_loading || !widget.canWrite)
                    ? null
                    : () => _showStageDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增工段'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_loading || !widget.canWrite)
                    ? null
                    : () => _showProcessDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增工序'),
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow =
                          constraints.maxWidth < _twoPaneBreakpoint;
                      return Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '工段列表',
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        _buildToolbarSearchField(
                                          controller: _stageSearchController,
                                          hintText: '搜索工段',
                                          onChanged: (v) => setState(
                                            () => _stageKeyword = v.trim(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildStageHeaderRow(theme),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: _filteredStages.isEmpty
                                          ? const Center(child: Text('暂无工段'))
                                          : ListView.separated(
                                              itemCount: _filteredStages.length,
                                              separatorBuilder:
                                                  (context, index) =>
                                                      const Divider(height: 1),
                                              itemBuilder: (context, index) {
                                                final item =
                                                    _filteredStages[index];
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 12,
                                                      ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        flex: 1,
                                                        child: _buildCellText(
                                                          item.code,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: _buildCellText(
                                                          item.name,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: _buildCellText(
                                                          item.remark.isEmpty
                                                              ? '-'
                                                              : item.remark,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: _buildCellText(
                                                          '${item.sortOrder}',
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: _buildCellText(
                                                          item.isEnabled
                                                              ? '启用'
                                                              : '停用',
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: _buildCellText(
                                                          '${item.processCount}',
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: _buildCellText(
                                                          '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}',
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 64,
                                                        child: UnifiedListTableHeaderStyle.actionMenuButton<_StageAction>(
                                                          theme: theme,
                                                          onSelected: (action) {
                                                            _handleStageAction(
                                                              action,
                                                              item,
                                                            );
                                                          },
                                                          itemBuilder: (context) {
                                                            final items =
                                                                <
                                                                  PopupMenuEntry<
                                                                    _StageAction
                                                                  >
                                                                >[
                                                                  const PopupMenuItem(
                                                                    value: _StageAction
                                                                        .viewReference,
                                                                    child: Text(
                                                                      '查看引用',
                                                                    ),
                                                                  ),
                                                                ];
                                                            if (widget
                                                                .canWrite) {
                                                              items.addAll(const [
                                                                PopupMenuItem(
                                                                  value:
                                                                      _StageAction
                                                                          .edit,
                                                                  child: Text(
                                                                    '编辑',
                                                                  ),
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
                                                                  child: Text(
                                                                    '删除',
                                                                  ),
                                                                ),
                                                              ]);
                                                            }
                                                            return items;
                                                          },
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
                          SizedBox(
                            width: isNarrow ? 0 : 12,
                            height: isNarrow ? 12 : 0,
                          ),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '工序列表',
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        _buildToolbarSearchField(
                                          controller: _processSearchController,
                                          hintText: '搜索工序',
                                          onChanged: (v) => setState(
                                            () => _processKeyword = v.trim(),
                                          ),
                                        ),
                                        DropdownButton<int?>(
                                          value: _processStageFilter,
                                          isDense: true,
                                          hint: const Text('全部工段'),
                                          items: [
                                            const DropdownMenuItem<int?>(
                                              value: null,
                                              child: Text('全部工段'),
                                            ),
                                            ..._stages.map(
                                              (s) => DropdownMenuItem<int?>(
                                                value: s.id,
                                                child: Text(s.name),
                                              ),
                                            ),
                                          ],
                                          onChanged: (v) => setState(
                                            () => _processStageFilter = v,
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildFocusedProcessBanner(theme),
                                    const SizedBox(height: 8),
                                    _buildProcessHeaderRow(theme),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: _filteredProcesses.isEmpty
                                          ? const Center(child: Text('暂无小工序'))
                                          : ListView.separated(
                                              itemCount:
                                                  _filteredProcesses.length,
                                              separatorBuilder:
                                                  (context, index) =>
                                                      const Divider(height: 1),
                                              itemBuilder: (context, index) {
                                                final item =
                                                    _filteredProcesses[index];
                                                final isFocused =
                                                    item.id ==
                                                    _focusedProcessId;
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 12,
                                                      ),
                                                  decoration: isFocused
                                                      ? BoxDecoration(
                                                          color: theme
                                                              .colorScheme
                                                              .primaryContainer
                                                              .withValues(
                                                                alpha: 0.28,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        )
                                                      : null,
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        flex: 2,
                                                        child: _buildCellText(
                                                          item.stageName ?? '-',
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: _buildCellText(
                                                          item.code,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: _buildCellText(
                                                          item.name,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: _buildCellText(
                                                          item.remark.isEmpty
                                                              ? '-'
                                                              : item.remark,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: _buildCellText(
                                                          item.isEnabled
                                                              ? '启用'
                                                              : '停用',
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: _buildCellText(
                                                          '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}',
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 64,
                                                        child: UnifiedListTableHeaderStyle.actionMenuButton<_ProcessAction>(
                                                          theme: theme,
                                                          onSelected: (action) {
                                                            _handleProcessAction(
                                                              action,
                                                              item,
                                                            );
                                                          },
                                                          itemBuilder: (context) {
                                                            final items =
                                                                <
                                                                  PopupMenuEntry<
                                                                    _ProcessAction
                                                                  >
                                                                >[
                                                                  const PopupMenuItem(
                                                                    value: _ProcessAction
                                                                        .viewReference,
                                                                    child: Text(
                                                                      '查看引用',
                                                                    ),
                                                                  ),
                                                                ];
                                                            if (widget
                                                                .canWrite) {
                                                              items.addAll(const [
                                                                PopupMenuItem(
                                                                  value:
                                                                      _ProcessAction
                                                                          .edit,
                                                                  child: Text(
                                                                    '编辑',
                                                                  ),
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
                                                                  child: Text(
                                                                    '删除',
                                                                  ),
                                                                ),
                                                              ]);
                                                            }
                                                            return items;
                                                          },
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RefEntry {
  _RefEntry(this.refType, this.refName, this.refId, this.detail);
  final String refType;
  final String refName;
  final String refId;
  final String? detail;
}

class _ReferenceDialog extends StatefulWidget {
  const _ReferenceDialog({required this.title, required this.loader});
  final String title;
  final Future<List<_RefEntry>> Function() loader;

  @override
  State<_ReferenceDialog> createState() => _ReferenceDialogState();
}

class _ReferenceDialogState extends State<_ReferenceDialog> {
  bool _loading = true;
  String _error = '';
  List<_RefEntry> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.loader();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _refTypeLabel(String t) => switch (t) {
    'process' => '工序',
    'user' => '用户',
    'template' => '工艺模板',
    'system_master_template' => '系统母版',
    'order' => '生产工单',
    _ => t,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        height: 360,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            : _items.isEmpty
            ? const Center(child: Text('无引用记录，可安全删除'))
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = _items[i];
                  return ListTile(
                    dense: true,
                    leading: Chip(
                      label: Text(
                        _refTypeLabel(e.refType),
                        style: const TextStyle(fontSize: 11),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    title: Text(e.refName),
                    subtitle: Text(
                      [
                        '编码/编号：${e.refId}',
                        if (e.detail != null && e.detail!.trim().isNotEmpty)
                          e.detail!,
                      ].join('\n'),
                    ),
                    trailing: Text(
                      e.refId,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
