# 工序管理页紧凑工作台重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变业务行为和接口语义的前提下，将 `process_management_page.dart` 重构为“默认工序主视图 + 工段辅助入口”的紧凑工作台，并显著降低主页面文件复杂度。

**Architecture:** 保留现有 `CraftService`、页面参数和 jump 语义，把页面重构为“入口页 + 页面状态编排层 + 视图切换区 + 工序/工段两个可切换主视图 + 独立弹窗”。页面外层接入工艺模块语义页头和统一容器，顶部反馈区独立，默认展示工序列表，工段列表作为辅助入口，不再保留固定详情卡片。

**Tech Stack:** Flutter、Dart、Material 3、现有 `core/ui/patterns`、`flutter_test`、`integration_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git` 与 `evidence` 操作默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”，且所有提交信息必须使用中文。

## 文件结构

### 新增文件

- `frontend/lib/features/craft/presentation/widgets/process_management_models.dart`
  - 放置 action enum、视图枚举、轻量 view state、引用条目类型
- `frontend/lib/features/craft/presentation/widgets/process_management_state.dart`
  - 管理页面级联动状态与动作分发
- `frontend/lib/features/craft/presentation/widgets/process_management_page_header.dart`
  - 工艺模块语义页头，内部接 `MesPageHeader`
- `frontend/lib/features/craft/presentation/widgets/process_management_feedback_banner.dart`
  - 统一渲染 `_message / _jumpNotice`
- `frontend/lib/features/craft/presentation/widgets/process_management_view_switch.dart`
  - 负责“工序列表 / 工段列表”切换
- `frontend/lib/features/craft/presentation/widgets/process_stage_panel.dart`
  - 工段搜索、工段列表、工段操作
- `frontend/lib/features/craft/presentation/widgets/process_item_panel.dart`
  - 工序搜索、工段筛选、工序列表、工序操作
- `frontend/lib/features/craft/presentation/widgets/process_stage_dialog.dart`
  - 新建/编辑工段弹窗
- `frontend/lib/features/craft/presentation/widgets/process_item_dialog.dart`
  - 新建/编辑工序弹窗
- `frontend/lib/features/craft/presentation/widgets/process_delete_dialogs.dart`
  - 删除确认弹窗
- `evidence/verification_20260423_process_management_compact_workbench_plan.md`
  - 本轮 implementation plan 验证留痕

### 修改文件

- `frontend/lib/features/craft/presentation/process_management_page.dart`
  - 收缩为页面入口、生命周期入口和骨架装配
- `frontend/test/widgets/process_management_page_test.dart`
  - 更新为紧凑工作台 + 视图切换后的行为断言
- `frontend/test/widgets/craft_page_test.dart`
  - 维持 craft 页签接线不回归
- `frontend/integration_test/home_shell_flow_test.dart`
  - 维持消息跳转到工序管理页不回归

## 任务 1：先把目标行为固定成失败测试

**Files:**
- Modify: `frontend/test/widgets/process_management_page_test.dart`
- Test: `frontend/test/widgets/process_management_page_test.dart`

- [ ] **Step 1: 扩展 widget 测试，固定默认工序主视图和视图切换**

```dart
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

testWidgets('默认进入工序主视图并显示视图切换按钮', (tester) async {
  await _pumpProcessManagementPage(tester, size: const Size(1400, 1200));

  expect(find.byType(MesPageHeader), findsOneWidget);
  expect(find.byKey(const ValueKey('process-management-feedback-banner')), findsOneWidget);
  expect(find.byKey(const ValueKey('process-management-view-switch')), findsOneWidget);
  expect(find.byKey(const ValueKey('process-item-panel')), findsOneWidget);
  expect(find.byKey(const ValueKey('process-stage-panel')), findsNothing);
  expect(find.text('工序列表'), findsWidgets);
  expect(find.text('工段列表'), findsWidgets);
});
```

- [ ] **Step 2: 固定切换到工段视图的行为**

```dart
testWidgets('点击工段列表按钮后切换到工段视图', (tester) async {
  await _pumpProcessManagementPage(tester, size: const Size(1400, 1200));

  await tester.tap(find.byKey(const ValueKey('process-view-switch-stage')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('process-stage-panel')), findsOneWidget);
  expect(find.byKey(const ValueKey('process-item-panel')), findsNothing);
});
```

- [ ] **Step 3: 固定 jump 命中工序时自动回到工序视图**

