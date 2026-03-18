import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import 'craft_kanban_page.dart';
import 'craft_reference_analysis_page.dart';
import 'process_configuration_page.dart';
import 'process_management_page.dart';

const String processManagementTabCode = 'process_management';
const String productionProcessConfigTabCode = 'production_process_config';
const String craftKanbanTabCode = 'craft_kanban';
const String craftReferenceAnalysisTabCode = 'craft_reference_analysis';

const List<String> _defaultTabOrder = [
  processManagementTabCode,
  productionProcessConfigTabCode,
  craftKanbanTabCode,
  craftReferenceAnalysisTabCode,
];

class CraftPage extends StatefulWidget {
  const CraftPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
    required this.capabilityCodes,
    this.onNavigateToPage,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;
  final Set<String> capabilityCodes;
  final void Function(String pageCode)? onNavigateToPage;

  @override
  State<CraftPage> createState() => _CraftPageState();
}

class _CraftPageState extends State<CraftPage>
    with SingleTickerProviderStateMixin {
  late List<String> _orderedVisibleTabCodes;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _orderedVisibleTabCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    _rebuildTabController();
  }

  @override
  void didUpdateWidget(covariant CraftPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    if (!listEquals(updatedCodes, _orderedVisibleTabCodes)) {
      final selectedCode = _currentSelectedTabCode();
      _orderedVisibleTabCodes = updatedCodes;
      _rebuildTabController(preferredCode: selectedCode);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  bool _hasPermission(String code) => widget.capabilityCodes.contains(code);

  bool get _canWriteProcessBasics =>
      _hasPermission(CraftFeaturePermissionCodes.processBasicsManage);

  bool get _canManageTemplates =>
      _hasPermission(CraftFeaturePermissionCodes.processTemplatesManage);

  bool get _canViewTemplates =>
      _hasPermission(CraftFeaturePermissionCodes.processTemplatesView) ||
      _canManageTemplates;

  bool get _canManageSystemMasterTemplate =>
      _hasPermission(CraftFeaturePermissionCodes.processTemplatesManage);

  List<String> _sortedVisibleTabCodes(List<String> tabCodes) {
    final visibleSet = tabCodes.toSet();
    final ordered = <String>[];
    for (final code in _defaultTabOrder) {
      if (visibleSet.remove(code)) {
        ordered.add(code);
      }
    }
    final remaining = visibleSet.toList()..sort();
    ordered.addAll(remaining);
    return ordered;
  }

  String? _currentSelectedTabCode() {
    if (_tabController == null || _orderedVisibleTabCodes.isEmpty) {
      return null;
    }
    final safeIndex = _tabController!.index.clamp(
      0,
      _orderedVisibleTabCodes.length - 1,
    );
    return _orderedVisibleTabCodes[safeIndex];
  }

  void _rebuildTabController({String? preferredCode}) {
    _tabController?.dispose();
    if (_orderedVisibleTabCodes.isEmpty) {
      _tabController = null;
      return;
    }
    var initialIndex = 0;
    if (preferredCode != null) {
      final preferredIndex = _orderedVisibleTabCodes.indexOf(preferredCode);
      if (preferredIndex >= 0) {
        initialIndex = preferredIndex;
      }
    }
    _tabController = TabController(
      length: _orderedVisibleTabCodes.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  String _tabTitle(String code) {
    switch (code) {
      case processManagementTabCode:
        return '工序管理';
      case productionProcessConfigTabCode:
        return '生产工序配置';
      case craftKanbanTabCode:
        return '工艺看板';
      case craftReferenceAnalysisTabCode:
        return '引用分析';
      default:
        return code;
    }
  }

  void _selectCraftTab(String tabCode) {
    final index = _orderedVisibleTabCodes.indexOf(tabCode);
    if (index >= 0 && _tabController != null) {
      _tabController!.animateTo(index);
    }
  }

  void _handleReferenceNavigation({required String moduleCode, String? jumpTarget}) {
    final normalizedModule = moduleCode.trim();
    if (normalizedModule == 'craft') {
      final target = (jumpTarget ?? '').trim();
      if (target.startsWith('process-management')) {
        _selectCraftTab(processManagementTabCode);
        return;
      }
      if (target.startsWith('process-configuration')) {
        _selectCraftTab(productionProcessConfigTabCode);
        return;
      }
      if (target.startsWith('craft-kanban')) {
        _selectCraftTab(craftKanbanTabCode);
        return;
      }
      _selectCraftTab(craftReferenceAnalysisTabCode);
      return;
    }

    final pageCode = switch (normalizedModule) {
      'user' => 'user',
      'product' => 'product',
      'production' => 'production',
      'equipment' => 'equipment',
      'quality' => 'quality',
      'message' => 'message',
      _ => '',
    };
    if (pageCode.isNotEmpty) {
      widget.onNavigateToPage?.call(pageCode);
    }
  }

  Widget _buildTabContent(String code) {
    switch (code) {
      case processManagementTabCode:
        return ProcessManagementPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canWrite: _canWriteProcessBasics,
        );
      case productionProcessConfigTabCode:
        return ProcessConfigurationPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canViewTemplates: _canViewTemplates,
          canManageTemplates: _canManageTemplates,
          canManageSystemMasterTemplate: _canManageSystemMasterTemplate,
        );
      case craftKanbanTabCode:
        return CraftKanbanPage(
          session: widget.session,
          onLogout: widget.onLogout,
        );
      case craftReferenceAnalysisTabCode:
        return CraftReferenceAnalysisPage(
          session: widget.session,
          onLogout: widget.onLogout,
          onNavigate: _handleReferenceNavigation,
        );
      default:
        return Center(child: Text('页面暂未实现：$code'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_orderedVisibleTabCodes.isEmpty || _tabController == null) {
      return const Center(child: Text('当前账号无可见工艺页面。'));
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: TabBar(
            controller: _tabController,
            tabs: _orderedVisibleTabCodes
                .map((code) => Tab(text: _tabTitle(code)))
                .toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _orderedVisibleTabCodes.map(_buildTabContent).toList(),
          ),
        ),
      ],
    );
  }
}
