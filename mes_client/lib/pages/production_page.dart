import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import '../services/authz_service.dart';
import 'production_assist_approval_page.dart';
import 'production_data_page.dart';
import 'production_order_management_page.dart';
import 'production_order_query_page.dart';
import 'production_repair_orders_page.dart';
import 'production_scrap_statistics_page.dart';

const String productionOrderManagementTabCode = 'production_order_management';
const String productionOrderQueryTabCode = 'production_order_query';
const String productionAssistApprovalTabCode = 'production_assist_approval';
const String productionDataQueryTabCode = 'production_data_query';
const String productionScrapStatisticsTabCode = 'production_scrap_statistics';
const String productionRepairOrdersTabCode = 'production_repair_orders';

const List<String> _defaultTabOrder = [
  productionOrderManagementTabCode,
  productionOrderQueryTabCode,
  productionAssistApprovalTabCode,
  productionDataQueryTabCode,
  productionScrapStatisticsTabCode,
  productionRepairOrdersTabCode,
];

class ProductionPage extends StatefulWidget {
  const ProductionPage({
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
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage>
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
  void didUpdateWidget(covariant ProductionPage oldWidget) {
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
        moduleCode: 'production',
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
        _permissionMessage = '加载功能权限失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPermissions = false;
        });
      }
    }
  }

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
      case productionOrderManagementTabCode:
        return '订单管理';
      case productionOrderQueryTabCode:
        return '订单查询';
      case productionAssistApprovalTabCode:
        return '代班记录';
      case productionDataQueryTabCode:
        return '生产数据';
      case productionScrapStatisticsTabCode:
        return '报废统计';
      case productionRepairOrdersTabCode:
        return '维修订单';
      default:
        return code;
    }
  }

  Widget _buildTabContent(String code) {
    switch (code) {
      case productionOrderManagementTabCode:
        return ProductionOrderManagementPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canCreateOrder: _hasPermission(
            ProductionFeaturePermissionCodes.orderManagementManage,
          ),
          canEditOrder: _hasPermission(
            ProductionFeaturePermissionCodes.orderManagementManage,
          ),
          canDeleteOrder: _hasPermission(
            ProductionFeaturePermissionCodes.orderManagementManage,
          ),
          canCompleteOrder: _hasPermission(
            ProductionFeaturePermissionCodes.orderManagementManage,
          ),
          canUpdatePipelineMode: _hasPermission(
            ProductionFeaturePermissionCodes.pipelineModeManage,
          ),
        );
      case productionOrderQueryTabCode:
        return ProductionOrderQueryPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canFirstArticle: _hasPermission(
            ProductionFeaturePermissionCodes.orderQueryExecute,
          ),
          canEndProduction: _hasPermission(
            ProductionFeaturePermissionCodes.orderQueryExecute,
          ),
          canCreateManualRepairOrder: _hasPermission(
            ProductionFeaturePermissionCodes.repairOrdersCreateManual,
          ),
          canCreateAssistAuthorization: _hasPermission(
            ProductionFeaturePermissionCodes.assistLaunch,
          ),
          canProxyView: _hasPermission(
            ProductionFeaturePermissionCodes.orderQueryProxy,
          ),
        );
      case productionAssistApprovalTabCode:
        return ProductionAssistApprovalPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canReview: _hasPermission(
            ProductionFeaturePermissionCodes.assistRecordsView,
          ),
        );
      case productionDataQueryTabCode:
        return ProductionDataPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canExport: _hasPermission(
            ProductionFeaturePermissionCodes.dataExportUse,
          ),
        );
      case productionScrapStatisticsTabCode:
        return ProductionScrapStatisticsPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canExport: _hasPermission(
            ProductionFeaturePermissionCodes.scrapExportUse,
          ),
        );
      case productionRepairOrdersTabCode:
        return ProductionRepairOrdersPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canComplete: _hasPermission(
            ProductionFeaturePermissionCodes.repairOrdersManage,
          ),
          canExport: _hasPermission(
            ProductionFeaturePermissionCodes.repairOrdersExport,
          ),
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
      return const Center(child: Text('当前账号无可见生产页面'));
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