```dart
testWidgets('jump 命中工序时自动停留在工序视图并展示反馈横幅', (tester) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProcessManagementPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          canWrite: true,
          craftService: _FakeCraftService(),
          processId: 11,
          jumpRequestId: 1,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  expect(find.byKey(const ValueKey('process-item-panel')), findsOneWidget);
  expect(find.byKey(const ValueKey('process-stage-panel')), findsNothing);
  expect(find.byKey(const ValueKey('process-management-feedback-banner')), findsOneWidget);
  expect(find.textContaining('已定位工序 #11 激光切割'), findsOneWidget);
  expect(find.textContaining('编码：CUT-01'), findsOneWidget);
});
```

- [ ] **Step 4: 运行测试，确认新方向先红灯**

Run: `flutter test test/widgets/process_management_page_test.dart -r expanded`

Expected: FAIL，至少一个断言报 `process-management-view-switch`、`process-item-panel` 或 `process-stage-panel` 与当前结构不一致。

- [ ] **Step 5: 提交失败测试快照**

```bash
git add frontend/test/widgets/process_management_page_test.dart
git commit -m "补充工序管理页紧凑工作台失败测试"
```

## 任务 2：建立页面模型与状态编排层

**Files:**
- Create: `frontend/lib/features/craft/presentation/widgets/process_management_models.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_management_state.dart`
- Modify: `frontend/lib/features/craft/presentation/process_management_page.dart`
- Test: `frontend/test/widgets/process_management_page_test.dart`

- [ ] **Step 1: 定义新的页面模型，加入主视图枚举**

```dart
// frontend/lib/features/craft/presentation/widgets/process_management_models.dart
import 'package:mes_client/features/craft/models/craft_models.dart';

enum StageAction { edit, toggle, viewReference, delete }
enum ProcessAction { edit, toggle, viewReference, delete }
enum ProcessManagementPrimaryView { processList, stageList }

class RefEntry {
  RefEntry(this.refType, this.refName, this.refId, this.detail);

  final String refType;
  final String refName;
  final String refId;
  final String? detail;
}

class ProcessManagementViewState {
  const ProcessManagementViewState({
    required this.loading,
    required this.message,
    required this.jumpNotice,
    required this.stages,
    required this.processes,
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
    stageKeyword: '',
    processKeyword: '',
    processStageFilter: null,
    focusedProcessId: null,
    lastHandledJumpRequestId: -1,
    activeView: ProcessManagementPrimaryView.processList,
  );
}
```

- [ ] **Step 2: 状态编排层接入 activeView 和 jump 强制切回工序视图**

```dart
// frontend/lib/features/craft/presentation/widgets/process_management_state.dart
import 'package:flutter/foundation.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

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
    if (kw.isEmpty) return _viewState.stages;
    return _viewState.stages
        .where(
          (s) =>
              s.code.toLowerCase().contains(kw) ||
              s.name.toLowerCase().contains(kw),
        )
        .toList();
  }

  List<CraftProcessItem> get filteredProcesses {
    var list = _viewState.processes;
    if (_viewState.processStageFilter != null) {
      list = list.where((p) => p.stageId == _viewState.processStageFilter).toList();
    }
    final kw = _viewState.processKeyword.trim().toLowerCase();
    if (kw.isEmpty) return list;
    return list
        .where(
          (p) =>
              p.code.toLowerCase().contains(kw) ||
              p.name.toLowerCase().contains(kw) ||
              (p.stageName?.toLowerCase().contains(kw) ?? false),
        )
        .toList();
  }

  CraftProcessItem? get focusedProcess {
    final id = _viewState.focusedProcessId;
    if (id == null) return null;
    for (final item in _viewState.processes) {
      if (item.id == id) return item;
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
              (stageSortOrderById[a.stageId] ?? missingStageSortOrder).compareTo(
                stageSortOrderById[b.stageId] ?? missingStageSortOrder,
              );
          if (stageOrderCompare != 0) return stageOrderCompare;
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
    if (jumpRequestId == _viewState.lastHandledJumpRequestId) return;
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
```

- [ ] **Step 3: 主页面先只接状态编排层**

Run: `flutter test test/widgets/process_management_page_test.dart -r expanded`

Expected: PASS 或仅保留任务 1 里的新断言失败。

- [ ] **Step 4: 提交状态编排层地基**

```bash
git add frontend/lib/features/craft/presentation/widgets/process_management_models.dart frontend/lib/features/craft/presentation/widgets/process_management_state.dart frontend/lib/features/craft/presentation/process_management_page.dart frontend/test/widgets/process_management_page_test.dart
git commit -m "建立工序管理页紧凑工作台状态地基"
```

