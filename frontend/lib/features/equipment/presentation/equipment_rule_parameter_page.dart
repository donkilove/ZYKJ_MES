import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/presentation/widgets/equipment_rule_form_dialog.dart';
import 'package:mes_client/features/equipment/presentation/widgets/equipment_rule_parameter_action_dialogs.dart';
import 'package:mes_client/features/equipment/presentation/widgets/equipment_runtime_parameter_form_dialog.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';

enum _RuleListAction { openParameters, edit, toggle, delete }

enum _ParameterListAction { edit, toggle, delete }

const double _toolbarSpacing = 12;
const double _toolbarRunSpacing = 8;
const double _toolbarWideFieldMinWidth = 280;
const double _toolbarMediumFieldWidth = 200;
const double _toolbarNarrowFieldWidth = 140;

Widget _buildEquipmentDropdownText(String text) {
  return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
}

class EquipmentRuleParameterPage extends StatefulWidget {
  const EquipmentRuleParameterPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canViewRules,
    required this.canManageRules,
    required this.canViewParameters,
    required this.canManageParameters,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canViewRules;
  final bool canManageRules;
  final bool canViewParameters;
  final bool canManageParameters;
  final EquipmentService? service;

  @override
  State<EquipmentRuleParameterPage> createState() =>
      _EquipmentRuleParameterPageState();
}

class _EquipmentRuleParameterPageState extends State<EquipmentRuleParameterPage>
    with SingleTickerProviderStateMixin {
  late final EquipmentService _service;
  TabController? _innerTabController;
  final GlobalKey<_RulesTabState> _rulesTabKey = GlobalKey<_RulesTabState>();
  final GlobalKey<_ParametersTabState> _parametersTabKey =
      GlobalKey<_ParametersTabState>();
  List<EquipmentLedgerItem> _equipmentOptions = const [];
  int? _parametersTabIndex;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EquipmentService(widget.session);
    final tabCount =
        (widget.canViewRules ? 1 : 0) + (widget.canViewParameters ? 1 : 0);
    if (tabCount > 0) {
      _innerTabController = TabController(length: tabCount, vsync: this);
    }
    if (widget.canViewParameters) {
      _parametersTabIndex = widget.canViewRules ? 1 : 0;
    }
    _loadEquipmentOptions();
  }

  void _openParametersForRule(EquipmentRuleItem rule) {
    final tabIndex = _parametersTabIndex;
    if (tabIndex == null) {
      return;
    }
    final scope = _RuleParameterScope(
      ruleId: rule.id,
      ruleName: rule.ruleName,
      equipmentId: rule.equipmentId,
      equipmentName: rule.equipmentName,
      equipmentType: rule.equipmentType,
      isEnabled: rule.isEnabled,
    );
    _innerTabController?.animateTo(tabIndex);
    _applyRuleScopeAfterFrame(scope);
  }

  void _applyRuleScopeAfterFrame(_RuleParameterScope scope, [int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _parametersTabKey.currentState;
      if (state != null) {
        state.applyRuleScope(scope);
        return;
      }
      if (mounted && attempt < 5) {
        _applyRuleScopeAfterFrame(scope, attempt + 1);
      }
    });
  }

  Future<void> _loadEquipmentOptions() async {
    try {
      final result = await _service.listEquipment(
        page: 1,
        pageSize: 200,
        enabled: null,
      );
      if (mounted) {
        setState(() => _equipmentOptions = result.items);
      }
    } catch (_) {}
  }

  Future<void> _refreshCurrentTab() async {
    await _loadEquipmentOptions();
    final currentIndex = _innerTabController?.index ?? 0;
    if (currentIndex == _parametersTabIndex) {
      await _parametersTabKey.currentState?.refresh();
      return;
    }
    await _rulesTabKey.currentState?.refresh();
  }

  @override
  void dispose() {
    _innerTabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[];
    final children = <Widget>[];
    if (widget.canViewRules) {
      tabs.add(const Tab(text: '设备规则'));
      children.add(
        _RulesTab(
          key: _rulesTabKey,
          service: _service,
          onLogout: widget.onLogout,
          canManage: widget.canManageRules,
          canOpenParameters: widget.canViewParameters,
          canManageParameters: widget.canManageParameters,
          equipmentOptions: _equipmentOptions,
          onOpenParametersForRule: _openParametersForRule,
        ),
      );
    }
    if (widget.canViewParameters) {
      tabs.add(const Tab(text: '运行参数'));
      children.add(
        _ParametersTab(
          key: _parametersTabKey,
          service: _service,
          onLogout: widget.onLogout,
          canManage: widget.canManageParameters,
          equipmentOptions: _equipmentOptions,
        ),
      );
    }
    if (tabs.isEmpty || _innerTabController == null) {
      return const Center(child: Text('当前账号没有可访问的规则/参数页面。'));
    }
    return MesCrudPageScaffold(
      header: MesRefreshPageHeader(title: '规则与参数', onRefresh: _refreshCurrentTab),
      filters: Material(
        color: Theme.of(context).colorScheme.surface,
        child: TabBar(controller: _innerTabController, tabs: tabs),
      ),
      content: TabBarView(
        controller: _innerTabController,
        children: children,
      ),
    );
  }
}

