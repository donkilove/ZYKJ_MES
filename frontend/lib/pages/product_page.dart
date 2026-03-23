import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import '../models/product_models.dart';
import '../services/product_service.dart';
import 'product_management_page.dart';
import 'product_parameter_management_page.dart';
import 'product_parameter_query_page.dart';
import 'product_version_management_page.dart';

const String productManagementTabCode = 'product_management';
const String productVersionManagementTabCode = 'product_version_management';
const String productParameterManagementTabCode = 'product_parameter_management';
const String productParameterQueryTabCode = 'product_parameter_query';

const List<String> _defaultTabOrder = [
  productManagementTabCode,
  productVersionManagementTabCode,
  productParameterManagementTabCode,
  productParameterQueryTabCode,
];

class ProductPage extends StatefulWidget {
  const ProductPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
    required this.capabilityCodes,
    this.preferredTabCode,
    this.routePayloadJson,
    this.productVersionService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;
  final Set<String> capabilityCodes;
  final String? preferredTabCode;
  final String? routePayloadJson;
  final ProductService? productVersionService;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage>
    with SingleTickerProviderStateMixin {
  late List<String> _orderedVisibleTabCodes;
  TabController? _tabController;

  ProductJumpCommand? _jumpCommand;
  int _jumpSeq = 0;
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
  void didUpdateWidget(covariant ProductPage oldWidget) {
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

  void _consumeRoutePayload(String? rawJson) {
    if (rawJson == null || rawJson == _lastHandledRoutePayloadJson) {
      return;
    }
    _lastHandledRoutePayloadJson = rawJson;
    final payload = parseProductMessageJumpPayload(rawJson);
    if (payload == null) {
      return;
    }
    final targetIndex = _orderedVisibleTabCodes.indexOf(payload.targetTabCode);
    if (targetIndex < 0) {
      return;
    }
    setState(() {
      _jumpSeq += 1;
      _jumpCommand = ProductJumpCommand(
        seq: _jumpSeq,
        targetTabCode: payload.targetTabCode,
        action: payload.action,
        productId: payload.productId,
        productName: payload.productName,
        targetVersion: payload.targetVersion,
        targetVersionLabel: payload.targetVersionLabel,
      );
    });
    _tabController?.animateTo(targetIndex);
  }

  void _dispatchJump({
    required String targetTabCode,
    required String action,
    required ProductItem product,
    int? targetVersion,
    String? targetVersionLabel,
  }) {
    final targetIndex = _orderedVisibleTabCodes.indexOf(targetTabCode);
    if (targetIndex < 0) {
      return;
    }

    setState(() {
      _jumpSeq += 1;
      _jumpCommand = ProductJumpCommand(
        seq: _jumpSeq,
        targetTabCode: targetTabCode,
        action: action,
        productId: product.id,
        productName: product.name,
        targetVersion: targetVersion,
        targetVersionLabel: targetVersionLabel,
      );
    });
    _tabController?.animateTo(targetIndex);
  }

  void _handleJumpConsumed(int seq) {
    final current = _jumpCommand;
    if (current == null || current.seq != seq) {
      return;
    }
    setState(() {
      _jumpCommand = null;
    });
  }

  String _tabTitle(String code) {
    switch (code) {
      case productManagementTabCode:
        return '产品管理';
      case productVersionManagementTabCode:
        return '版本管理';
      case productParameterManagementTabCode:
        return '版本参数管理';
      case productParameterQueryTabCode:
        return '产品参数查询';
      default:
        return code;
    }
  }

  Widget _buildTabContent(String code) {
    switch (code) {
      case productManagementTabCode:
        return ProductManagementPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canCreateProduct: _hasPermission(
            ProductFeaturePermissionCodes.productManagementManage,
          ),
          canExportProducts: _hasPermission(
            ProductFeaturePermissionCodes.catalogExport,
          ),
          canDeleteProduct: _hasPermission(
            ProductFeaturePermissionCodes.productManagementManage,
          ),
          canUpdateLifecycle: _hasPermission(
            ProductFeaturePermissionCodes.productManagementManage,
          ),
          canViewVersions: _hasPermission(
            ProductFeaturePermissionCodes.versionAnalysisView,
          ),
          canCompareVersions: _hasPermission(
            ProductFeaturePermissionCodes.versionAnalysisView,
          ),
          canRollbackVersion: _hasPermission(
            ProductFeaturePermissionCodes.productManagementManage,
          ),
          canManageVersions: _hasPermission(
            ProductFeaturePermissionCodes.versionsManage,
          ),
          canActivateVersions: _hasPermission(
            ProductFeaturePermissionCodes.versionActivationManage,
          ),
          canViewImpactAnalysis: _hasPermission(
            ProductFeaturePermissionCodes.versionAnalysisView,
          ),
          canViewParameters: _hasPermission(
            ProductFeaturePermissionCodes.parametersView,
          ),
          canEditParameters: _hasPermission(
            ProductFeaturePermissionCodes.parametersEdit,
          ),
          canExportParameters: _hasPermission(
            ProductFeaturePermissionCodes.parametersExport,
          ),
          onViewParameters: (product) {
            _dispatchJump(
              targetTabCode: productParameterQueryTabCode,
              action: 'view',
              product: product,
            );
          },
          onEditParameters: (product) {
            _dispatchJump(
              targetTabCode: productParameterManagementTabCode,
              action: 'edit',
              product: product,
              targetVersion: product.currentVersion,
            );
          },
        );
      case productVersionManagementTabCode:
        return ProductVersionManagementPage(
          session: widget.session,
          onLogout: widget.onLogout,
          tabCode: productVersionManagementTabCode,
          jumpCommand: _jumpCommand,
          onJumpHandled: _handleJumpConsumed,
          onEditVersionParameters: (product, version) {
            _dispatchJump(
              targetTabCode: productParameterManagementTabCode,
              action: 'edit',
              product: product,
              targetVersion: version.version,
              targetVersionLabel: version.versionLabel,
            );
          },
          canManageVersions: _hasPermission(
            ProductFeaturePermissionCodes.versionsManage,
          ),
          canActivateVersions: _hasPermission(
            ProductFeaturePermissionCodes.versionActivationManage,
          ),
          canExportVersionParameters: _hasPermission(
            ProductFeaturePermissionCodes.parametersExport,
          ),
          service: widget.productVersionService,
        );
      case productParameterManagementTabCode:
        return ProductParameterManagementPage(
          session: widget.session,
          onLogout: widget.onLogout,
          tabCode: productParameterManagementTabCode,
          jumpCommand: _jumpCommand,
          onJumpHandled: _handleJumpConsumed,
          canExportParameters: _hasPermission(
            ProductFeaturePermissionCodes.parametersExport,
          ),
        );
      case productParameterQueryTabCode:
        return ProductParameterQueryPage(
          session: widget.session,
          onLogout: widget.onLogout,
          tabCode: productParameterQueryTabCode,
          jumpCommand: _jumpCommand,
          onJumpHandled: _handleJumpConsumed,
          canExportParameters: _hasPermission(
            ProductFeaturePermissionCodes.parametersExport,
          ),
        );
      default:
        return Center(child: Text('页面暂未实现：$code'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_orderedVisibleTabCodes.isEmpty || _tabController == null) {
      return const Center(child: Text('当前账号没有可访问的产品模块页面。'));
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

class ProductMessageJumpPayload {
  const ProductMessageJumpPayload({
    required this.targetTabCode,
    required this.action,
    required this.productId,
    required this.productName,
    this.targetVersion,
    this.targetVersionLabel,
  });

  final String targetTabCode;
  final String action;
  final int productId;
  final String productName;
  final int? targetVersion;
  final String? targetVersionLabel;
}

ProductMessageJumpPayload? parseProductMessageJumpPayload(String? rawJson) {
  final normalized = (rawJson ?? '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  try {
    final payload = jsonDecode(normalized);
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    final productId = payload['product_id'] as int?;
    if (productId == null || productId <= 0) {
      return null;
    }
    return ProductMessageJumpPayload(
      targetTabCode:
          payload['target_tab_code'] as String? ??
          productVersionManagementTabCode,
      action: payload['action'] as String? ?? 'view_version',
      productId: productId,
      productName: payload['product_name'] as String? ?? '',
      targetVersion: payload['target_version'] as int?,
      targetVersionLabel: payload['target_version_label'] as String?,
    );
  } catch (_) {
    return null;
  }
}
