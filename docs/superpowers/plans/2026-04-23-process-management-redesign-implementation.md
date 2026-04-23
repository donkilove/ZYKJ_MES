# 工序管理页重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变业务行为和接口语义的前提下，将 `process_management_page.dart` 重构为统一骨架的三栏工艺工作台，并显著降低主页面文件复杂度。

**Architecture:** 保留现有 `CraftService`、页面参数和 jump 语义，把页面重构为“入口页 + 页面状态编排层 + 业务区块 widgets + 独立弹窗”。页面外层接入工艺模块语义页头和统一 section 容器，顶部反馈区独立，主体采用左工段、中工序、右聚焦详情的三栏工作台。

**Tech Stack:** Flutter、Dart、Material 3、现有 `core/ui/patterns`、`flutter_test`、`integration_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git` 与 `evidence` 操作默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”，且所有提交信息必须使用中文。

## 文件结构

### 新增文件

- `frontend/lib/features/craft/presentation/widgets/process_management_models.dart`
  - 放置页面内部 action enum、轻量 view model、筛选快照类型
- `frontend/lib/features/craft/presentation/widgets/process_management_state.dart`
  - 管理页面级联动状态与动作分发
- `frontend/lib/features/craft/presentation/widgets/process_management_page_header.dart`
  - 工艺模块语义页头，内部接 `MesPageHeader`
- `frontend/lib/features/craft/presentation/widgets/process_management_feedback_banner.dart`
  - 统一渲染 `_message / _jumpNotice`
- `frontend/lib/features/craft/presentation/widgets/process_stage_panel.dart`
  - 左侧工段面板
- `frontend/lib/features/craft/presentation/widgets/process_item_panel.dart`
  - 中间工序面板
- `frontend/lib/features/craft/presentation/widgets/process_focus_panel.dart`
  - 右侧聚焦工序详情/空态
- `frontend/lib/features/craft/presentation/widgets/process_stage_dialog.dart`
  - 新建/编辑工段弹窗
- `frontend/lib/features/craft/presentation/widgets/process_item_dialog.dart`
  - 新建/编辑工序弹窗
- `frontend/lib/features/craft/presentation/widgets/process_delete_dialogs.dart`
  - 删除确认弹窗
- `evidence/verification_20260423_process_management_redesign_plan.md`
  - 本轮 implementation plan 验证留痕

### 修改文件

- `frontend/lib/features/craft/presentation/process_management_page.dart`
  - 收缩为页面入口、生命周期入口和骨架装配
- `frontend/test/widgets/process_management_page_test.dart`
  - 更新为统一骨架 + 结构拆分后的行为断言
- `frontend/test/widgets/craft_page_test.dart`
  - 维持 craft 页签接线不回归
- `frontend/integration_test/home_shell_flow_test.dart`
  - 维持消息跳转到工序管理页不回归
- `evidence/task_log_20260422_process_management_redesign_brainstorming.md`
  - 补 implementation plan 接续信息（若需）

## 任务 1：先把目标行为固定成失败测试

**Files:**
- Modify: `frontend/test/widgets/process_management_page_test.dart`
- Test: `frontend/test/widgets/process_management_page_test.dart`

- [ ] **Step 1: 扩展 widget 测试，先固定统一骨架和三栏结构**

```dart
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

testWidgets('中等桌面宽度下使用统一页头和三栏工作台', (tester) async {
  await _pumpProcessManagementPage(tester, size: const Size(1400, 1200));

  expect(find.byType(MesPageHeader), findsOneWidget);
  expect(find.byKey(const ValueKey('process-management-feedback-banner')), findsOneWidget);
  expect(find.byKey(const ValueKey('process-stage-panel')), findsOneWidget);
  expect(find.byKey(const ValueKey('process-item-panel')), findsOneWidget);
  expect(find.byKey(const ValueKey('process-focus-panel')), findsOneWidget);
  expect(find.byType(MesSectionCard), findsAtLeastNWidgets(3));

  final stageLeft = tester.getTopLeft(find.byKey(const ValueKey('process-stage-panel')));
  final processLeft = tester.getTopLeft(find.byKey(const ValueKey('process-item-panel')));
  final focusLeft = tester.getTopLeft(find.byKey(const ValueKey('process-focus-panel')));

  expect(processLeft.dx, greaterThan(stageLeft.dx + 80));
  expect(focusLeft.dx, greaterThan(processLeft.dx + 80));
});
```