## 任务 3：抽出页头、反馈区、视图切换和两个主视图

**Files:**
- Create: `frontend/lib/features/craft/presentation/widgets/process_management_page_header.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_management_feedback_banner.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_management_view_switch.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_stage_panel.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_item_panel.dart`
- Modify: `frontend/lib/features/craft/presentation/process_management_page.dart`
- Test: `frontend/test/widgets/process_management_page_test.dart`

- [ ] **Step 1: 新增页头和反馈区**

```dart
// frontend/lib/features/craft/presentation/widgets/process_management_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProcessManagementPageHeader extends StatelessWidget {
  const ProcessManagementPageHeader({
    super.key,
    required this.loading,
    required this.canWrite,
    required this.onRefresh,
    required this.onCreateStage,
    required this.onCreateProcess,
  });

  final bool loading;
  final bool canWrite;
  final VoidCallback onRefresh;
  final VoidCallback onCreateStage;
  final VoidCallback onCreateProcess;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '工序管理',
      subtitle: '默认工序主视图，工段作为辅助入口。',
      actions: [
        OutlinedButton.icon(
          key: const ValueKey('process-management-refresh-button'),
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
        FilledButton.icon(
          key: const ValueKey('process-management-create-stage-button'),
          onPressed: loading || !canWrite ? null : onCreateStage,
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('新建工段'),
        ),
        FilledButton.icon(
          key: const ValueKey('process-management-create-process-button'),
          onPressed: loading || !canWrite ? null : onCreateProcess,
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('新建工序'),
        ),
      ],
    );
  }
}
```

```dart
// frontend/lib/features/craft/presentation/widgets/process_management_feedback_banner.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

class ProcessManagementFeedbackBanner extends StatelessWidget {
  const ProcessManagementFeedbackBanner({
    super.key,
    required this.message,
    required this.jumpNotice,
  });

  final String message;
  final String jumpNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = message.trim().isNotEmpty;
    final text = hasError ? message.trim() : jumpNotice.trim();

    return KeyedSubtree(
      key: const ValueKey('process-management-feedback-banner'),
      child: text.isEmpty
          ? const SizedBox.shrink()
          : MesSurface(
              tone: hasError ? MesSurfaceTone.normal : MesSurfaceTone.subtle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hasError
                        ? Icons.error_outline_rounded
                        : Icons.assistant_direction_outlined,
                    color: hasError ? theme.colorScheme.error : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: hasError
                          ? theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            )
                          : theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 2: 新增视图切换区**

```dart
// frontend/lib/features/craft/presentation/widgets/process_management_view_switch.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

class ProcessManagementViewSwitch extends StatelessWidget {
  const ProcessManagementViewSwitch({
    super.key,
    required this.activeView,
    required this.onChanged,
  });

  final ProcessManagementPrimaryView activeView;
  final ValueChanged<ProcessManagementPrimaryView> onChanged;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('process-management-view-switch'),
      child: SegmentedButton<ProcessManagementPrimaryView>(
        segments: const [
          ButtonSegment(
            value: ProcessManagementPrimaryView.processList,
            label: Text('工序列表'),
          ),
          ButtonSegment(
            value: ProcessManagementPrimaryView.stageList,
            label: Text('工段列表'),
          ),
        ],
        selected: {activeView},
        onSelectionChanged: (selection) => onChanged(selection.first),
        showSelectedIcon: false,
      ),
    );
  }
}
```

- [ ] **Step 3: 保留两个主视图 panel，删除固定详情面板**

```dart
// frontend/lib/features/craft/presentation/process_management_page.dart
import 'package:mes_client/features/craft/presentation/widgets/process_management_view_switch.dart';

