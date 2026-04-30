import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/presentation/widgets/maintenance_plan_action_dialogs.dart';
import 'package:mes_client/features/equipment/presentation/widgets/maintenance_plan_form_dialog.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';

class MaintenancePlanPage extends StatefulWidget {
  const MaintenancePlanPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
    this.equipmentService,
    this.craftService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;
  final EquipmentService? equipmentService;
  final CraftService? craftService;

  @override
  State<MaintenancePlanPage> createState() => _MaintenancePlanPageState();
}

class _MaintenancePlanPageState extends State<MaintenancePlanPage> {
  static const int _pageSize = 30;

  late final EquipmentService _equipmentService;
  late final CraftService _craftService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  int _page = 1;
  List<MaintenancePlanItem> _plans = const [];
  List<EquipmentLedgerItem> _equipmentOptions = const [];
  List<MaintenanceItemEntry> _itemOptions = const [];
  List<CraftStageItem> _stageOptions = const [];
  List<EquipmentOwnerOption> _ownerOptions = const [];
  int? _equipmentFilterId;
  int? _itemFilterId;
  bool? _enabledFilter;
  String? _executionStageCodeFilter;
  int? _defaultExecutorFilterId;

  @override
  void initState() {
    super.initState();
    _equipmentService =
        widget.equipmentService ?? EquipmentService(widget.session);
    _craftService = widget.craftService ?? CraftService(widget.session);
    _loadAll(reloadOptions: true);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _equipmentFilterLabel(EquipmentLedgerItem entry) {
    return '${entry.code} - ${entry.name}';
  }

  Widget _buildFilterDropdownText(String text) {
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  int get _totalPages {
    final pages = (_total + _pageSize - 1) ~/ _pageSize;
    return pages > 0 ? pages : 1;
  }

  Future<void> _updateFilterAndReload(VoidCallback update) async {
    setState(() {
      update();
      _page = 1;
    });
    await _loadAll(page: 1);
  }

  Future<void> _loadAll({int? page, bool reloadOptions = false}) async {
    final targetPage = page ?? _page;
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      if (reloadOptions) {
        final results = await Future.wait<Object>([
          _equipmentService.listEquipment(
            page: 1,
            pageSize: 200,
            enabled: true,
          ),
          _equipmentService.listMaintenanceItems(
            page: 1,
            pageSize: 200,
            enabled: true,
          ),
          _craftService.listStages(page: 1, pageSize: 500, enabled: true),
          _equipmentService.listAllOwners(),
        ]);
        final equipmentResult = results[0] as EquipmentLedgerListResult;
        final itemResult = results[1] as MaintenanceItemListResult;
        final stageResult = results[2] as CraftStageListResult;
        final ownerOptions = results[3] as List<EquipmentOwnerOption>;
        _equipmentOptions = equipmentResult.items;
        _itemOptions = itemResult.items;
        _ownerOptions = ownerOptions;
        _stageOptions = [...stageResult.items]
          ..sort((a, b) {
            final orderCompare = a.sortOrder.compareTo(b.sortOrder);
            if (orderCompare != 0) {
              return orderCompare;
            }
            return a.id.compareTo(b.id);
          });

        if (_equipmentFilterId != null &&
            !_equipmentOptions.any((e) => e.id == _equipmentFilterId)) {
          _equipmentFilterId = null;
        }
        if (_itemFilterId != null &&
            !_itemOptions.any((e) => e.id == _itemFilterId)) {
          _itemFilterId = null;
        }
      }

      final result = await _equipmentService.listMaintenancePlans(
        page: targetPage,
        pageSize: _pageSize,
        keyword: _keywordController.text.trim(),
        equipmentId: _equipmentFilterId,
        itemId: _itemFilterId,
        enabled: _enabledFilter,
        executionProcessCode: _executionStageCodeFilter,
        defaultExecutorUserId: _defaultExecutorFilterId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _page = targetPage;
        _plans = result.items;
        _total = result.total;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载保养计划失败: ${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showPlanEditDialog({MaintenancePlanItem? plan}) async {
    if (!mounted) {
      return;
    }
    if (_equipmentOptions.isEmpty ||
        _itemOptions.isEmpty ||
        _stageOptions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先维护设备台账、保养项目和工艺工段')));
      return;
    }
    final saved = await showMaintenancePlanFormDialog(
      context: context,
      equipmentService: _equipmentService,
      equipmentOptions: _equipmentOptions,
      itemOptions: _itemOptions,
      stageOptions: _stageOptions,
      ownerOptions: _ownerOptions,
      plan: plan,
    );

    if (saved == true) {
      await _loadAll();
    }
  }

  Future<void> _togglePlan(MaintenancePlanItem plan) async {
    final nextEnabled = !plan.isEnabled;
    final confirmed = await showMaintenancePlanToggleDialog(
      context: context,
      plan: plan,
      nextEnabled: nextEnabled,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await _equipmentService.toggleMaintenancePlan(
        planId: plan.id,
        enabled: nextEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(plan.isEnabled ? '计划已停用' : '计划已启用')),
        );
      }
      await _loadAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新计划状态失败: ${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _generateWorkOrder(MaintenancePlanItem plan) async {
    try {
      final result = await _equipmentService.generateMaintenancePlan(
        planId: plan.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.created
                  ? '执行单已生成 (ID: ${result.workOrderId})'
                  : '已存在待执行单 (ID: ${result.workOrderId})',
            ),
          ),
        );
      }
      await _loadAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成执行单失败: ${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _deletePlan(MaintenancePlanItem plan) async {
    if (!mounted) {
      return;
    }
    final confirmed = await showMaintenancePlanDeleteDialog(
      context: context,
      plan: plan,
    );
    if (!confirmed) {
      return;
    }
    try {
      await _equipmentService.deleteMaintenancePlan(planId: plan.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保养计划已删除')));
      }
      await _loadAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除保养计划失败: ${_errorMessage(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtersToolbar = Row(
      children: [
        Expanded(
          child: TextField(
            controller: _keywordController,
            decoration: const InputDecoration(
              labelText: '搜索设备/项目',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _loadAll(page: 1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: _equipmentFilterId,
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  '全部设备',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._equipmentOptions.map(
                (entry) => DropdownMenuItem<int?>(
                  value: entry.id,
                  child: _buildFilterDropdownText(_equipmentFilterLabel(entry)),
                ),
              ),
            ],
            selectedItemBuilder: (context) {
              return [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildFilterDropdownText('全部设备'),
                ),
                ..._equipmentOptions.map(
                  (entry) => Align(
                    alignment: Alignment.centerLeft,
                    child: _buildFilterDropdownText(
                      _equipmentFilterLabel(entry),
                    ),
                  ),
                ),
              ];
            },
            onChanged: (value) =>
                _updateFilterAndReload(() => _equipmentFilterId = value),
            decoration: const InputDecoration(
              labelText: '设备筛选',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: _itemFilterId,
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  '全部项目',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._itemOptions.map(
                (entry) => DropdownMenuItem<int?>(
                  value: entry.id,
                  child: _buildFilterDropdownText(entry.name),
                ),
              ),
            ],
            selectedItemBuilder: (context) {
              return [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildFilterDropdownText('全部项目'),
                ),
                ..._itemOptions.map(
                  (entry) => Align(
                    alignment: Alignment.centerLeft,
                    child: _buildFilterDropdownText(entry.name),
                  ),
                ),
              ];
            },
            onChanged: (value) =>
                _updateFilterAndReload(() => _itemFilterId = value),
            decoration: const InputDecoration(
              labelText: '项目筛选',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<bool?>(
            initialValue: _enabledFilter,
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('全部状态')),
              DropdownMenuItem<bool?>(value: true, child: Text('启用')),
              DropdownMenuItem<bool?>(value: false, child: Text('停用')),
            ],
            onChanged: (value) =>
                _updateFilterAndReload(() => _enabledFilter = value),
            decoration: const InputDecoration(
              labelText: '状态',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: _executionStageCodeFilter,
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  '全部执行工段',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._stageOptions.map(
                (entry) => DropdownMenuItem<String?>(
                  value: entry.code,
                  child: _buildFilterDropdownText(entry.name),
                ),
              ),
            ],
            selectedItemBuilder: (context) {
              return [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildFilterDropdownText('全部执行工段'),
                ),
                ..._stageOptions.map(
                  (entry) => Align(
                    alignment: Alignment.centerLeft,
                    child: _buildFilterDropdownText(entry.name),
                  ),
                ),
              ];
            },
            onChanged: (value) =>
                _updateFilterAndReload(() => _executionStageCodeFilter = value),
            decoration: const InputDecoration(
              labelText: '执行工段',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: _defaultExecutorFilterId,
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  '全部默认执行人',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._ownerOptions.map(
                (entry) => DropdownMenuItem<int?>(
                  value: entry.userId,
                  child: _buildFilterDropdownText(entry.displayName),
                ),
              ),
            ],
            selectedItemBuilder: (context) {
              return [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildFilterDropdownText('全部默认执行人'),
                ),
                ..._ownerOptions.map(
                  (entry) => Align(
                    alignment: Alignment.centerLeft,
                    child: _buildFilterDropdownText(entry.displayName),
                  ),
                ),
              ];
            },
            onChanged: (value) =>
                _updateFilterAndReload(() => _defaultExecutorFilterId = value),
            decoration: const InputDecoration(
              labelText: '默认执行人',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _loading ? null : () => _loadAll(page: 1),
          icon: const Icon(Icons.search),
          label: const Text('查询'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: (_loading || !widget.canWrite)
              ? null
              : () => _showPlanEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('新增计划'),
        ),
      ],
    );

    return MesCrudPageScaffold(
      header: MesRefreshPageHeader(
        title: '保养计划',
        onRefresh: _loading
            ? null
            : () => _loadAll(page: _page, reloadOptions: true),
      ),
      filters: filtersToolbar,
      banner: _message.isEmpty
          ? null
          : Text(
              _message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
      content: CrudListTableSection(
        loading: _loading,
        isEmpty: _plans.isEmpty,
        emptyText: '暂无保养计划',
        enableUnifiedHeaderStyle: true,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('设备')),
            DataColumn(label: Text('保养项目')),
            DataColumn(label: Text('执行工段')),
            DataColumn(label: Text('周期天数')),
            DataColumn(label: Text('开始日期')),
            DataColumn(label: Text('下次到期日')),
            DataColumn(label: Text('默认执行人')),
            DataColumn(label: Text('预计时长')),
            DataColumn(label: Text('创建时间')),
            DataColumn(label: Text('更新时间')),
            DataColumn(label: Text('状态')),
            DataColumn(label: Text('操作')),
          ],
          rows: _plans.map((plan) {
            return DataRow(
              cells: [
                DataCell(Text(plan.equipmentName)),
                DataCell(Text(plan.itemName)),
                DataCell(Text(plan.executionProcessName)),
                DataCell(Text('${plan.cycleDays}')),
                DataCell(Text(_formatDate(plan.startDate))),
                DataCell(Text(_formatDate(plan.nextDueDate))),
                DataCell(Text(plan.defaultExecutorUsername ?? '-')),
                DataCell(
                  Text(
                    plan.estimatedDurationMinutes == null
                        ? '-'
                        : '${plan.estimatedDurationMinutes} 分钟',
                  ),
                ),
                DataCell(Text(_formatDate(plan.createdAt))),
                DataCell(Text(_formatDate(plan.updatedAt))),
                DataCell(Text(plan.isEnabled ? '启用' : '停用')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: widget.canWrite
                            ? () => _showPlanEditDialog(plan: plan)
                            : null,
                        child: const Text('编辑'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.canWrite
                            ? () => _togglePlan(plan)
                            : null,
                        child: Text(plan.isEnabled ? '停用' : '启用'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.canWrite
                            ? () => _deletePlan(plan)
                            : null,
                        child: const Text('删除'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: (widget.canWrite && plan.isEnabled)
                            ? () => _generateWorkOrder(plan)
                            : null,
                        child: const Text('生成执行单'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
      pagination: MesPaginationBar(
        page: _page,
        totalPages: _totalPages,
        total: _total,
        loading: _loading,
        onPrevious: () => _loadAll(page: _page - 1),
        onNext: () => _loadAll(page: _page + 1),
      ),
    );
  }
}
