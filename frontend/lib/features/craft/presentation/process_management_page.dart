import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_delete_dialogs.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_item_dialog.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_item_panel.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_feedback_banner.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_page_header.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_state.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_view_switch.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_stage_dialog.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_stage_panel.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';

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
  late final CraftService _service;
  late final ProcessManagementState _pageState;
  final _stageSearchController = TextEditingController();
  final _processSearchController = TextEditingController();

  ProcessManagementViewState get _viewState => _pageState.viewState;
  List<CraftStageItem> get _stages => _viewState.stages;
  List<CraftStageItem> get _filteredStages => _pageState.filteredStages;
  List<CraftProcessItem> get _filteredProcesses => _pageState.filteredProcesses;

  @override
  void initState() {
    super.initState();
    _service = widget.craftService ?? CraftService(widget.session);
    _pageState = ProcessManagementState(
      service: _service,
      onUnauthorized: widget.onLogout,
    )..addListener(_handleStateChanged);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ProcessManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jumpRequestId != oldWidget.jumpRequestId) {
      _applyJumpTarget();
    }
  }

  @override
  void dispose() {
    _pageState.removeListener(_handleStateChanged);
    _pageState.dispose();
    _stageSearchController.dispose();
    _processSearchController.dispose();
    super.dispose();
  }

  void _handleStateChanged() {
    _syncControllersFromState();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _syncControllersFromState() {
    if (_stageSearchController.text != _viewState.stageKeyword) {
      _stageSearchController.value = TextEditingValue(
        text: _viewState.stageKeyword,
        selection: TextSelection.collapsed(
          offset: _viewState.stageKeyword.length,
        ),
      );
    }
    if (_processSearchController.text != _viewState.processKeyword) {
      _processSearchController.value = TextEditingValue(
        text: _viewState.processKeyword,
        selection: TextSelection.collapsed(
          offset: _viewState.processKeyword.length,
        ),
      );
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

  Future<void> _loadData() async {
    await _pageState.loadData();
    _applyJumpTarget();
  }

  void _applyJumpTarget() {
    _pageState.applyJumpTarget(
      processId: widget.processId,
      jumpRequestId: widget.jumpRequestId,
    );
  }

  void _showNoPermission() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前账号没有操作权限')));
  }

  CraftStageItem _stageById(int stageId) {
    return _stages.firstWhere((item) => item.id == stageId);
  }

  Future<void> _showStageDialog({CraftStageItem? existing}) async {
    if (!widget.canWrite) {
      _showNoPermission();
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProcessStageDialog(
        existing: existing,
        onSubmit: ({
          required String code,
          required String name,
          required int sortOrder,
          required String remark,
          required bool isEnabled,
        }) async {
          if (existing == null) {
            await _service.createStage(
              code: code,
              name: name,
              sortOrder: sortOrder,
              remark: remark,
            );
          } else {
            await _service.updateStage(
              stageId: existing.id,
              code: code,
              name: name,
              sortOrder: sortOrder,
              isEnabled: isEnabled,
              remark: remark,
            );
          }
        },
      ),
    );

    if (saved == true) {
      await _loadData();
    }
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
    _pageState.setActiveView(ProcessManagementPrimaryView.processList);

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProcessItemDialog(
        existing: existing,
        stages: _stages,
        onSubmit: ({
          required String codeSuffix,
          required String name,
          required int stageId,
          required String remark,
          required bool isEnabled,
        }) async {
          final stage = _stageById(stageId);
          final fullCode = '${stage.code}-$codeSuffix';
          if (existing == null) {
            await _service.createProcess(
              code: fullCode,
              name: name,
              stageId: stageId,
              remark: remark,
            );
          } else {
            await _service.updateProcess(
              processId: existing.id,
              code: fullCode,
              name: name,
              stageId: stageId,
              isEnabled: isEnabled,
              remark: remark,
            );
          }
        },
      ),
    );

    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _handleStageAction(
    StageAction action,
    CraftStageItem item,
  ) async {
    switch (action) {
      case StageAction.edit:
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        await _showStageDialog(existing: item);
        return;
      case StageAction.toggle:
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
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
        }
        return;
      case StageAction.viewReference:
        _showStageReferenceDialog(item);
        return;
      case StageAction.delete:
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        List<RefEntry> refs = [];
        try {
          final result = await _service.getStageReferences(stageId: item.id);
          refs = result.items
              .map(
                (entry) => RefEntry(
                  entry.refType,
                  entry.refName,
                  entry.refCode ?? '#${entry.refId}',
                  entry.detail,
                ),
              )
              .toList();
        } catch (error) {
          if (_isUnauthorized(error)) {
            widget.onLogout();
            return;
          }
        }
        if (!mounted) {
          return;
        }
        final confirmed = await showDeleteDialog(
          context,
          title: '删除工段',
          targetName: '工段 ${item.name}',
          refs: refs,
        );
        if (!confirmed) {
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
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
        }
        return;
    }
  }

  Future<void> _handleProcessAction(
    ProcessAction action,
    CraftProcessItem item,
  ) async {
    switch (action) {
      case ProcessAction.edit:
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        await _showProcessDialog(existing: item);
        return;
      case ProcessAction.toggle:
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
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
        }
        return;
      case ProcessAction.viewReference:
        _showProcessReferenceDialog(item);
        return;
      case ProcessAction.delete:
        if (!widget.canWrite) {
          _showNoPermission();
          return;
        }
        List<RefEntry> refs = [];
        try {
          final result = await _service.getProcessReferences(processId: item.id);
          refs = result.items
              .map(
                (entry) => RefEntry(
                  entry.refType,
                  entry.refName,
                  entry.refCode ?? '#${entry.refId}',
                  entry.detail,
                ),
              )
              .toList();
        } catch (error) {
          if (_isUnauthorized(error)) {
            widget.onLogout();
            return;
          }
        }
        if (!mounted) {
          return;
        }
        final confirmed = await showDeleteDialog(
          context,
          title: '删除工序',
          targetName: '工序 ${item.name}',
          refs: refs,
        );
        if (!confirmed) {
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
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
        }
        return;
    }
  }

  void _showStageReferenceDialog(CraftStageItem stage) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ReferenceDialog(
        title: '工段引用分析：${stage.name}',
        loader: () => _service.getStageReferences(stageId: stage.id).then(
          (result) => result.items
              .map(
                (entry) => RefEntry(
                  entry.refType,
                  entry.refName,
                  entry.refCode ?? '#${entry.refId}',
                  entry.detail,
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
        loader: () => _service.getProcessReferences(processId: process.id).then(
          (result) => result.items
              .map(
                (entry) => RefEntry(
                  entry.refType,
                  entry.refName,
                  entry.refCode ?? '#${entry.refId}',
                  entry.detail,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = switch (_viewState.activeView) {
      ProcessManagementPrimaryView.processList => ProcessItemPanel(
          searchController: _processSearchController,
          stageFilter: _viewState.processStageFilter,
          stageOptions: _stages,
          items: _filteredProcesses,
          focusedProcessId: _viewState.focusedProcessId,
          canWrite: widget.canWrite,
          onKeywordChanged: _pageState.setProcessKeyword,
          onStageFilterChanged: _pageState.setProcessStageFilter,
          onFocusProcess: _pageState.focusProcess,
          onActionSelected: _handleProcessAction,
        ),
      ProcessManagementPrimaryView.stageList => ProcessStagePanel(
          searchController: _stageSearchController,
          items: _filteredStages,
          canWrite: widget.canWrite,
          onKeywordChanged: _pageState.setStageKeyword,
          onActionSelected: _handleStageAction,
        ),
    };

    return MesCrudPageScaffold(
      header: ProcessManagementPageHeader(
        loading: _viewState.loading,
        canWrite: widget.canWrite,
        onRefresh: _loadData,
        onCreateStage: _showStageDialog,
        onCreateProcess: _showProcessDialog,
      ),
      filters: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ProcessManagementFeedbackBanner(
            message: _viewState.message,
            jumpNotice: _viewState.jumpNotice,
          ),
          const SizedBox(height: 12),
          ProcessManagementViewSwitch(
            activeView: _viewState.activeView,
            onChanged: _pageState.setActiveView,
          ),
        ],
      ),
      content: _viewState.loading
          ? const Center(child: CircularProgressIndicator())
          : workspace,
    );
  }
}

class _ReferenceDialog extends StatefulWidget {
  const _ReferenceDialog({required this.title, required this.loader});

  final String title;
  final Future<List<RefEntry>> Function() loader;

  @override
  State<_ReferenceDialog> createState() => _ReferenceDialogState();
}

class _ReferenceDialogState extends State<_ReferenceDialog> {
  bool _loading = true;
  String _error = '';
  List<RefEntry> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _refTypeLabel(String type) => switch (type) {
    'process' => '工序',
    'user' => '用户',
    'template' => '工艺模板',
    'system_master_template' => '系统母版',
    'order' => '生产工单',
    _ => type,
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
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    dense: true,
                    leading: Chip(
                      label: Text(
                        _refTypeLabel(item.refType),
                        style: const TextStyle(fontSize: 11),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    title: Text(item.refName),
                    subtitle: Text(
                      [
                        '编码/编号：${item.refId}',
                        if (item.detail != null && item.detail!.trim().isNotEmpty)
                          item.detail!,
                      ].join('\n'),
                    ),
                    trailing: Text(
                      item.refId,
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
