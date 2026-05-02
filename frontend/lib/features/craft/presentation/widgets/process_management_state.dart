import 'package:flutter/foundation.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';

class ProcessManagementState extends ChangeNotifier {
  static const int stagePageSize = 10;
  static const int processPageSize = 10;

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

  List<CraftStageItem> get filteredStages => _viewState.stages;

  List<CraftProcessItem> get filteredProcesses => _viewState.processes;

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
    _viewState = _viewState.copyWith(
      loading: true,
      message: '',
      stagePage: 1,
      processPage: 1,
    );
    notifyListeners();
    try {
      final stageResult = await _service.listStages(
        page: _viewState.stagePage,
        pageSize: stagePageSize,
        keyword: _viewState.stageKeyword,
      );
      final stages = [...stageResult.items]..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        return orderCompare != 0 ? orderCompare : a.id.compareTo(b.id);
      });
      final stageSortOrderById = <int, int>{
        for (final item in stages) item.id: item.sortOrder,
      };
      const missingStageSortOrder = 1 << 30;
      final processResult = await _service.listProcesses(
        page: _viewState.processPage,
        pageSize: processPageSize,
        keyword: _viewState.processKeyword,
        stageId: _viewState.processStageFilter,
      );
      final processes = [...processResult.items]..sort((a, b) {
        final stageOrderCompare =
            (stageSortOrderById[a.stageId] ?? missingStageSortOrder).compareTo(
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
        stageTotal: stageResult.total,
        processTotal: processResult.total,
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
    _viewState = _viewState.copyWith(stageKeyword: value.trim(), stagePage: 1);
    notifyListeners();
  }

  void setProcessKeyword(String value) {
    _viewState = _viewState.copyWith(processKeyword: value.trim(), processPage: 1);
    notifyListeners();
  }

  void setProcessStageFilter(int? stageId) {
    _viewState = _viewState.copyWith(
      processStageFilter: stageId,
      processPage: 1,
    );
    notifyListeners();
  }

  Future<void> reloadStages({int? page}) async {
    _viewState = _viewState.copyWith(
      loading: true,
      message: '',
      stagePage: page ?? _viewState.stagePage,
    );
    notifyListeners();
    try {
      final result = await _service.listStages(
        page: _viewState.stagePage,
        pageSize: stagePageSize,
        keyword: _viewState.stageKeyword,
      );
      final stages = [...result.items]..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        return orderCompare != 0 ? orderCompare : a.id.compareTo(b.id);
      });
      _viewState = _viewState.copyWith(
        loading: false,
        stages: stages,
        stageTotal: result.total,
      );
      notifyListeners();
    } catch (error) {
      if (_isUnauthorized(error)) {
        _onUnauthorized();
        return;
      }
      _viewState = _viewState.copyWith(
        loading: false,
        message: '加载工段列表失败：${_errorMessage(error)}',
      );
      notifyListeners();
    }
  }

  Future<void> reloadProcesses({int? page}) async {
    _viewState = _viewState.copyWith(
      loading: true,
      message: '',
      processPage: page ?? _viewState.processPage,
    );
    notifyListeners();
    try {
      final processResult = await _service.listProcesses(
        page: _viewState.processPage,
        pageSize: processPageSize,
        keyword: _viewState.processKeyword,
        stageId: _viewState.processStageFilter,
      );
      final stageSortOrderById = <int, int>{
        for (final item in _viewState.stages) item.id: item.sortOrder,
      };
      const missingStageSortOrder = 1 << 30;
      final processes = [...processResult.items]..sort((a, b) {
        final stageOrderCompare =
            (stageSortOrderById[a.stageId] ?? missingStageSortOrder).compareTo(
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
        processes: processes,
        processTotal: processResult.total,
      );
      notifyListeners();
    } catch (error) {
      if (_isUnauthorized(error)) {
        _onUnauthorized();
        return;
      }
      _viewState = _viewState.copyWith(
        loading: false,
        message: '加载工序列表失败：${_errorMessage(error)}',
      );
      notifyListeners();
    }
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
