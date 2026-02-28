import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/product_models.dart';
import 'product_management_page.dart';
import 'product_parameter_management_page.dart';
import 'product_parameter_query_page.dart';

const String productManagementTabCode = 'product_management';
const String productParameterManagementTabCode = 'product_parameter_management';
const String productParameterQueryTabCode = 'product_parameter_query';

const List<String> _defaultTabOrder = [
  productManagementTabCode,
  productParameterManagementTabCode,
  productParameterQueryTabCode,
];

class ProductPage extends StatefulWidget {
  const ProductPage({
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
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage>
    with SingleTickerProviderStateMixin {
  late List<String> _orderedVisibleTabCodes;
  TabController? _tabController;

  ProductJumpCommand? _jumpCommand;
  int _jumpSeq = 0;

  @override
  void initState() {
    super.initState();
    _orderedVisibleTabCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    _rebuildTabController();
  }

  @override
  void didUpdateWidget(covariant ProductPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    if (listEquals(updatedCodes, _orderedVisibleTabCodes)) {
      return;
    }
    final selectedCode = _currentSelectedTabCode();
    _orderedVisibleTabCodes = updatedCodes;
    _rebuildTabController(preferredCode: selectedCode);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
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
    final safeIndex = _tabController!.index.clamp(0, _orderedVisibleTabCodes.length - 1);
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

  void _dispatchJump({
    required String targetTabCode,
    required String action,
    required ProductItem product,
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
      );
    });
    _tabController?.animateTo(targetIndex);
  }

  String _tabTitle(String code) {
    switch (code) {
      case productManagementTabCode:
        return '产品管理';
      case productParameterManagementTabCode:
        return '产品参数管理';
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
          isSystemAdmin: widget.currentRoleCodes.contains('system_admin'),
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
            );
          },
        );
      case productParameterManagementTabCode:
        return ProductParameterManagementPage(
          session: widget.session,
          onLogout: widget.onLogout,
          tabCode: productParameterManagementTabCode,
          jumpCommand: _jumpCommand,
        );
      case productParameterQueryTabCode:
        return ProductParameterQueryPage(
          session: widget.session,
          onLogout: widget.onLogout,
          tabCode: productParameterQueryTabCode,
          jumpCommand: _jumpCommand,
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
