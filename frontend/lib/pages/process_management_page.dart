import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/simple_pagination_bar.dart';
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
  static const int _defaultPageSize = 10;
  static const List<int> _pageSizeOptions = [10, 20, 50];

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
  bool? _stageEnabledFilter;
  bool? _processEnabledFilter;
  int? _processStageFilter;
  bool _exporting = false;
  int? _focusedProcessId;
  String _jumpNotice = '';
  int _lastHandledJumpRequestId = -1;
  int _stagePage = 1;
  int _processPage = 1;
  int _stagePageSize = _defaultPageSize;
  int _processPageSize = _defaultPageSize;

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
    if (_stageEnabledFilter != null) {
      list = list.where((s) => s.isEnabled == _stageEnabledFilter).toList();
    }
    return list;
  }

  List<CraftStageItem> get _pagedStages =>
      _paginate(_filteredStages, _stagePage, _stagePageSize);

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
    if (_processEnabledFilter != null) {
      list = list.where((p) => p.isEnabled == _processEnabledFilter).toList();
    }
    return list;
  }

  List<CraftProcessItem> get _pagedProcesses =>
      _paginate(_filteredProcesses, _processPage, _processPageSize);

  int get _stageTotalPages => _resolveTotalPages(
    total: _filteredStages.length,
    pageSize: _stagePageSize,
  );

  int get _processTotalPages => _resolveTotalPages(
    total: _filteredProcesses.length,
    pageSize: _processPageSize,
  );

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

  int _resolveTotalPages({required int total, required int pageSize}) {
    if (total <= 0) {
      return 1;
    }
    return ((total - 1) ~/ pageSize) + 1;
  }

  List<T> _paginate<T>(List<T> items, int page, int pageSize) {
    if (items.isEmpty) {
      return const [];
    }
    final start = (page - 1) * pageSize;
    if (start >= items.length) {
      return const [];
    }
    final end = (start + pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  void _clampStagePage() {
    final totalPages = _stageTotalPages;
    if (_stagePage > totalPages) {
      _stagePage = totalPages;
    }
    if (_stagePage < 1) {
      _stagePage = 1;
    }
  }

  void _clampProcessPage() {
    final totalPages = _processTotalPages;
    if (_processPage > totalPages) {
      _processPage = totalPages;
    }
    if (_processPage < 1) {
      _processPage = 1;
    }
  }

  void _applyStageFilters({String? keyword, bool? enabled}) {
    setState(() {
      _stageKeyword = keyword ?? _stageSearchController.text.trim();
      _stageEnabledFilter = enabled;
      _stagePage = 1;
      _clampStagePage();
    });
  }

  void _resetStageFilters() {
    _stageSearchController.clear();
    setState(() {
      _stageKeyword = '';
      _stageEnabledFilter = null;
      _stagePage = 1;
      _clampStagePage();
    });
  }

  void _applyProcessFilters({String? keyword, bool? enabled, int? stageId}) {
    setState(() {
      _processKeyword = keyword ?? _processSearchController.text.trim();
      _processEnabledFilter = enabled;
      _processStageFilter = stageId;
      _processPage = 1;
      _clampProcessPage();
    });
  }

  void _resetProcessFilters() {
    _processSearchController.clear();
    setState(() {
      _processKeyword = '';
      _processEnabledFilter = null;
      _processStageFilter = null;
      _focusedProcessId = null;
      _jumpNotice = '';
      _processPage = 1;
      _clampProcessPage();
    });
  }

  void _moveToFocusedProcessPage() {
    final focusedProcessId = _focusedProcessId;
    if (focusedProcessId == null) {
      _clampProcessPage();
      return;
    }
    final index = _filteredProcesses.indexWhere(
      (item) => item.id == focusedProcessId,
    );
    if (index < 0) {
      _clampProcessPage();
      return;
    }
    _processPage = (index ~/ _processPageSize) + 1;
    _clampProcessPage();
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
      _processEnabledFilter = null;
      _focusedProcessId = matched.id;
      _jumpNotice = '已定位工序 #${matched.id} ${matched.name}';
      _moveToFocusedProcessPage();
    });
    _lastHandledJumpRequestId = widget.jumpRequestId;
  }

  Future<void> _exportCsv({required bool isStage}) async {
    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final csvBase64 = isStage
          ? await _service.exportStages(
              keyword: _stageKeyword.isNotEmpty ? _stageKeyword : null,
              enabled: _stageEnabledFilter,
            )
          : await _service.exportProcesses(
              keyword: _processKeyword.isNotEmpty ? _processKeyword : null,
              stageId: _processStageFilter,
              enabled: _processEnabledFilter,
            );
      if (!mounted) return;
      if (csvBase64.isEmpty) {
        setState(() => _message = '无数据可导出');
        return;
      }
      final bytes = base64Decode(csvBase64);
      final csvString = String.fromCharCodes(bytes);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(isStage ? '工段导出预览' : '工序导出预览'),
          content: SizedBox(
            width: 600,
            height: 400,
            child: SingleChildScrollView(child: SelectableText(csvString)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      setState(() => _message = '导出失败：${_errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
        _clampStagePage();
        _clampProcessPage();
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

    codeController.dispose();
    nameController.dispose();
    sortController.dispose();
    remarkController.dispose();

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

    nameController.dispose();
    serialController.dispose();
    remarkController.dispose();

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

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Widget _buildCountChip(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(ThemeData theme, bool enabled) {
    final color = enabled ? Colors.green : theme.colorScheme.error;
    final backgroundColor = enabled
        ? Colors.green.withValues(alpha: 0.12)
        : theme.colorScheme.errorContainer.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        enabled ? '启用' : '停用',
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTableSection({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required List<Widget> metrics,
    required Widget toolbar,
    required Widget table,
    required Widget pagination,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
                ...metrics,
              ],
            ),
            const SizedBox(height: 16),
            toolbar,
            const SizedBox(height: 12),
            Expanded(child: table),
            const SizedBox(height: 12),
            pagination,
          ],
        ),
      ),
    );
  }

  Widget _buildStageToolbar(ThemeData theme) {
    final buttonStyle = UnifiedListTableHeaderStyle.toolbarActionButtonStyle(
      theme,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              key: const Key('process-management-stage-search'),
              controller: _stageSearchController,
              decoration: const InputDecoration(
                labelText: '工段关键词',
                hintText: '按编码或名称筛选',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) =>
                  _applyStageFilters(enabled: _stageEnabledFilter),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<bool?>(
              key: ValueKey<bool?>(_stageEnabledFilter),
              initialValue: _stageEnabledFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '状态',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem<bool?>(value: null, child: Text('全部状态')),
                DropdownMenuItem<bool?>(value: true, child: Text('启用')),
                DropdownMenuItem<bool?>(value: false, child: Text('停用')),
              ],
              onChanged: (value) => _applyStageFilters(enabled: value),
            ),
          ),
          FilledButton.icon(
            key: const Key('process-management-stage-search-button'),
            onPressed: () => _applyStageFilters(enabled: _stageEnabledFilter),
            icon: const Icon(Icons.search),
            label: const Text('查询'),
          ),
          OutlinedButton.icon(
            key: const Key('process-management-stage-reset-button'),
            onPressed: _resetStageFilters,
            style: buttonStyle,
            icon: const Icon(Icons.restart_alt),
            label: const Text('重置'),
          ),
          OutlinedButton.icon(
            onPressed: _exporting ? null : () => _exportCsv(isStage: true),
            style: buttonStyle,
            icon: const Icon(Icons.download),
            label: const Text('导出'),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessToolbar(ThemeData theme) {
    final buttonStyle = UnifiedListTableHeaderStyle.toolbarActionButtonStyle(
      theme,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              key: const Key('process-management-process-search'),
              controller: _processSearchController,
              decoration: const InputDecoration(
                labelText: '工序关键词',
                hintText: '按编码、名称或工段筛选',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _applyProcessFilters(
                enabled: _processEnabledFilter,
                stageId: _processStageFilter,
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<bool?>(
              key: ValueKey<bool?>(_processEnabledFilter),
              initialValue: _processEnabledFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '状态',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem<bool?>(value: null, child: Text('全部状态')),
                DropdownMenuItem<bool?>(value: true, child: Text('启用')),
                DropdownMenuItem<bool?>(value: false, child: Text('停用')),
              ],
              onChanged: (value) => _applyProcessFilters(
                enabled: value,
                stageId: _processStageFilter,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int?>(
              key: ValueKey<int?>(_processStageFilter),
              initialValue: _processStageFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '工段',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('全部工段')),
                ..._stages.map(
                  (stage) => DropdownMenuItem<int?>(
                    value: stage.id,
                    child: Text('${stage.name} (${stage.code})'),
                  ),
                ),
              ],
              onChanged: (value) => _applyProcessFilters(
                enabled: _processEnabledFilter,
                stageId: value,
              ),
            ),
          ),
          FilledButton.icon(
            key: const Key('process-management-process-search-button'),
            onPressed: () => _applyProcessFilters(
              enabled: _processEnabledFilter,
              stageId: _processStageFilter,
            ),
            icon: const Icon(Icons.search),
            label: const Text('查询'),
          ),
          OutlinedButton.icon(
            key: const Key('process-management-process-reset-button'),
            onPressed: _resetProcessFilters,
            style: buttonStyle,
            icon: const Icon(Icons.restart_alt),
            label: const Text('重置'),
          ),
          OutlinedButton.icon(
            onPressed: _exporting ? null : () => _exportCsv(isStage: false),
            style: buttonStyle,
            icon: const Icon(Icons.download),
            label: const Text('导出'),
          ),
        ],
      ),
    );
  }

  Widget _buildStageTable(ThemeData theme) {
    if (_filteredStages.isEmpty) {
      return const Center(child: Text('暂无工段'));
    }
    return AdaptiveTableContainer(
      minTableWidth: 1120,
      child: UnifiedListTableHeaderStyle.wrap(
        theme: theme,
        child: DataTable(
          dataRowMinHeight: 64,
          dataRowMaxHeight: 84,
          columns: [
            UnifiedListTableHeaderStyle.column(context, '工段编码'),
            UnifiedListTableHeaderStyle.column(context, '工段名称'),
            UnifiedListTableHeaderStyle.column(context, '备注'),
            UnifiedListTableHeaderStyle.column(context, '排序'),
            UnifiedListTableHeaderStyle.column(context, '状态'),
            UnifiedListTableHeaderStyle.column(context, '关联工序数'),
            UnifiedListTableHeaderStyle.column(context, '创建时间'),
            UnifiedListTableHeaderStyle.column(
              context,
              '操作',
              textAlign: TextAlign.center,
            ),
          ],
          rows: _pagedStages.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.code)),
                DataCell(Text(item.name)),
                DataCell(Text(item.remark.isEmpty ? '-' : item.remark)),
                DataCell(Text('${item.sortOrder}')),
                DataCell(_buildStatusTag(theme, item.isEnabled)),
                DataCell(Text('${item.processCount}')),
                DataCell(
                  Text(
                    _formatDate(item.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                DataCell(
                  UnifiedListTableHeaderStyle.actionMenuButton<_StageAction>(
                    theme: theme,
                    onSelected: (action) {
                      _handleStageAction(action, item);
                    },
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<_StageAction>>[
                        const PopupMenuItem(
                          value: _StageAction.viewReference,
                          child: Text('查看引用'),
                        ),
                      ];
                      if (widget.canWrite) {
                        items.addAll(const [
                          PopupMenuItem(
                            value: _StageAction.edit,
                            child: Text('编辑'),
                          ),
                          PopupMenuItem(
                            value: _StageAction.toggle,
                            child: Text('启用/停用'),
                          ),
                          PopupMenuItem(
                            value: _StageAction.delete,
                            child: Text('删除'),
                          ),
                        ]);
                      }
                      return items;
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProcessTable(ThemeData theme) {
    if (_filteredProcesses.isEmpty) {
      return const Center(child: Text('暂无小工序'));
    }
    return AdaptiveTableContainer(
      minTableWidth: 1100,
      child: UnifiedListTableHeaderStyle.wrap(
        theme: theme,
        child: DataTable(
          dataRowMinHeight: 64,
          dataRowMaxHeight: 84,
          columns: [
            UnifiedListTableHeaderStyle.column(context, '所属工段'),
            UnifiedListTableHeaderStyle.column(context, '工序编码'),
            UnifiedListTableHeaderStyle.column(context, '工序名称'),
            UnifiedListTableHeaderStyle.column(context, '备注'),
            UnifiedListTableHeaderStyle.column(context, '状态'),
            UnifiedListTableHeaderStyle.column(context, '创建时间'),
            UnifiedListTableHeaderStyle.column(
              context,
              '操作',
              textAlign: TextAlign.center,
            ),
          ],
          rows: _pagedProcesses.map((item) {
            final isFocused = item.id == _focusedProcessId;
            return DataRow(
              color: isFocused
                  ? WidgetStatePropertyAll(
                      theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.28,
                      ),
                    )
                  : null,
              cells: [
                DataCell(Text(item.stageName ?? '-')),
                DataCell(Text(item.code)),
                DataCell(Text(item.name)),
                DataCell(Text(item.remark.isEmpty ? '-' : item.remark)),
                DataCell(_buildStatusTag(theme, item.isEnabled)),
                DataCell(
                  Text(
                    _formatDate(item.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                DataCell(
                  UnifiedListTableHeaderStyle.actionMenuButton<_ProcessAction>(
                    theme: theme,
                    onSelected: (action) {
                      _handleProcessAction(action, item);
                    },
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<_ProcessAction>>[
                        const PopupMenuItem(
                          value: _ProcessAction.viewReference,
                          child: Text('查看引用'),
                        ),
                      ];
                      if (widget.canWrite) {
                        items.addAll(const [
                          PopupMenuItem(
                            value: _ProcessAction.edit,
                            child: Text('编辑'),
                          ),
                          PopupMenuItem(
                            value: _ProcessAction.toggle,
                            child: Text('启用/停用'),
                          ),
                          PopupMenuItem(
                            value: _ProcessAction.delete,
                            child: Text('删除'),
                          ),
                        ]);
                      }
                      return items;
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
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
    final toolbarButtonStyle =
        UnifiedListTableHeaderStyle.toolbarActionButtonStyle(theme);

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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadData,
                style: toolbarButtonStyle,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
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
                      final isNarrow = constraints.maxWidth < 1360;
                      return Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        children: [
                          Expanded(
                            flex: isNarrow ? 1 : 5,
                            child: _buildTableSection(
                              theme: theme,
                              title: '工段列表',
                              subtitle: '左侧维护工段档案，右侧工序列表继续按工段联动过滤。',
                              metrics: [
                                _buildCountChip(
                                  theme,
                                  '筛选后',
                                  '${_filteredStages.length}',
                                ),
                                _buildCountChip(
                                  theme,
                                  '当前页',
                                  '$_stagePage/$_stageTotalPages',
                                ),
                              ],
                              toolbar: _buildStageToolbar(theme),
                              table: _buildStageTable(theme),
                              pagination: SimplePaginationBar(
                                page: _stagePage,
                                totalPages: _stageTotalPages,
                                total: _filteredStages.length,
                                loading: _loading,
                                pageSize: _stagePageSize,
                                pageSizeOptions: _pageSizeOptions,
                                onPrevious: () =>
                                    setState(() => _stagePage -= 1),
                                onNext: () => setState(() => _stagePage += 1),
                                onPageChanged: (value) =>
                                    setState(() => _stagePage = value),
                                onPageSizeChanged: (value) {
                                  setState(() {
                                    _stagePageSize = value;
                                    _stagePage = 1;
                                    _clampStagePage();
                                  });
                                },
                              ),
                            ),
                          ),
                          SizedBox(
                            width: isNarrow ? 0 : 12,
                            height: isNarrow ? 12 : 0,
                          ),
                          Expanded(
                            flex: isNarrow ? 1 : 7,
                            child: _buildTableSection(
                              theme: theme,
                              title: '工序列表',
                              subtitle: '保留工段-工序双区联动，支持定位结果高亮与分页浏览。',
                              metrics: [
                                _buildCountChip(
                                  theme,
                                  '筛选后',
                                  '${_filteredProcesses.length}',
                                ),
                                _buildCountChip(
                                  theme,
                                  '当前页',
                                  '$_processPage/$_processTotalPages',
                                ),
                              ],
                              toolbar: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProcessToolbar(theme),
                                  _buildFocusedProcessBanner(theme),
                                ],
                              ),
                              table: _buildProcessTable(theme),
                              pagination: SimplePaginationBar(
                                page: _processPage,
                                totalPages: _processTotalPages,
                                total: _filteredProcesses.length,
                                loading: _loading,
                                pageSize: _processPageSize,
                                pageSizeOptions: _pageSizeOptions,
                                onPrevious: () =>
                                    setState(() => _processPage -= 1),
                                onNext: () => setState(() => _processPage += 1),
                                onPageChanged: (value) =>
                                    setState(() => _processPage = value),
                                onPageSizeChanged: (value) {
                                  setState(() {
                                    _processPageSize = value;
                                    _moveToFocusedProcessPage();
                                  });
                                },
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