@override
Widget build(BuildContext context) {
  final view = _pageState.viewState;
  final activePanel = switch (view.activeView) {
    ProcessManagementPrimaryView.processList => ProcessItemPanel(
        searchController: _processSearchController,
        stageFilter: view.processStageFilter,
        stageOptions: view.stages,
        items: _pageState.filteredProcesses,
        focusedProcessId: view.focusedProcessId,
        canWrite: widget.canWrite,
        onKeywordChanged: _pageState.setProcessKeyword,
        onStageFilterChanged: _pageState.setProcessStageFilter,
        onFocusProcess: _pageState.focusProcess,
        onActionSelected: _handleProcessAction,
      ),
    ProcessManagementPrimaryView.stageList => ProcessStagePanel(
        searchController: _stageSearchController,
        items: _pageState.filteredStages,
        canWrite: widget.canWrite,
        onKeywordChanged: _pageState.setStageKeyword,
        onActionSelected: _handleStageAction,
      ),
  };

  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProcessManagementPageHeader(
          loading: view.loading,
          canWrite: widget.canWrite,
          onRefresh: _loadData,
          onCreateStage: _showStageDialog,
          onCreateProcess: _showProcessDialog,
        ),
        const SizedBox(height: 12),
        ProcessManagementFeedbackBanner(
          message: view.message,
          jumpNotice: view.jumpNotice,
        ),
        const SizedBox(height: 12),
        ProcessManagementViewSwitch(
          activeView: view.activeView,
          onChanged: _pageState.setActiveView,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: view.loading
              ? const Center(child: CircularProgressIndicator())
              : activePanel,
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: 运行 widget tests，确认紧凑工作台断言转绿**

Run: `flutter test test/widgets/process_management_page_test.dart -r expanded`

Expected: PASS，尤其是：
- `默认进入工序主视图并显示视图切换按钮`
- `点击工段列表按钮后切换到工段视图`
- `jump 命中工序时自动停留在工序视图并展示反馈横幅`

- [ ] **Step 5: 提交紧凑工作台骨架**

```bash
git add frontend/lib/features/craft/presentation/process_management_page.dart frontend/lib/features/craft/presentation/widgets/process_management_page_header.dart frontend/lib/features/craft/presentation/widgets/process_management_feedback_banner.dart frontend/lib/features/craft/presentation/widgets/process_management_view_switch.dart frontend/lib/features/craft/presentation/widgets/process_stage_panel.dart frontend/lib/features/craft/presentation/widgets/process_item_panel.dart frontend/test/widgets/process_management_page_test.dart
git commit -m "重构工序管理页紧凑工作台骨架"
```

## 任务 4：拆出工段/工序弹窗和删除确认

**Files:**
- Create: `frontend/lib/features/craft/presentation/widgets/process_stage_dialog.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_item_dialog.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_delete_dialogs.dart`
- Modify: `frontend/lib/features/craft/presentation/process_management_page.dart`
- Test: `frontend/test/widgets/process_management_page_test.dart`

- [ ] **Step 1: 抽出工段弹窗**

```dart
// frontend/lib/features/craft/presentation/widgets/process_stage_dialog.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';

class ProcessStageDialog extends StatefulWidget {
  const ProcessStageDialog({
    super.key,
    this.existing,
    required this.onSubmit,
  });

  final CraftStageItem? existing;
  final Future<void> Function({
    required String code,
    required String name,
    required int sortOrder,
    required String remark,
    required bool isEnabled,
  }) onSubmit;

  @override
  State<ProcessStageDialog> createState() => _ProcessStageDialogState();
}

class _ProcessStageDialogState extends State<ProcessStageDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _sortController;
  late final TextEditingController _remarkController;
  late bool _isEnabled;
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.existing?.code ?? '');
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _sortController = TextEditingController(
      text: (widget.existing?.sortOrder ?? 0).toString(),
    );
    _remarkController = TextEditingController(text: widget.existing?.remark ?? '');
    _isEnabled = widget.existing?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _sortController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await widget.onSubmit(
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      sortOrder: int.parse(_sortController.text.trim()),
      remark: _remarkController.text.trim(),
      isEnabled: _isEnabled,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增工段' : '编辑工段'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '工段编码',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入工段编码' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '工段名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入工段名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sortController,
                decoration: const InputDecoration(
                  labelText: '排序',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || int.tryParse(value.trim()) == null
                    ? '请输入有效排序'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLength: 500,
                maxLines: 3,
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isEnabled,
                  onChanged: (value) => setState(() => _isEnabled = value),
                  title: const Text('启用'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 抽出工序弹窗和删除确认**

```dart
// frontend/lib/features/craft/presentation/widgets/process_item_dialog.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';

class ProcessItemDialog extends StatefulWidget {
  const ProcessItemDialog({
    super.key,
    this.existing,
    required this.stages,
    required this.onSubmit,
  });

  final CraftProcessItem? existing;
  final List<CraftStageItem> stages;
  final Future<void> Function({
    required String codeSuffix,
    required String name,
    required int stageId,
    required String remark,
    required bool isEnabled,
  }) onSubmit;

  @override
  State<ProcessItemDialog> createState() => _ProcessItemDialogState();
}

class _ProcessItemDialogState extends State<ProcessItemDialog> {
  late final TextEditingController _codeSuffixController;
  late final TextEditingController _nameController;
  late final TextEditingController _remarkController;
  late int _stageId;
  late bool _isEnabled;
  bool _legacyCodeInvalid = false;
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _stageId = widget.existing?.stageId ?? widget.stages.first.id;
    final initialSerial = _buildInitialSerial();
    _legacyCodeInvalid = widget.existing != null && initialSerial.isEmpty;
    _codeSuffixController = TextEditingController(text: initialSerial);
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _remarkController = TextEditingController(text: widget.existing?.remark ?? '');
    _isEnabled = widget.existing?.isEnabled ?? true;
  }

  String _buildInitialSerial() {
    final existing = widget.existing;
    if (existing == null) return '';
    final stage = widget.stages.firstWhere(
      (item) => item.id == existing.stageId,
      orElse: () => widget.stages.first,
    );
    final prefix = '${stage.code}-';
    if (!existing.code.startsWith(prefix)) return '';
    final serial = existing.code.substring(prefix.length);
    if (serial.length != 2 || int.tryParse(serial) == null || serial == '00') {
      return '';
    }
    return serial;
  }

  @override
  void dispose() {
    _codeSuffixController.dispose();
    _nameController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await widget.onSubmit(
      codeSuffix: _codeSuffixController.text.trim(),
      name: _nameController.text.trim(),
      stageId: _stageId,
      remark: _remarkController.text.trim(),
      isEnabled: _isEnabled,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stages.firstWhere((item) => item.id == _stageId);
    final serialText = _codeSuffixController.text.trim();
    final fullCodePreview = serialText.isEmpty
        ? '${stage.code}-__'
        : '${stage.code}-$serialText';
    return AlertDialog(
      title: Text(widget.existing == null ? '新增工序' : '编辑工序'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _stageId,
                decoration: const InputDecoration(
                  labelText: '所属工段',
                  border: OutlineInputBorder(),
                ),
                items: widget.stages
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text('${item.name} (${item.code})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _stageId = value;
                    _codeSuffixController.clear();
                    _legacyCodeInvalid = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeSuffixController,
                decoration: const InputDecoration(
                  labelText: '工序编码序号（两位）',
                  hintText: '例如 01',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final serial = (value ?? '').trim();
                  if (serial.isEmpty) return '请输入两位序号';
                  if (serial.length != 2 || int.tryParse(serial) == null) {
                    return '序号必须是两位数字';
                  }
                  if (serial == '00') return '序号必须是 01-99';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                '完整编码预览：$fullCodePreview',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_legacyCodeInvalid) ...[
                const SizedBox(height: 8),
                Text(
                  '历史编码不符合新规则，请按“工段编码-两位序号”重新填写。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '小工序名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入工序名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLength: 500,
                maxLines: 3,
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isEnabled,
                  onChanged: (value) => setState(() => _isEnabled = value),
                  title: const Text('启用'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}
```

```dart
// frontend/lib/features/craft/presentation/widgets/process_delete_dialogs.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

Future<bool> showDeleteDialog(
  BuildContext context, {
  required String title,
  required String targetName,
  required List<RefEntry> refs,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确认删除 $targetName 吗？'),
            if (refs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '该对象存在 ${refs.length} 条引用关系：',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
  return result ?? false;
}
```

- [ ] **Step 3: 主页面切到紧凑工作台逻辑并调用独立弹窗**

Run: `flutter test test/widgets/process_management_page_test.dart -r expanded`

Expected: PASS，尤其保留：
- `工序管理支持新增与删除工序`
- `jump 命中工序时自动停留在工序视图并展示反馈横幅`

- [ ] **Step 4: 提交弹窗与切换逻辑**

```bash
git add frontend/lib/features/craft/presentation/process_management_page.dart frontend/lib/features/craft/presentation/widgets/process_stage_dialog.dart frontend/lib/features/craft/presentation/widgets/process_item_dialog.dart frontend/lib/features/craft/presentation/widgets/process_delete_dialogs.dart frontend/test/widgets/process_management_page_test.dart
git commit -m "拆分工序管理页紧凑工作台弹窗与切换逻辑"
```

## 任务 5：补齐 craft 入口、集成回归与留痕

**Files:**
- Modify: `frontend/test/widgets/craft_page_test.dart`
- Modify: `frontend/integration_test/home_shell_flow_test.dart`
- Create: `evidence/verification_20260423_process_management_compact_workbench_plan.md`

- [ ] **Step 1: craft 入口保持不回归**

```dart
// frontend/test/widgets/craft_page_test.dart
testWidgets('CraftPage 支持字符串 routePayloadJson 并分发到工序管理页签', (tester) async {
  await pumpCraftPage(
    tester,
    visibleTabCodes: const [
      processManagementTabCode,
      productionProcessConfigTabCode,
    ],
    preferredTabCode: productionProcessConfigTabCode,
    routePayloadJson:
        '{"target_tab_code":"process_management","process_id":"11"}',
    tabPageBuilder: (tabCode, child) {
      if (child is ProcessManagementPage) {
        return Center(
          child: Text('pm:${child.processId}:${child.jumpRequestId}'),
        );
      }
      return child;
    },
  );

  expect(find.text('pm:11:1'), findsOneWidget);
});
```

- [ ] **Step 2: 更新集成测试到新锚点**

```dart
// frontend/integration_test/home_shell_flow_test.dart
expect(find.text('工序管理'), findsWidgets);
expect(find.byKey(const ValueKey('process-management-feedback-banner')), findsOneWidget);
expect(find.byKey(const ValueKey('process-management-view-switch')), findsOneWidget);
expect(find.byKey(const ValueKey('process-item-panel')), findsOneWidget);
expect(find.byKey(const ValueKey('process-stage-panel')), findsNothing);
```

- [ ] **Step 3: 跑完整验证命令**

Run: `flutter test test/widgets/process_management_page_test.dart test/widgets/craft_page_test.dart -r expanded`

Expected: PASS

Run: `flutter test integration_test/home_shell_flow_test.dart -d windows --plain-name "登录后经主壳和消息中心跳转到工艺工序管理页" -r expanded`

Expected: PASS

Run: `flutter analyze lib/features/craft/presentation/process_management_page.dart lib/features/craft/presentation/widgets/process_management_models.dart lib/features/craft/presentation/widgets/process_management_state.dart lib/features/craft/presentation/widgets/process_management_page_header.dart lib/features/craft/presentation/widgets/process_management_feedback_banner.dart lib/features/craft/presentation/widgets/process_management_view_switch.dart lib/features/craft/presentation/widgets/process_stage_panel.dart lib/features/craft/presentation/widgets/process_item_panel.dart lib/features/craft/presentation/widgets/process_stage_dialog.dart lib/features/craft/presentation/widgets/process_item_dialog.dart lib/features/craft/presentation/widgets/process_delete_dialogs.dart`

Expected: `No issues found!`

- [ ] **Step 4: 更新验证留痕**

```md
# 工具化验证日志：工序管理页紧凑工作台计划执行

- 执行日期：2026-04-23
- 对应 spec：`docs/superpowers/specs/2026-04-23-process-management-redesign-design.md`
- 当前状态：待执行

## 计划验证命令
- `flutter test test/widgets/process_management_page_test.dart test/widgets/craft_page_test.dart -r expanded`
- `flutter test integration_test/home_shell_flow_test.dart -d windows --plain-name "登录后经主壳和消息中心跳转到工艺工序管理页" -r expanded`
- `flutter analyze lib/features/craft/presentation/process_management_page.dart ...`

## 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 5: 提交回归与留痕**

```bash
git add frontend/test/widgets/process_management_page_test.dart frontend/test/widgets/craft_page_test.dart frontend/integration_test/home_shell_flow_test.dart evidence/verification_20260423_process_management_compact_workbench_plan.md
git commit -m "补齐工序管理页紧凑工作台回归验证"
```

## 计划自检结论

### Spec 覆盖

已覆盖 spec 中以下要求：

1. 默认工序主视图
2. 工段辅助入口
3. 去掉固定详情卡片
4. jump 强制回到工序视图
5. 结构拆分与统一骨架
6. widget / integration / analyze 验证

### 占位词扫描

本计划未使用 `TODO`、`TBD`、`待定`、`implement later` 等占位词。

### 一致性检查

已统一使用以下命名：

1. `ProcessManagementPrimaryView`
2. `ProcessManagementState`
3. `ProcessManagementViewSwitch`
4. `ProcessManagementPageHeader`
5. `ProcessManagementFeedbackBanner`
6. `ProcessStagePanel`
7. `ProcessItemPanel`

未在后续任务中继续引用已废弃的 `process_focus_panel.dart` 作为实现目标。