- [ ] **Step 2: 固定 jump 命中后右栏详情承接**

```dart
testWidgets('jump 命中后在反馈区和右栏同时可见定位结果', (tester) async {
  tester.view.physicalSize = const Size(1600, 1200);
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

  expect(find.byKey(const ValueKey('process-management-feedback-banner')), findsOneWidget);
  expect(find.textContaining('已定位工序 #11 激光切割'), findsWidgets);
  expect(find.byKey(const ValueKey('process-focus-panel')), findsOneWidget);
  expect(find.textContaining('编码：CUT-01'), findsOneWidget);
});
```

- [ ] **Step 3: 运行测试，确认新骨架断言先红灯**

Run: `flutter test test/widgets/process_management_page_test.dart -r expanded`

Expected: FAIL，至少一个断言报 `MesPageHeader`、`process-stage-panel` 或 `process-focus-panel` 未找到。

- [ ] **Step 4: 提交失败测试快照**

```bash
git add frontend/test/widgets/process_management_page_test.dart
git commit -m "补充工序管理页重构前失败测试"
```

## 任务 2：建立页面内模型和状态编排层

**Files:**
- Create: `frontend/lib/features/craft/presentation/widgets/process_management_models.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_management_state.dart`
- Modify: `frontend/lib/features/craft/presentation/process_management_page.dart`
- Test: `frontend/test/widgets/process_management_page_test.dart`

- [ ] **Step 1: 新增页面模型文件，收拢 action 和轻量状态类型**

```dart
// frontend/lib/features/craft/presentation/widgets/process_management_models.dart
import 'package:mes_client/features/craft/models/craft_models.dart';

enum StageAction { edit, toggle, viewReference, delete }
enum ProcessAction { edit, toggle, viewReference, delete }

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
  );
}
```

- [ ] **Step 2: 新增状态编排层，承接跨区块联动状态**

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
    _viewState = _viewState.copyWith(stageKeyword: value);
    notifyListeners();
  }

  void setProcessKeyword(String value) {
    _viewState = _viewState.copyWith(processKeyword: value);
    notifyListeners();
  }

  void setProcessStageFilter(int? stageId) {
    _viewState = _viewState.copyWith(processStageFilter: stageId);
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
    );
    notifyListeners();
  }
}
```

- [ ] **Step 3: 在主页面先接入状态编排层，但保持现有 UI 暂时不变**

```dart
// frontend/lib/features/craft/presentation/process_management_page.dart
import 'package:mes_client/features/craft/presentation/widgets/process_management_state.dart';

late final ProcessManagementState _pageState;

@override
void initState() {
  super.initState();
  _service = widget.craftService ?? CraftService(widget.session);
  _pageState = ProcessManagementState(
    service: _service,
    onUnauthorized: widget.onLogout,
  )..addListener(_handleStateChanged);
  _pageState.loadData();
}

void _handleStateChanged() {
  if (!mounted) return;
  setState(() {});
}

@override
void dispose() {
  _pageState.removeListener(_handleStateChanged);
  _pageState.dispose();
  _stageSearchController.dispose();
  _processSearchController.dispose();
  super.dispose();
}
```

- [ ] **Step 4: 运行现有测试，确认状态编排层接入不改变行为**

Run: `flutter test test/widgets/process_management_page_test.dart -r expanded`

Expected: PASS 或仅保留任务 1 中新增的统一骨架断言失败。

- [ ] **Step 5: 提交状态编排层骨架**

```bash
git add frontend/lib/features/craft/presentation/process_management_page.dart frontend/lib/features/craft/presentation/widgets/process_management_models.dart frontend/lib/features/craft/presentation/widgets/process_management_state.dart frontend/test/widgets/process_management_page_test.dart
git commit -m "建立工序管理页状态编排骨架"
```

## 任务 3：抽出页头、反馈区和三栏工作台 widgets

**Files:**
- Create: `frontend/lib/features/craft/presentation/widgets/process_management_page_header.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_management_feedback_banner.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_stage_panel.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_item_panel.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_focus_panel.dart`
- Modify: `frontend/lib/features/craft/presentation/process_management_page.dart`
- Test: `frontend/test/widgets/process_management_page_test.dart`

- [ ] **Step 1: 新增工艺页头和反馈区**

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
      subtitle: '统一维护工段、小工序及 jump 定位工作台。',
      actions: [
        OutlinedButton.icon(
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
        FilledButton.icon(
          onPressed: loading || !canWrite ? null : onCreateStage,
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('新建工段'),
        ),
        FilledButton.icon(
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
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
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
    final text = message.isNotEmpty ? message : jumpNotice;
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: const ValueKey('process-management-feedback-banner'),
      child: message.isNotEmpty
          ? MesErrorState(message: text)
          : MesSurface(
              tone: MesSurfaceTone.subtle,
              child: Row(
                children: [
                  const Icon(Icons.assistant_direction_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 2: 新增三块工作区 panel**

```dart
// frontend/lib/features/craft/presentation/widgets/process_stage_panel.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

