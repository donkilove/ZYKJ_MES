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
import 'package:mes_client/features/craft/presentation/widgets/process_reference_dialog.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_state.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_view_switch.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_stage_dialog.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_stage_panel.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_toggle_dialogs.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';

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
        onSubmit:
            ({
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
        onSubmit:
            ({
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
        final nextEnabled = !item.isEnabled;
        final confirmed = await showStageToggleDialog(
          context: context,
          stage: item,
          nextEnabled: nextEnabled,
        );
        if (!confirmed || !mounted) {
          return;
        }
        try {
          await _service.updateStage(
            stageId: item.id,
            code: item.code,
            name: item.name,
            sortOrder: item.sortOrder,
            isEnabled: nextEnabled,
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
        final nextEnabled = !item.isEnabled;
        final confirmed = await showProcessToggleDialog(
          context: context,
          process: item,
          nextEnabled: nextEnabled,
        );
        if (!confirmed || !mounted) {
          return;
        }
        try {
          await _service.updateProcess(
            processId: item.id,
            code: item.code,
            name: item.name,
            stageId: item.stageId ?? 0,
            isEnabled: nextEnabled,
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
          final result = await _service.getProcessReferences(
            processId: item.id,
          );
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
    showProcessReferenceDialog(
      context: context,
      title: '工段引用分析：${stage.name}',
      loader: () => _service
          .getStageReferences(stageId: stage.id)
          .then(
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
    );
  }

  void _showProcessReferenceDialog(CraftProcessItem process) {
    showProcessReferenceDialog(
      context: context,
      title: '工序引用分析：${process.name}',
      loader: () => _service
          .getProcessReferences(processId: process.id)
          .then(
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
          ? const MesLoadingState(label: '工艺视图加载中...')
          : workspace,
    );
  }
}
