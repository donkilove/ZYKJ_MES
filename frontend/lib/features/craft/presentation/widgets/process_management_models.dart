import 'package:mes_client/features/craft/models/craft_models.dart';

enum StageAction { edit, toggle, viewReference, delete }

enum ProcessAction { edit, toggle, viewReference, delete }

enum ProcessManagementPrimaryView { processList, stageList }

class ProcessManagementViewState {
  const ProcessManagementViewState({
    required this.loading,
    required this.message,
    required this.jumpNotice,
    required this.stages,
    required this.processes,
    required this.stageTotal,
    required this.processTotal,
    required this.stagePage,
    required this.processPage,
    required this.stageKeyword,
    required this.processKeyword,
    required this.processStageFilter,
    required this.focusedProcessId,
    required this.lastHandledJumpRequestId,
    required this.activeView,
  });

  final bool loading;
  final String message;
  final String jumpNotice;
  final List<CraftStageItem> stages;
  final List<CraftProcessItem> processes;
  final int stageTotal;
  final int processTotal;
  final int stagePage;
  final int processPage;
  final String stageKeyword;
  final String processKeyword;
  final int? processStageFilter;
  final int? focusedProcessId;
  final int lastHandledJumpRequestId;
  final ProcessManagementPrimaryView activeView;

  ProcessManagementViewState copyWith({
    bool? loading,
    String? message,
    String? jumpNotice,
    List<CraftStageItem>? stages,
    List<CraftProcessItem>? processes,
    int? stageTotal,
    int? processTotal,
    int? stagePage,
    int? processPage,
    String? stageKeyword,
    String? processKeyword,
    int? processStageFilter,
    int? focusedProcessId,
    bool clearFocusedProcessId = false,
    int? lastHandledJumpRequestId,
    ProcessManagementPrimaryView? activeView,
  }) {
    return ProcessManagementViewState(
      loading: loading ?? this.loading,
      message: message ?? this.message,
      jumpNotice: jumpNotice ?? this.jumpNotice,
      stages: stages ?? this.stages,
      processes: processes ?? this.processes,
      stageTotal: stageTotal ?? this.stageTotal,
      processTotal: processTotal ?? this.processTotal,
      stagePage: stagePage ?? this.stagePage,
      processPage: processPage ?? this.processPage,
      stageKeyword: stageKeyword ?? this.stageKeyword,
      processKeyword: processKeyword ?? this.processKeyword,
      processStageFilter: processStageFilter ?? this.processStageFilter,
      focusedProcessId: clearFocusedProcessId
          ? null
          : focusedProcessId ?? this.focusedProcessId,
      lastHandledJumpRequestId:
          lastHandledJumpRequestId ?? this.lastHandledJumpRequestId,
      activeView: activeView ?? this.activeView,
    );
  }

  static const empty = ProcessManagementViewState(
    loading: false,
    message: '',
    jumpNotice: '',
    stages: <CraftStageItem>[],
    processes: <CraftProcessItem>[],
    stageTotal: 0,
    processTotal: 0,
    stagePage: 1,
    processPage: 1,
    stageKeyword: '',
    processKeyword: '',
    processStageFilter: null,
    focusedProcessId: null,
    lastHandledJumpRequestId: -1,
    activeView: ProcessManagementPrimaryView.processList,
  );
}

class RefEntry {
  RefEntry(this.refType, this.refName, this.refId, this.detail);

  final String refType;
  final String refName;
  final String refId;
  final String? detail;
}