class _RuleParameterScope {
  const _RuleParameterScope({
    required this.ruleId,
    required this.ruleName,
    required this.equipmentId,
    required this.equipmentName,
    required this.equipmentType,
    required this.isEnabled,
  });

  final int ruleId;
  final String ruleName;
  final int? equipmentId;
  final String? equipmentName;
  final String? equipmentType;
  final bool isEnabled;

  String get summary {
    final parts = <String>['规则#$ruleId $ruleName'];
    if (equipmentName != null && equipmentName!.trim().isNotEmpty) {
      parts.add('设备: ${equipmentName!.trim()}');
    } else if (equipmentId != null) {
      parts.add('设备ID: $equipmentId');
    }
    if (equipmentType != null && equipmentType!.trim().isNotEmpty) {
      parts.add('设备类型: ${equipmentType!.trim()}');
    }
    parts.add('状态: ${isEnabled ? '启用' : '停用'}');
    return parts.join(' / ');
  }
}

// ── 设备规则 Tab ──────────────────────────────────────────────────────────────

class _RulesTab extends StatefulWidget {
  const _RulesTab({
    super.key,
    required this.service,
    required this.onLogout,
    required this.canManage,
    required this.canOpenParameters,
    required this.canManageParameters,
    required this.equipmentOptions,
    required this.onOpenParametersForRule,
  });

  final EquipmentService service;
  final VoidCallback onLogout;
  final bool canManage;
  final bool canOpenParameters;
  final bool canManageParameters;
  final List<EquipmentLedgerItem> equipmentOptions;
  final ValueChanged<EquipmentRuleItem> onOpenParametersForRule;

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  static const int _pageSize = 30;

