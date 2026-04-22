import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/craft_page_shell.dart';
import 'package:mes_client/features/craft/presentation/craft_kanban_page.dart';
import 'package:mes_client/features/craft/presentation/craft_reference_analysis_page.dart';
import 'package:mes_client/features/craft/presentation/process_configuration_page.dart';
import 'package:mes_client/features/craft/presentation/process_management_page.dart';

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

class _ProcessManagementJumpTarget {
  const _ProcessManagementJumpTarget({
    required this.processId,
    required this.requestId,
  });

  final int processId;
  final int requestId;
}

class _ProcessConfigurationJumpTarget {
  const _ProcessConfigurationJumpTarget({
    required this.requestId,
    this.templateId,
    this.version,
    this.systemMasterVersions = false,
  });

  final int requestId;
  final int? templateId;
  final int? version;
  final bool systemMasterVersions;
}

class CraftPage extends StatefulWidget {
  const CraftPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
    required this.capabilityCodes,
    this.preferredTabCode,
    this.routePayloadJson,
    this.onNavigateToPage,
    this.tabChildBuilder,
    this.tabPageBuilder,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;
  final Set<String> capabilityCodes;
  final String? preferredTabCode;
  final String? routePayloadJson;
  final void Function(String pageCode)? onNavigateToPage;
  final Widget Function(String tabCode)? tabChildBuilder;
  final Widget Function(String tabCode, Widget child)? tabPageBuilder;

  @override
  State<CraftPage> createState() => _CraftPageState();
}

class _CraftPageState extends State<CraftPage> with TickerProviderStateMixin {
  late List<String> _orderedVisibleTabCodes;
  TabController? _tabController;
  _ProcessManagementJumpTarget? _processManagementJumpTarget;
  _ProcessConfigurationJumpTarget? _processConfigurationJumpTarget;
  String? _lastHandledRoutePayloadJson;

