import 'package:flutter/foundation.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';

class ProcessManagementState extends ChangeNotifier {
  ProcessManagementState({
    required CraftService service,
    required VoidCallback onUnauthorized,
  }) : _service = service,
       _onUnauthorized = onUnauthorized;

  final CraftService _service;
  final VoidCallback _onUnauthorized;

  ProcessManagementViewState _viewState = ProcessManagementViewState.empty;
  ProcessManagementViewState get viewState => _viewState;

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) =>
      error is ApiException ? error.message : error.toString();

  List<CraftStageItem> get filteredStages {
    final kw = _viewState.stageKeyword.trim().toLowerCase();
    if (kw.isEmpty) {
      return _viewState.stages;
    }
    return _viewState.stages
        .where(
          (stage) =>
              stage.code.toLowerCase().contains(kw) ||
              stage.name.toLowerCase().contains(kw),
        )
        .toList();
  }

  List<CraftProcessItem> get filteredProcesses {
    var list = _viewState.processes;
    if (_viewState.processStageFilter != null) {
      list = list
          .where((process) => process.stageId == _viewState.processStageFilter)
          .toList();
    }
    final kw = _viewState.processKeyword.trim().toLowerCase();
    if (kw.isEmpty) {
      return list;
    }
    return list
        .where(
          (process) =>
              process.code.toLowerCase().contains(kw) ||
              process.name.toLowerCase().contains(kw) ||
              (process.stageName?.toLowerCase().contains(kw) ?? false),
        )
        .toList();
  }

  CraftProcessItem? get focusedProcess {
    final focusedId = _viewState.focusedProcessId;
    if (focusedId == null) {
      return null;
    }
    for (final item in _viewState.processes) {
      if (item.id == focusedId) {
        return item;
      }
    }
    return null;
  }

  Future<void> loadData() async {
    _viewState = _viewState.copyWith(loading: true, message: '');
    notifyListeners();
    try {
      final stageResult = await _service.listStages(pageSize: 500);
      final processResult = await _service.listProcesses(pageSize: 500);
      final stages = [...stageResult.items]
        ..sort((a, b) {
          final orderCompare = a.sortOrder.compareTo(b.sortOrder);
          return orderCompare != 0 ? orderCompare : a.id.compareTo(b.id);
        });
      final stageSortOrderById = <int, int>{
        for (final item in stages) item.id: item.sortOrder,
      };
      const missingStageSortOrder = 1 << 30;
      final processes = [...processResult.items]
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
          return codeCompare != 0 ? codeCompare : a.id.compareTo(b.id);
        });
      _viewState = _viewState.copyWith(
        loading: false,
        stages: stages,
        processes: processes,
      );
      notifyListeners();
    } catch (error) {
      if (_isUnauthorized(error)) {
        _onUnauthorized();
        return;
      }
      _viewState = _viewState.copyWith(
        loading: false,
        message: '加载工艺数据失败：${_errorMessage(error)}',
      );
      notifyListeners();
    }
  }

  void setStageKeyword(String value) {
    _viewState = _viewState.copyWith(stageKeyword: value.trim());
    notifyListeners();
  }

  void setProcessKeyword(String value) {
    _viewState = _viewState.copyWith(processKeyword: value.trim());
    notifyListeners();
  }

  void setProcessStageFilter(int? stageId) {
    _viewState = _viewState.copyWith(processStageFilter: stageId);
    notifyListeners();
  }

  void setActiveView(ProcessManagementPrimaryView view) {
    _viewState = _viewState.copyWith(activeView: view);
    notifyListeners();
  }

  void focusProcess(int? processId) {
    _viewState = _viewState.copyWith(focusedProcessId: processId);
    notifyListeners();
  }

  void applyJumpTarget({
    required int? processId,
    required int jumpRequestId,
  }) {
    if (jumpRequestId == _viewState.lastHandledJumpRequestId) {
      return;
    }
    if (processId == null || processId <= 0) {
      _viewState = _viewState.copyWith(lastHandledJumpRequestId: jumpRequestId);
      notifyListeners();
      return;
    }
    CraftProcessItem? matched;
    for (final item in _viewState.processes) {
      if (item.id == processId) {
        matched = item;
        break;
      }
    }
    if (matched == null) {
      _viewState = _viewState.copyWith(
        jumpNotice: '未找到目标工序记录 #$processId',
        clearFocusedProcessId: true,
        lastHandledJumpRequestId: jumpRequestId,
        activeView: ProcessManagementPrimaryView.processList,
      );
      notifyListeners();
      return;
    }
    _viewState = _viewState.copyWith(
      processStageFilter: matched.stageId,
      processKeyword: '',
      focusedProcessId: matched.id,
      jumpNotice: '已定位工序 #${matched.id} ${matched.name}',
      lastHandledJumpRequestId: jumpRequestId,
      activeView: ProcessManagementPrimaryView.processList,
    );
    notifyListeners();
  }
}
