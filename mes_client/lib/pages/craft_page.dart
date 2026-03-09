import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import '../services/authz_service.dart';
import 'craft_kanban_page.dart';
import 'process_configuration_page.dart';
import 'process_management_page.dart';

const String processManagementTabCode = 'process_management';
const String productionProcessConfigTabCode = 'production_process_config';
const String craftKanbanTabCode = 'craft_kanban';

const List<String> _defaultTabOrder = [
  processManagementTabCode,
  productionProcessConfigTabCode,
  craftKanbanTabCode,
];

class CraftPage extends StatefulWidget {
  const CraftPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
    required this.currentRoleCodes,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;
  final List<String> currentRoleCodes;

  @override
  State<CraftPage> createState() => _CraftPageState();
}

class _CraftPageState extends State<CraftPage>
    with SingleTickerProviderStateMixin {
  late final AuthzService _authzService;
  late List<String> _orderedVisibleTabCodes;
  TabController? _tabController;

  Set<String> _permissionCodes = const <String>{};
  bool _loadingPermissions = true;
  String _permissionMessage = '';

  @override
  void initState() {
    super.initState();
    _authzService = AuthzService(widget.session);
    _orderedVisibleTabCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    _rebuildTabController();
    _loadPermissions();
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
    if (oldWidget.session.accessToken != widget.session.accessToken) {
      _loadPermissions();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  bool _hasPermission(String code) => _permissionCodes.contains(code);

  Future<void> _loadPermissions() async {
    setState(() {
      _loadingPermissions = true;
      _permissionMessage = '';
    });
    try {
      final codes = await _authzService.getMyPermissionCodes(
        moduleCode: 'craft',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _permissionCodes = codes.toSet();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _permissionCodes = const <String>{};
        _permissionMessage = '加载工艺模块权限失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPermissions = false;
        });
      }
    }
  }

  bool get _canWriteProcessBasics =>
      _hasPermission(CraftPermissionCodes.stagesCreate) ||
      _hasPermission(CraftPermissionCodes.stagesUpdate) ||
      _hasPermission(CraftPermissionCodes.stagesDelete) ||
      _hasPermission(CraftPermissionCodes.processesCreate) ||
      _hasPermission(CraftPermissionCodes.processesUpdate) ||
      _hasPermission(CraftPermissionCodes.processesDelete);

  bool get _canManageTemplates =>
      _hasPermission(CraftPermissionCodes.templatesCreate) ||
      _hasPermission(CraftPermissionCodes.templatesUpdate) ||
      _hasPermission(CraftPermissionCodes.templatesDelete) ||
      _hasPermission(CraftPermissionCodes.templatesPublish) ||
      _hasPermission(CraftPermissionCodes.templatesExport) ||
      _hasPermission(CraftPermissionCodes.templatesImport) ||
      _hasPermission(CraftPermissionCodes.templatesRollback);

  bool get _canManageSystemMasterTemplate =>
      _hasPermission(CraftPermissionCodes.systemMasterTemplateCreate) ||
      _hasPermission(CraftPermissionCodes.systemMasterTemplateUpdate);

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
      default:
        return code;
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
          canManageTemplates: _canManageTemplates,
          canManageSystemMasterTemplate: _canManageSystemMasterTemplate,
        );
      case craftKanbanTabCode:
        return CraftKanbanPage(
          session: widget.session,
          onLogout: widget.onLogout,
        );
      default:
        return Center(child: Text('页面暂未实现：$code'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPermissions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orderedVisibleTabCodes.isEmpty || _tabController == null) {
      return const Center(child: Text('当前账号无可见工艺页面。'));
    }

    return Column(
      children: [
        if (_permissionMessage.isNotEmpty)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(_permissionMessage),
          ),
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