  @override
  void initState() {
    super.initState();
    _orderedVisibleTabCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    _rebuildTabController(preferredCode: widget.preferredTabCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeRoutePayload(widget.routePayloadJson);
    });
  }

  @override
  void didUpdateWidget(covariant CraftPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    if (!listEquals(updatedCodes, _orderedVisibleTabCodes)) {
      final selectedCode = _currentSelectedTabCode();
      _orderedVisibleTabCodes = updatedCodes;
      _rebuildTabController(preferredCode: selectedCode);
    } else if (widget.preferredTabCode != oldWidget.preferredTabCode) {
      _rebuildTabController(preferredCode: widget.preferredTabCode);
    }
    if (widget.routePayloadJson != oldWidget.routePayloadJson) {
      _consumeRoutePayload(widget.routePayloadJson);
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

  Widget _buildTabChild(String code, Widget child) {
    final overridden = widget.tabPageBuilder?.call(code, child);
    if (overridden != null) {
      return overridden;
    }
    return widget.tabChildBuilder?.call(code) ?? child;
  }

  void _selectCraftTab(String tabCode) {
    final index = _orderedVisibleTabCodes.indexOf(tabCode);
    if (index >= 0 && _tabController != null) {
      _tabController!.animateTo(index);
    }
  }

  void _consumeRoutePayload(String? rawJson) {
    if (rawJson == null || rawJson == _lastHandledRoutePayloadJson) {
      return;
    }
    _lastHandledRoutePayloadJson = rawJson;
    final payload = parseCraftMessageJumpPayload(rawJson);
    if (payload == null) {
      return;
    }
    setState(() {
      if (payload.targetTabCode == processManagementTabCode &&
          payload.processId != null &&
          payload.processId! > 0) {
        _processManagementJumpTarget = _ProcessManagementJumpTarget(
          processId: payload.processId!,
          requestId: (_processManagementJumpTarget?.requestId ?? 0) + 1,
        );
      }
      if (payload.targetTabCode == productionProcessConfigTabCode) {
        _processConfigurationJumpTarget = _ProcessConfigurationJumpTarget(
          requestId: (_processConfigurationJumpTarget?.requestId ?? 0) + 1,
          templateId: payload.templateId,
          version: payload.version,
          systemMasterVersions: payload.systemMasterVersions,
        );
      }
    });
    _selectCraftTab(payload.targetTabCode);
  }

  int? _parsePositiveInt(String? rawValue) {
    final value = int.tryParse((rawValue ?? '').trim());
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  Uri? _parseJumpTarget(String jumpTarget) {
    try {
      return Uri.parse(jumpTarget);
    } catch (_) {
      return null;
    }
  }

  void _handleReferenceNavigation({
    required String moduleCode,
    String? jumpTarget,
  }) {
    final normalizedModule = moduleCode.trim().toLowerCase();
    if (normalizedModule == 'craft') {
      final target = (jumpTarget ?? '').trim();
      final uri = _parseJumpTarget(target);
      final path = (uri?.path ?? target).trim();
      if (path.startsWith('process-management')) {
        setState(() {
          _processManagementJumpTarget = _ProcessManagementJumpTarget(
            processId:
                _parsePositiveInt(uri?.queryParameters['process_id']) ?? 0,
            requestId: (_processManagementJumpTarget?.requestId ?? 0) + 1,
          );
        });
        _selectCraftTab(processManagementTabCode);
        return;
      }
      if (path.startsWith('process-configuration')) {
        final templateId = _parsePositiveInt(
          uri?.queryParameters['template_id'],
        );
        final version = _parsePositiveInt(uri?.queryParameters['version']);
        final systemMasterVersions =
            uri?.queryParameters['system_master_versions'] == '1';
        setState(() {
          _processConfigurationJumpTarget = _ProcessConfigurationJumpTarget(
            requestId: (_processConfigurationJumpTarget?.requestId ?? 0) + 1,
            templateId: templateId,
            version: version,
            systemMasterVersions: systemMasterVersions,
          );
        });
        _selectCraftTab(productionProcessConfigTabCode);
        return;
      }
      if (path.startsWith('craft-kanban')) {
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
        return _buildTabChild(
          code,
          ProcessManagementPage(
            session: widget.session,
            onLogout: widget.onLogout,
            canWrite: _canWriteProcessBasics,
            processId: (_processManagementJumpTarget?.processId ?? 0) > 0
                ? _processManagementJumpTarget?.processId
                : null,
            jumpRequestId: _processManagementJumpTarget?.requestId ?? 0,
          ),
        );
      case productionProcessConfigTabCode:
        return _buildTabChild(
          code,
          ProcessConfigurationPage(
            session: widget.session,
            onLogout: widget.onLogout,
            canViewTemplates: _canViewTemplates,
            canManageTemplates: _canManageTemplates,
            canManageSystemMasterTemplate: _canManageSystemMasterTemplate,
            templateId: _processConfigurationJumpTarget?.templateId,
            version: _processConfigurationJumpTarget?.version,
            systemMasterVersions:
                _processConfigurationJumpTarget?.systemMasterVersions ?? false,
            jumpRequestId: _processConfigurationJumpTarget?.requestId ?? 0,
          ),
        );
      case craftKanbanTabCode:
        return _buildTabChild(
          code,
          CraftKanbanPage(session: widget.session, onLogout: widget.onLogout),
        );
      case craftReferenceAnalysisTabCode:
        return _buildTabChild(
          code,
          CraftReferenceAnalysisPage(
            session: widget.session,
            onLogout: widget.onLogout,
            onNavigate: _handleReferenceNavigation,
          ),
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

    return CraftPageShell(
      tabBar: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: TabBar(
          controller: _tabController,
          tabs: _orderedVisibleTabCodes
              .map((code) => Tab(text: _tabTitle(code)))
              .toList(),
        ),
      ),
      tabBarView: TabBarView(
        controller: _tabController,
        children: _orderedVisibleTabCodes.map(_buildTabContent).toList(),
      ),
    );
  }
}

class CraftMessageJumpPayload {
  const CraftMessageJumpPayload({
    required this.targetTabCode,
    this.templateId,
    this.version,
    this.processId,
    this.systemMasterVersions = false,
  });

  final String targetTabCode;
  final int? templateId;
  final int? version;
  final int? processId;
  final bool systemMasterVersions;
}

int? _tryParsePositiveInt(dynamic rawValue) {
  final value = switch (rawValue) {
    int v => v,
    String v => int.tryParse(v.trim()),
    _ => null,
  };
  if (value == null || value <= 0) {
    return null;
  }
  return value;
}

bool _parseFlexibleBool(dynamic rawValue) {
  return switch (rawValue) {
    bool v => v,
    int v => v != 0,
    String v => const {
      '1',
      'true',
      'yes',
      'y',
    }.contains(v.trim().toLowerCase()),
    _ => false,
  };
}

CraftMessageJumpPayload? parseCraftMessageJumpPayload(String? rawJson) {
  final normalized = (rawJson ?? '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  try {
    final payload = jsonDecode(normalized);
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    final targetTabCode = (payload['target_tab_code'] as String?)?.trim();
    return CraftMessageJumpPayload(
      targetTabCode: (targetTabCode == null || targetTabCode.isEmpty)
          ? productionProcessConfigTabCode
          : targetTabCode,
      templateId: _tryParsePositiveInt(payload['template_id']),
      version: _tryParsePositiveInt(payload['version']),
      processId: _tryParsePositiveInt(payload['process_id']),
      systemMasterVersions: _parseFlexibleBool(
        payload['system_master_versions'],
      ),
    );
  } catch (_) {
    return null;
  }
}