  bool _loading = false;
  String _message = '';
  int _total = 0;
  int _page = 1;
  bool? _isEnabledFilter;
  int? _equipmentFilterId;
  final _keywordController = TextEditingController();
  List<EquipmentRuleItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object e) => e is ApiException && e.statusCode == 401;
  String _errMsg(Object e) => e is ApiException ? e.message : e.toString();

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  int get _totalPages {
    final pages = (_total + _pageSize - 1) ~/ _pageSize;
    return pages > 0 ? pages : 1;
  }

  Future<void> refresh() async {
    await _load(page: _page);
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await widget.service.listEquipmentRules(
        equipmentId: _equipmentFilterId,
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        isEnabled: _isEnabledFilter,
        page: targetPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = targetPage;
        _items = result.items;
        _total = result.total;
      });
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      setState(() => _message = _errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showUpsertDialog({EquipmentRuleItem? item}) async {
    final confirmed = await showEquipmentRuleFormDialog(
      context: context,
      service: widget.service,
      equipmentOptions: widget.equipmentOptions,
      item: item,
    );
    if (confirmed == true && mounted) _load();
  }

  Future<void> _toggleRule(EquipmentRuleItem item) async {
    try {
      await widget.service.toggleEquipmentRule(
        ruleId: item.id,
        isEnabled: !item.isEnabled,
      );
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errMsg(e))));
    }
  }

  Future<void> _deleteRule(EquipmentRuleItem item) async {
    final confirmed = await showEquipmentRuleDeleteDialog(
      context: context,
      ruleName: item.ruleName,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.service.deleteEquipmentRule(item.id);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errMsg(e))));
    }
  }

  Widget _buildKeywordField() {
    return TextField(
      controller: _keywordController,
      decoration: const InputDecoration(
        labelText: '规则名称',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _load(page: 1),
    );
  }

  Widget _buildEquipmentFilter() {
    return DropdownButtonFormField<int?>(
      initialValue: _equipmentFilterId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '适用设备',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('全部设备')),
        ...widget.equipmentOptions.map(
          (entry) => DropdownMenuItem<int?>(
            value: entry.id,
            child: _buildEquipmentDropdownText(entry.name),
          ),
        ),
      ],
      onChanged: _loading
          ? null
          : (value) {
              setState(() => _equipmentFilterId = value);
            },
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<bool?>(
      key: ValueKey(_isEnabledFilter),
      initialValue: _isEnabledFilter,
      decoration: const InputDecoration(
        labelText: '状态',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: const [
        DropdownMenuItem<bool?>(value: null, child: Text('全部')),
        DropdownMenuItem<bool?>(value: true, child: Text('启用')),
        DropdownMenuItem<bool?>(value: false, child: Text('停用')),
      ],
      onChanged: _loading
          ? null
          : (value) {
              setState(() => _isEnabledFilter = value);
            },
    );
  }

  List<Widget> _buildToolbarButtons() {
    return [
      FilledButton.icon(
        onPressed: _loading ? null : () => _load(page: 1),
        icon: const Icon(Icons.search),
        label: const Text('查询规则'),
      ),
      if (widget.canManage)
        FilledButton.icon(
          onPressed: _loading ? null : () => _showUpsertDialog(),
          icon: const Icon(Icons.add),
          label: const Text('新增规则'),
        ),
    ];
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final equipmentFilter = SizedBox(
          width: _toolbarMediumFieldWidth,
          child: _buildEquipmentFilter(),
        );
        final statusFilter = SizedBox(
          width: _toolbarNarrowFieldWidth,
          child: _buildStatusFilter(),
        );
        final buttons = _buildToolbarButtons();
        final desktopToolbarMinWidth =
            _toolbarWideFieldMinWidth +
            _toolbarMediumFieldWidth +
            _toolbarNarrowFieldWidth +
            (buttons.length * 120) +
            ((buttons.length + 3) * _toolbarSpacing);

        if (constraints.maxWidth >= desktopToolbarMinWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildKeywordField()),
              const SizedBox(width: _toolbarSpacing),
              equipmentFilter,
              const SizedBox(width: _toolbarSpacing),
              statusFilter,
              const SizedBox(width: _toolbarSpacing),
              Wrap(
                spacing: _toolbarSpacing,
                runSpacing: _toolbarRunSpacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: buttons,
              ),
            ],
          );
        }

        return Wrap(
          spacing: _toolbarSpacing,
          runSpacing: _toolbarRunSpacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: constraints.maxWidth, child: _buildKeywordField()),
            equipmentFilter,
            statusFilter,
            ...buttons,
          ],
        );
      },
    );
  }

  Future<void> _handleRuleAction(
    _RuleListAction action,
    EquipmentRuleItem item,
  ) async {
    switch (action) {
      case _RuleListAction.openParameters:
        widget.onOpenParametersForRule(item);
        return;
      case _RuleListAction.edit:
        await _showUpsertDialog(item: item);
        return;
      case _RuleListAction.toggle:
        await _toggleRule(item);
        return;
      case _RuleListAction.delete:
        await _deleteRule(item);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(),
        const SizedBox(height: 12),
        Text('总数：$_total', style: theme.textTheme.titleMedium),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: CrudListTableSection(
            loading: _loading,
            isEmpty: _items.isEmpty,
            emptyText: '暂无设备规则',
            enableUnifiedHeaderStyle: true,
            child: DataTable(
              columnSpacing: 16,
              columns: [
                UnifiedListTableHeaderStyle.column(context, 'ID'),
                UnifiedListTableHeaderStyle.column(context, '适用设备'),
                UnifiedListTableHeaderStyle.column(context, '规则编码'),
                UnifiedListTableHeaderStyle.column(context, '规则名称'),
                UnifiedListTableHeaderStyle.column(context, '规则类型'),
                UnifiedListTableHeaderStyle.column(context, '触发条件'),
                UnifiedListTableHeaderStyle.column(context, '生效时间'),
                UnifiedListTableHeaderStyle.column(context, '备注'),
                UnifiedListTableHeaderStyle.column(context, '状态'),
                if (widget.canManage || widget.canOpenParameters)
                  UnifiedListTableHeaderStyle.column(context, '操作'),
              ],
              rows: _items.map((item) {
                return DataRow(
                  cells: [
                    DataCell(Text('${item.id}')),
                    DataCell(
                      Text(
                        item.equipmentName?.trim().isNotEmpty == true
                            ? item.equipmentName!
                            : item.equipmentType?.trim().isNotEmpty == true
                            ? item.equipmentType!
                            : '未配置',
                      ),
                    ),
                    DataCell(Text(item.ruleCode.isEmpty ? '-' : item.ruleCode)),
                    DataCell(Text(item.ruleName)),
                    DataCell(Text(item.ruleType.isEmpty ? '-' : item.ruleType)),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          item.conditionDesc.isEmpty ? '-' : item.conditionDesc,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(_formatDateTime(item.effectiveAt))),
                    DataCell(Text(item.remark.isEmpty ? '-' : item.remark)),
                    DataCell(Text(item.isEnabled ? '启用' : '停用')),
                    if (widget.canManage || widget.canOpenParameters)
                      DataCell(
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (widget.canOpenParameters)
                              SizedBox(
                                height: 28,
                                child: OutlinedButton(
                                  key: Key(
                                    'equipment-rule-open-parameters-${item.id}',
                                  ),
                                  onPressed: () =>
                                      widget.onOpenParametersForRule(item),
                                  child: Text(
                                    widget.canManageParameters
                                        ? '配置参数'
                                        : '查看参数',
                                  ),
                                ),
                              ),
                            if (widget.canManage)
                              KeyedSubtree(
                                key: Key('equipment-rule-actions-${item.id}'),
                                child:
                                    UnifiedListTableHeaderStyle.actionMenuButton<
                                      _RuleListAction
                                    >(
                                      theme: theme,
                                      onSelected: (action) =>
                                          _handleRuleAction(action, item),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: _RuleListAction.edit,
                                          child: Text('编辑'),
                                        ),
                                        PopupMenuItem(
                                          value: _RuleListAction.toggle,
                                          child: Text(
                                            item.isEnabled ? '停用' : '启用',
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: _RuleListAction.delete,
                                          child: Text('删除'),
                                        ),
                                      ],
                                    ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        MesPaginationBar(
          page: _page,
          totalPages: _totalPages,
          total: _total,
          loading: _loading,
          onPrevious: () => _load(page: _page - 1),
          onNext: () => _load(page: _page + 1),
        ),
      ],
    );
  }
}

// ── 运行参数 Tab ──────────────────────────────────────────────────────────────

class _ParametersTab extends StatefulWidget {
  const _ParametersTab({
    super.key,
    required this.service,
    required this.onLogout,
    required this.canManage,
    required this.equipmentOptions,
  });

  final EquipmentService service;
  final VoidCallback onLogout;
  final bool canManage;
  final List<EquipmentLedgerItem> equipmentOptions;

  @override
  State<_ParametersTab> createState() => _ParametersTabState();
}

class _ParametersTabState extends State<_ParametersTab> {
  static const int _pageSize = 30;

  bool _loading = false;
  String _message = '';
  int _total = 0;
  int _page = 1;
  final _keywordController = TextEditingController();
  final _equipmentTypeController = TextEditingController();
  int? _equipmentFilterId;
  bool? _isEnabledFilter;
  _RuleParameterScope? _activeRuleScope;
  List<EquipmentRuntimeParameterItem> _items = const [];

  void applyRuleScope(_RuleParameterScope scope) {
    _equipmentTypeController.text = scope.equipmentType?.trim() ?? '';
    setState(() {
      _page = 1;
      _activeRuleScope = scope;
      _equipmentFilterId = scope.equipmentId;
      _isEnabledFilter = scope.isEnabled;
    });
    _load(page: 1);
  }

  void _clearRuleScope() {
    _equipmentTypeController.clear();
    setState(() {
      _page = 1;
      _activeRuleScope = null;
      _equipmentFilterId = null;
      _isEnabledFilter = null;
    });
    _load(page: 1);
  }

  void _clearRuleScopeFlag() {
    if (_activeRuleScope != null) {
      setState(() => _activeRuleScope = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _equipmentTypeController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object e) => e is ApiException && e.statusCode == 401;
  String _errMsg(Object e) => e is ApiException ? e.message : e.toString();

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  int get _totalPages {
    final pages = (_total + _pageSize - 1) ~/ _pageSize;
    return pages > 0 ? pages : 1;
  }

  Future<void> refresh() async {
    await _load(page: _page);
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await widget.service.listRuntimeParameters(
        equipmentId: _equipmentFilterId,
        equipmentType: _equipmentTypeController.text.trim().isEmpty
            ? null
            : _equipmentTypeController.text.trim(),
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        isEnabled: _isEnabledFilter,
        page: targetPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = targetPage;
        _items = result.items;
        _total = result.total;
      });
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      setState(() => _message = _errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showUpsertDialog({EquipmentRuntimeParameterItem? item}) async {
    final confirmed = await showEquipmentRuntimeParameterFormDialog(
      context: context,
      service: widget.service,
      equipmentOptions: widget.equipmentOptions,
      item: item,
    );
    if (confirmed == true && mounted) _load();
  }

  Future<void> _deleteParam(EquipmentRuntimeParameterItem item) async {
    final confirmed = await showEquipmentRuntimeParameterDeleteDialog(
      context: context,
      paramName: item.paramName,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.service.deleteRuntimeParameter(item.id);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errMsg(e))));
    }
  }

  Future<void> _toggleParam(EquipmentRuntimeParameterItem item) async {
    try {
      await widget.service.toggleRuntimeParameter(
        paramId: item.id,
        enabled: !item.isEnabled,
      );
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errMsg(e))));
    }
  }

  Widget _buildKeywordField() {
    return TextField(
      controller: _keywordController,
      decoration: const InputDecoration(
        labelText: '参数名称/编码',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _load(page: 1),
    );
  }

  Widget _buildEquipmentTypeField() {
    return TextField(
      controller: _equipmentTypeController,
      decoration: const InputDecoration(
        labelText: '设备类型',
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => _clearRuleScopeFlag(),
      onSubmitted: (_) => _load(page: 1),
    );
  }

  Widget _buildEquipmentFilter() {
    return DropdownButtonFormField<int?>(
      initialValue: _equipmentFilterId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '适用设备',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('全部设备')),
        ...widget.equipmentOptions.map(
          (entry) => DropdownMenuItem<int?>(
            value: entry.id,
            child: _buildEquipmentDropdownText(entry.name),
          ),
        ),
      ],
      onChanged: _loading
          ? null
          : (value) {
              _clearRuleScopeFlag();
              setState(() => _equipmentFilterId = value);
            },
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<bool?>(
      initialValue: _isEnabledFilter,
      decoration: const InputDecoration(
        labelText: '状态',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: const [
        DropdownMenuItem<bool?>(value: null, child: Text('全部')),
        DropdownMenuItem<bool?>(value: true, child: Text('启用')),
        DropdownMenuItem<bool?>(value: false, child: Text('停用')),
      ],
      onChanged: _loading
          ? null
          : (value) {
              _clearRuleScopeFlag();
              setState(() => _isEnabledFilter = value);
            },
    );
  }

  List<Widget> _buildToolbarButtons() {
    return [
      FilledButton.icon(
        onPressed: _loading ? null : () => _load(page: 1),
        icon: const Icon(Icons.search),
        label: const Text('查询参数'),
      ),
      if (widget.canManage)
        FilledButton.icon(
          onPressed: _loading ? null : () => _showUpsertDialog(),
          icon: const Icon(Icons.add),
          label: const Text('新增参数'),
        ),
    ];
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final equipmentTypeField = SizedBox(
          width: 180,
          child: _buildEquipmentTypeField(),
        );
        final equipmentFilter = SizedBox(
          width: _toolbarMediumFieldWidth,
          child: _buildEquipmentFilter(),
        );
        final statusFilter = SizedBox(
          width: _toolbarNarrowFieldWidth,
          child: _buildStatusFilter(),
        );
        final buttons = _buildToolbarButtons();
        final desktopToolbarMinWidth =
            _toolbarWideFieldMinWidth +
            180 +
            _toolbarMediumFieldWidth +
            _toolbarNarrowFieldWidth +
            (buttons.length * 120) +
            ((buttons.length + 4) * _toolbarSpacing);

        if (constraints.maxWidth >= desktopToolbarMinWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildKeywordField()),
              const SizedBox(width: _toolbarSpacing),
              equipmentTypeField,
              const SizedBox(width: _toolbarSpacing),
              equipmentFilter,
              const SizedBox(width: _toolbarSpacing),
              statusFilter,
              const SizedBox(width: _toolbarSpacing),
              Wrap(
                spacing: _toolbarSpacing,
                runSpacing: _toolbarRunSpacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: buttons,
              ),
            ],
          );
        }

        return Wrap(
          spacing: _toolbarSpacing,
          runSpacing: _toolbarRunSpacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: constraints.maxWidth, child: _buildKeywordField()),
            equipmentTypeField,
            equipmentFilter,
            statusFilter,
            ...buttons,
          ],
        );
      },
    );
  }

  Future<void> _handleParameterAction(
    _ParameterListAction action,
    EquipmentRuntimeParameterItem item,
  ) async {
    switch (action) {
      case _ParameterListAction.edit:
        await _showUpsertDialog(item: item);
        return;
      case _ParameterListAction.toggle:
        await _toggleParam(item);
        return;
      case _ParameterListAction.delete:
        await _deleteParam(item);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(),
        const SizedBox(height: 12),
        if (_activeRuleScope != null)
          Container(
            key: const Key('equipment-parameter-scope-banner'),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final clearButton = TextButton(
                  onPressed: _loading ? null : _clearRuleScope,
                  child: const Text('清除范围'),
                );
                final summary = Text(
                  '当前按规则作用范围查看参数：${_activeRuleScope!.summary}',
                );
                if (constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [summary, const SizedBox(height: 8), clearButton],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: summary),
                    clearButton,
                  ],
                );
              },
            ),
          ),
        Text('总数：$_total', style: theme.textTheme.titleMedium),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: CrudListTableSection(
            loading: _loading,
            isEmpty: _items.isEmpty,
            emptyText: '暂无运行参数',
            enableUnifiedHeaderStyle: true,
            child: DataTable(
              columnSpacing: 16,
              columns: [
                UnifiedListTableHeaderStyle.column(context, 'ID'),
                UnifiedListTableHeaderStyle.column(context, '适用设备'),
                UnifiedListTableHeaderStyle.column(context, '参数编码'),
                UnifiedListTableHeaderStyle.column(context, '参数名称'),
                UnifiedListTableHeaderStyle.column(context, '单位'),
                UnifiedListTableHeaderStyle.column(context, '默认值'),
                UnifiedListTableHeaderStyle.column(context, '上限'),
                UnifiedListTableHeaderStyle.column(context, '下限'),
                UnifiedListTableHeaderStyle.column(context, '生效时间'),
                UnifiedListTableHeaderStyle.column(context, '状态'),
                UnifiedListTableHeaderStyle.column(context, '备注'),
                if (widget.canManage)
                  UnifiedListTableHeaderStyle.column(context, '操作'),
              ],
              rows: _items.map((item) {
                return DataRow(
                  cells: [
                    DataCell(Text('${item.id}')),
                    DataCell(
                      Text(
                        item.equipmentName?.trim().isNotEmpty == true
                            ? item.equipmentName!
                            : item.equipmentType?.trim().isNotEmpty == true
                            ? item.equipmentType!
                            : '未配置',
                      ),
                    ),
                    DataCell(Text(item.paramCode)),
                    DataCell(Text(item.paramName)),
                    DataCell(Text(item.unit.isEmpty ? '-' : item.unit)),
                    DataCell(Text(item.standardValue ?? '-')),
                    DataCell(Text(item.upperLimit ?? '-')),
                    DataCell(Text(item.lowerLimit ?? '-')),
                    DataCell(Text(_formatDateTime(item.effectiveAt))),
                    DataCell(Text(item.isEnabled ? '启用' : '停用')),
                    DataCell(Text(item.remark.isEmpty ? '-' : item.remark)),
                    if (widget.canManage)
                      DataCell(
                        KeyedSubtree(
                          key: Key('equipment-parameter-actions-${item.id}'),
                          child:
                              UnifiedListTableHeaderStyle.actionMenuButton<
                                _ParameterListAction
                              >(
                                theme: theme,
                                onSelected: (action) =>
                                    _handleParameterAction(action, item),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: _ParameterListAction.edit,
                                    child: Text('编辑'),
                                  ),
                                  PopupMenuItem(
                                    value: _ParameterListAction.toggle,
                                    child: Text(item.isEnabled ? '停用' : '启用'),
                                  ),
                                  const PopupMenuItem(
                                    value: _ParameterListAction.delete,
                                    child: Text('删除'),
                                  ),
                                ],
                              ),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        MesPaginationBar(
          page: _page,
          totalPages: _totalPages,
          total: _total,
          loading: _loading,
          onPrevious: () => _load(page: _page - 1),
          onNext: () => _load(page: _page + 1),
        ),
      ],
    );
  }
}
