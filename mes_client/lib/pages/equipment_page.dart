import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import 'equipment_ledger_page.dart';
import 'maintenance_execution_page.dart';
import 'maintenance_item_page.dart';
import 'maintenance_plan_page.dart';
import 'maintenance_record_page.dart';

const String equipmentLedgerTabCode = 'equipment_ledger';
const String maintenanceItemTabCode = 'maintenance_item';
const String maintenancePlanTabCode = 'maintenance_plan';
const String maintenanceExecutionTabCode = 'maintenance_execution';
const String maintenanceRecordTabCode = 'maintenance_record';

const List<String> _defaultTabOrder = [
  equipmentLedgerTabCode,
  maintenanceItemTabCode,
  maintenancePlanTabCode,
  maintenanceExecutionTabCode,
  maintenanceRecordTabCode,
];

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({
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
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage>
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
  void didUpdateWidget(covariant EquipmentPage oldWidget) {
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

  bool get _canWrite =>
      widget.currentRoleCodes.contains('system_admin') ||
      widget.currentRoleCodes.contains('production_admin');

  bool get _canExecute =>
      widget.currentRoleCodes.contains('system_admin') ||
      widget.currentRoleCodes.contains('production_admin') ||
      widget.currentRoleCodes.contains('operator');

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
      case equipmentLedgerTabCode:
        return '设备台账';
      case maintenanceItemTabCode:
        return '保养项目';
      case maintenancePlanTabCode:
        return '保养计划';
      case maintenanceExecutionTabCode:
        return '保养执行';
      case maintenanceRecordTabCode:
        return '保养记录';
      default:
        return code;
    }
  }

  Widget _buildTabContent(String code) {
    switch (code) {
      case equipmentLedgerTabCode:
        return EquipmentLedgerPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canWrite: _canWrite,
        );
      case maintenanceItemTabCode:
        return MaintenanceItemPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canWrite: _canWrite,
        );
      case maintenancePlanTabCode:
        return MaintenancePlanPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canWrite: _canWrite,
        );
      case maintenanceExecutionTabCode:
        return MaintenanceExecutionPage(
          session: widget.session,
          onLogout: widget.onLogout,
          canExecute: _canExecute,
        );
      case maintenanceRecordTabCode:
        return MaintenanceRecordPage(
          session: widget.session,
          onLogout: widget.onLogout,
        );
      default:
        return Center(child: Text('页面暂未实现：$code'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_orderedVisibleTabCodes.isEmpty || _tabController == null) {
      return const Center(child: Text('当前账号没有可访问的设备模块页面。'));
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