class ProcessStagePanel extends StatelessWidget {
  const ProcessStagePanel({
    super.key,
    required this.keyword,
    required this.onKeywordChanged,
    required this.items,
    required this.canWrite,
    required this.onActionSelected,
  });

  final String keyword;
  final ValueChanged<String> onKeywordChanged;
  final List<CraftStageItem> items;
  final bool canWrite;
  final void Function(StageAction action, CraftStageItem item) onActionSelected;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('process-stage-panel'),
      child: MesSectionCard(
        title: '工段列表',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: TextEditingController(text: keyword)
                ..selection = TextSelection.collapsed(offset: keyword.length),
              onChanged: onKeywordChanged,
              decoration: const InputDecoration(
                hintText: '搜索工段编码/名称',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('暂无工段数据'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text('${item.code} · 排序 ${item.sortOrder}'),
                          trailing: PopupMenuButton<StageAction>(
                            onSelected: (action) => onActionSelected(action, item),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: StageAction.edit, child: Text('编辑')),
                              const PopupMenuItem(value: StageAction.toggle, child: Text('启停')),
                              const PopupMenuItem(value: StageAction.viewReference, child: Text('查看引用')),
                              if (canWrite)
                                const PopupMenuItem(value: StageAction.delete, child: Text('删除')),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/craft/presentation/widgets/process_item_panel.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

class ProcessItemPanel extends StatelessWidget {
  const ProcessItemPanel({
    super.key,
    required this.keyword,
    required this.stageFilter,
    required this.stageOptions,
    required this.items,
    required this.focusedProcessId,
    required this.canWrite,
    required this.onKeywordChanged,
    required this.onStageFilterChanged,
    required this.onFocusProcess,
    required this.onActionSelected,
  });

  final String keyword;
  final int? stageFilter;
  final List<CraftStageItem> stageOptions;
  final List<CraftProcessItem> items;
  final int? focusedProcessId;
  final bool canWrite;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<int?> onStageFilterChanged;
  final ValueChanged<int> onFocusProcess;
  final void Function(ProcessAction action, CraftProcessItem item) onActionSelected;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('process-item-panel'),
      child: MesSectionCard(
        title: '工序列表',
        child: Column(
          children: [
            MesFilterBar(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: TextEditingController(text: keyword)
                        ..selection = TextSelection.collapsed(offset: keyword.length),
                      onChanged: onKeywordChanged,
                      decoration: const InputDecoration(
                        hintText: '搜索工序编码/名称',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int?>(
                      initialValue: stageFilter,
                      decoration: const InputDecoration(labelText: '按工段筛选'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('全部工段')),
                        ...stageOptions.map(
                          (item) => DropdownMenuItem<int?>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: onStageFilterChanged,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('暂无工序数据'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final focused = item.id == focusedProcessId;
                        return ListTile(
                          selected: focused,
                          title: Text(item.name),
                          subtitle: Text('${item.code} · ${item.stageName ?? '-'}'),
                          onTap: () => onFocusProcess(item.id),
                          trailing: PopupMenuButton<ProcessAction>(
                            onSelected: (action) => onActionSelected(action, item),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: ProcessAction.edit, child: Text('编辑')),
                              const PopupMenuItem(value: ProcessAction.toggle, child: Text('启停')),
                              const PopupMenuItem(value: ProcessAction.viewReference, child: Text('查看引用')),
                              if (canWrite)
                                const PopupMenuItem(value: ProcessAction.delete, child: Text('删除')),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/craft/presentation/widgets/process_focus_panel.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';

class ProcessFocusPanel extends StatelessWidget {
  const ProcessFocusPanel({
    super.key,
    required this.item,
    required this.jumpNotice,
  });

  final CraftProcessItem? item;
  final String jumpNotice;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('process-focus-panel'),
      child: MesSectionCard(
        title: '聚焦工序详情',
        child: item == null
            ? MesEmptyState(
                title: jumpNotice.isNotEmpty ? jumpNotice : '当前未选中工序',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('名称：${item!.name}'),
                  const SizedBox(height: 8),
                  Text('编码：${item!.code}'),
                  const SizedBox(height: 8),
                  Text('所属工段：${item!.stageName ?? '-'}'),
                  const SizedBox(height: 8),
                  Text('状态：${item!.isEnabled ? '启用' : '停用'}'),
                  if ((item!.remark ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('备注：${item!.remark.trim()}'),
                  ],
                ],
              ),
      ),
    );
  }
}
```

- [ ] **Step 3: 把主页面替换成新骨架装配**

```dart
// frontend/lib/features/craft/presentation/process_management_page.dart
import 'package:mes_client/features/craft/presentation/widgets/process_focus_panel.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_item_panel.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_feedback_banner.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_page_header.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_state.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_stage_panel.dart';

@override
Widget build(BuildContext context) {
  final view = _pageState.viewState;
  final filteredStages = _pageState.filteredStages;
  final filteredProcesses = _pageState.filteredProcesses;
  final focusedProcess = _pageState.focusedProcess;
  final isWide = MediaQuery.sizeOf(context).width >= _twoPaneBreakpoint;

  final workspace = isWide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: SizedBox(
                height: 720,
                child: ProcessStagePanel(
                  keyword: view.stageKeyword,
                  onKeywordChanged: _pageState.setStageKeyword,
                  items: filteredStages,
                  canWrite: widget.canWrite,
                  onActionSelected: _handleStageAction,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 12,
              child: SizedBox(
                height: 720,
                child: ProcessItemPanel(
                  keyword: view.processKeyword,
                  stageFilter: view.processStageFilter,
                  stageOptions: view.stages,
                  items: filteredProcesses,
                  focusedProcessId: view.focusedProcessId,
                  canWrite: widget.canWrite,
                  onKeywordChanged: _pageState.setProcessKeyword,
                  onStageFilterChanged: _pageState.setProcessStageFilter,
                  onFocusProcess: _pageState.focusProcess,
                  onActionSelected: _handleProcessAction,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 10,
              child: SizedBox(
                height: 720,
                child: ProcessFocusPanel(
                  item: focusedProcess,
                  jumpNotice: view.jumpNotice,
                ),
              ),
            ),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 320,
              child: ProcessStagePanel(
                keyword: view.stageKeyword,
                onKeywordChanged: _pageState.setStageKeyword,
                items: filteredStages,
                canWrite: widget.canWrite,
                onActionSelected: _handleStageAction,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: ProcessItemPanel(
                keyword: view.processKeyword,
                stageFilter: view.processStageFilter,
                stageOptions: view.stages,
                items: filteredProcesses,
                focusedProcessId: view.focusedProcessId,
                canWrite: widget.canWrite,
                onKeywordChanged: _pageState.setProcessKeyword,
                onStageFilterChanged: _pageState.setProcessStageFilter,
                onFocusProcess: _pageState.focusProcess,
                onActionSelected: _handleProcessAction,
              ),
            ),
            const SizedBox(height: 12),
            ProcessFocusPanel(
              item: focusedProcess,
              jumpNotice: view.jumpNotice,
            ),
          ],
        );

  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProcessManagementPageHeader(
          loading: view.loading,
          canWrite: widget.canWrite,
          onRefresh: _pageState.loadData,
          onCreateStage: _showStageDialog,
          onCreateProcess: _showProcessDialog,
        ),
        const SizedBox(height: 12),
        ProcessManagementFeedbackBanner(
          message: view.message,
          jumpNotice: view.jumpNotice,
        ),
        const SizedBox(height: 12),
        Expanded(child: workspace),
      ],
    ),
  );
}
```

- [ ] **Step 4: 重新运行 widget tests，确认统一骨架断言转绿**

Run: `flutter test test/widgets/process_management_page_test.dart -r expanded`

Expected: PASS，且旧行为用例继续通过。

- [ ] **Step 5: 提交工作台骨架重构**

```bash
git add frontend/lib/features/craft/presentation/process_management_page.dart frontend/lib/features/craft/presentation/widgets/process_management_page_header.dart frontend/lib/features/craft/presentation/widgets/process_management_feedback_banner.dart frontend/lib/features/craft/presentation/widgets/process_stage_panel.dart frontend/lib/features/craft/presentation/widgets/process_item_panel.dart frontend/lib/features/craft/presentation/widgets/process_focus_panel.dart frontend/test/widgets/process_management_page_test.dart
git commit -m "重构工序管理页工作台骨架"
```

## 任务 4：拆出工段/工序弹窗和删除确认

**Files:**
- Create: `frontend/lib/features/craft/presentation/widgets/process_stage_dialog.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_item_dialog.dart`
- Create: `frontend/lib/features/craft/presentation/widgets/process_delete_dialogs.dart`
- Modify: `frontend/lib/features/craft/presentation/process_management_page.dart`
- Test: `frontend/test/widgets/process_management_page_test.dart`

- [ ] **Step 1: 把工段弹窗从主文件抽到独立 widget**

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
      title: Text(widget.existing == null ? '新建工段' : '编辑工段'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: '工段编码'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入工段编码' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '工段名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入工段名称' : null,
              ),
              TextFormField(
                controller: _sortController,
                decoration: const InputDecoration(labelText: '排序'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || int.tryParse(value.trim()) == null ? '请输入有效排序' : null,
              ),
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(labelText: '备注'),
                maxLines: 3,
              ),
              SwitchListTile(
                value: _isEnabled,
                onChanged: (value) => setState(() => _isEnabled = value),
                title: const Text('启用'),
              ),
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
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _codeSuffixController = TextEditingController(
      text: widget.existing?.code.split('-').last ?? '',
    );
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _remarkController = TextEditingController(text: widget.existing?.remark ?? '');
    _stageId = widget.existing?.stageId ?? widget.stages.first.id;
    _isEnabled = widget.existing?.isEnabled ?? true;
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
    return AlertDialog(
      title: Text(widget.existing == null ? '新建工序' : '编辑工序'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeSuffixController,
                decoration: const InputDecoration(labelText: '工序编码序号（两位）'),
                validator: (value) =>
                    value == null || value.trim().length != 2 ? '请输入两位编码序号' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '小工序名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入工序名称' : null,
              ),
              DropdownButtonFormField<int>(
                initialValue: _stageId,
                decoration: const InputDecoration(labelText: '所属工段'),
                items: widget.stages
                    .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _stageId = value);
                },
              ),
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(labelText: '备注'),
                maxLines: 3,
              ),
              SwitchListTile(
                value: _isEnabled,
                onChanged: (value) => setState(() => _isEnabled = value),
                title: const Text('启用'),
              ),
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

Future<bool> showDeleteProcessDialog(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(content),
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

- [ ] **Step 3: 主页面改为调用独立弹窗**

```dart
// frontend/lib/features/craft/presentation/process_management_page.dart
import 'package:mes_client/features/craft/presentation/widgets/process_delete_dialogs.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_item_dialog.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_stage_dialog.dart';

Future<void> _showStageDialog({CraftStageItem? existing}) async {
  final changed = await showDialog<bool>(
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
            remark: remark,
            isEnabled: isEnabled,
          );
        }
        await _pageState.loadData();
      },
    ),
  );
  if (changed == true && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existing == null ? '工段已创建' : '工段已更新')),
    );
  }
}
```

- [ ] **Step 4: 运行 widget tests，确认新增/删除与 jump 回归通过**

Run: `flutter test test/widgets/process_management_page_test.dart -r expanded`

Expected: PASS，尤其保留：
- `工序管理支持新增与删除工序`
- `工序管理支持 jump 定位并展示横幅`

- [ ] **Step 5: 提交弹窗与动作拆分**

```bash
git add frontend/lib/features/craft/presentation/process_management_page.dart frontend/lib/features/craft/presentation/widgets/process_stage_dialog.dart frontend/lib/features/craft/presentation/widgets/process_item_dialog.dart frontend/lib/features/craft/presentation/widgets/process_delete_dialogs.dart frontend/test/widgets/process_management_page_test.dart
git commit -m "拆分工序管理页弹窗与动作逻辑"
```

## 任务 5：补齐 craft 入口与集成回归，并完成留痕

**Files:**
- Modify: `frontend/test/widgets/craft_page_test.dart`
- Modify: `frontend/integration_test/home_shell_flow_test.dart`
- Create: `evidence/verification_20260423_process_management_redesign_plan.md`

- [ ] **Step 1: 更新 craft 页签 widget tests，确认入口不回归**

```dart
// frontend/test/widgets/craft_page_test.dart
testWidgets('craft 页面仍挂载工序管理页入口', (tester) async {
  await _pumpCraftPage(tester);

  expect(find.text('工序管理'), findsWidgets);
  await tester.tap(find.text('工序管理').last);
  await tester.pumpAndSettle();

  expect(find.byType(ProcessManagementPage), findsOneWidget);
});
```

- [ ] **Step 2: 更新集成测试，确认消息跳转后新骨架仍可见**

```dart
// frontend/integration_test/home_shell_flow_test.dart
testWidgets('登录后经主壳和消息中心跳转到工艺工序管理页', (tester) async {
  final authService = _IntegrationAuthService();
  final message = _buildMessageItem(
    id: 405,
    title: '工序待处理',
    summary: '请查看工序71。',
    sourceModule: 'craft',
  );

  await _pumpHomeShellApp(
    tester,
    authService: authService,
    messageService: _IntegrationMessageService(
      items: [message],
      jumpResults: {
        message.id: const MessageJumpResult(
          canJump: true,
          disabledReason: null,
          targetPageCode: 'craft',
          targetTabCode: processManagementTabCode,
          targetRoutePayloadJson:
              '{"target_tab_code":"process_management","process_id":"71"}',
        ),
      },
    ),
    craftService: _IntegrationCraftService(),
  );

  await _loginAndOpenMessageCenter(tester);
  await tester.tap(find.byKey(const ValueKey('message-center-tile-405')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('message-center-preview-jump-405')));
  await tester.pumpAndSettle();

  expect(find.text('工序管理'), findsWidgets);
  expect(find.byKey(const ValueKey('process-management-feedback-banner')), findsOneWidget);
  expect(find.byKey(const ValueKey('process-focus-panel')), findsOneWidget);
});
```

- [ ] **Step 3: 跑完整验证命令**

Run: `flutter test test/widgets/process_management_page_test.dart test/widgets/craft_page_test.dart -r expanded`

Expected: PASS

Run: `flutter test integration_test/home_shell_flow_test.dart -d windows --plain-name "登录后经主壳和消息中心跳转到工艺工序管理页" -r expanded`

Expected: PASS

Run: `flutter analyze lib/features/craft/presentation/process_management_page.dart lib/features/craft/presentation/widgets/process_management_models.dart lib/features/craft/presentation/widgets/process_management_state.dart lib/features/craft/presentation/widgets/process_management_page_header.dart lib/features/craft/presentation/widgets/process_management_feedback_banner.dart lib/features/craft/presentation/widgets/process_stage_panel.dart lib/features/craft/presentation/widgets/process_item_panel.dart lib/features/craft/presentation/widgets/process_focus_panel.dart lib/features/craft/presentation/widgets/process_stage_dialog.dart lib/features/craft/presentation/widgets/process_item_dialog.dart lib/features/craft/presentation/widgets/process_delete_dialogs.dart`

Expected: `No issues found!`

- [ ] **Step 4: 更新验证留痕**

```md
# 工具化验证日志：工序管理页统一骨架重构计划执行

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
git add frontend/test/widgets/process_management_page_test.dart frontend/test/widgets/craft_page_test.dart frontend/integration_test/home_shell_flow_test.dart evidence/verification_20260423_process_management_redesign_plan.md
git commit -m "补齐工序管理页重构回归验证"
```

## 计划自检结论

### Spec 覆盖

已覆盖 spec 中以下要求：

1. 页面拆分边界
2. 顶部页头与反馈区
3. 三栏工作台骨架
4. 状态下沉边界
5. 保持业务行为不变
6. widget / integration / analyze 验证

### 占位词扫描

本计划未使用 `TODO`、`TBD`、`待定`、`implement later` 等占位词。

### 一致性检查

已统一使用以下命名：

1. `ProcessManagementState`
2. `ProcessManagementViewState`
3. `ProcessManagementPageHeader`
4. `ProcessManagementFeedbackBanner`
5. `ProcessStagePanel`
6. `ProcessItemPanel`
7. `ProcessFocusPanel`

未在后续任务中出现与前文不一致的类型名或文件名。
