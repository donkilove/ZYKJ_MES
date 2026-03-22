import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';

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
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(controller: _innerTabController, tabs: tabs),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTabController,
            children: children,
          ),
        ),
      ],
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
  bool _loading = false;
  String _message = '';
  int _total = 0;
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

  Future<DateTime?> _pickEffectiveDate(DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    return picked;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  Future<void> _load() async {
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
      );
      if (!mounted) return;
      setState(() {
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
    final codeCtrl = TextEditingController(text: item?.ruleCode ?? '');
    final nameCtrl = TextEditingController(text: item?.ruleName ?? '');
    final typeCtrl = TextEditingController(text: item?.ruleType ?? '');
    final condCtrl = TextEditingController(text: item?.conditionDesc ?? '');
    final remarkCtrl = TextEditingController(text: item?.remark ?? '');
    bool isEnabled = item?.isEnabled ?? true;
    int? selectedEquipmentId = item?.equipmentId;
    final equipmentTypeCtrl = TextEditingController(
      text: item?.equipmentType ?? '',
    );
    DateTime? selectedEffectiveAt = item?.effectiveAt;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(item == null ? '新增设备规则' : '编辑设备规则'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: '规则编码 *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '规则名称 *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(labelText: '规则类型'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: condCtrl,
                  decoration: const InputDecoration(labelText: '触发条件'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: remarkCtrl,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('启用'),
                  value: isEnabled,
                  onChanged: (v) => setS(() => isEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: selectedEquipmentId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('适用全部设备'),
                    ),
                    ...widget.equipmentOptions.map(
                      (entry) => DropdownMenuItem<int?>(
                        value: entry.id,
                        child: Text('${entry.code} ${entry.name}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setS(() => selectedEquipmentId = value),
                  decoration: const InputDecoration(labelText: '适用设备'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: equipmentTypeCtrl,
                  decoration: const InputDecoration(labelText: '适用设备类型'),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await _pickEffectiveDate(
                      selectedEffectiveAt,
                    );
                    if (picked != null) {
                      setS(() => selectedEffectiveAt = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '生效时间'),
                    child: Text(_formatDateTime(selectedEffectiveAt)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('规则编码和名称不能为空')));
      return;
    }
    if (selectedEquipmentId == null && equipmentTypeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择适用设备或填写设备类型')));
      return;
    }

    try {
      if (item == null) {
        await widget.service.createEquipmentRule(
          equipmentId: selectedEquipmentId,
          equipmentType: equipmentTypeCtrl.text.trim().isEmpty
              ? null
              : equipmentTypeCtrl.text.trim(),
          ruleCode: codeCtrl.text.trim(),
          ruleName: nameCtrl.text.trim(),
          ruleType: typeCtrl.text.trim(),
          conditionDesc: condCtrl.text.trim(),
          isEnabled: isEnabled,
          effectiveAt: selectedEffectiveAt,
          remark: remarkCtrl.text.trim(),
        );
      } else {
        await widget.service.updateEquipmentRule(
          ruleId: item.id,
          equipmentId: selectedEquipmentId,
          equipmentType: equipmentTypeCtrl.text.trim().isEmpty
              ? null
              : equipmentTypeCtrl.text.trim(),
          ruleCode: codeCtrl.text.trim(),
          ruleName: nameCtrl.text.trim(),
          ruleType: typeCtrl.text.trim(),
          conditionDesc: condCtrl.text.trim(),
          isEnabled: isEnabled,
          effectiveAt: selectedEffectiveAt,
          remark: remarkCtrl.text.trim(),
        );
      }
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除规则「${item.ruleName}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '规则名称',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int?>(
                  initialValue: _equipmentFilterId,
                  decoration: const InputDecoration(
                    labelText: '适用设备',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('全部设备'),
                    ),
                    ...widget.equipmentOptions.map(
                      (entry) => DropdownMenuItem<int?>(
                        value: entry.id,
                        child: Text(entry.name),
                      ),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (v) {
                          setState(() => _equipmentFilterId = v);
                          _load();
                        },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<bool?>(
                  key: ValueKey(_isEnabledFilter),
                  initialValue: _isEnabledFilter,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('全部')),
                    DropdownMenuItem(value: true, child: Text('启用')),
                    DropdownMenuItem(value: false, child: Text('停用')),
                  ],
                  onChanged: _loading
                      ? null
                      : (v) {
                          setState(() => _isEnabledFilter = v);
                          _load();
                        },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: '查询',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
              const Spacer(),
              if (widget.canManage)
                ElevatedButton.icon(
                  onPressed: _loading ? null : () => _showUpsertDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('新增规则'),
                ),
            ],
          ),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('暂无设备规则'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('ID')),
                          const DataColumn(label: Text('适用设备')),
                          const DataColumn(label: Text('规则编码')),
                          const DataColumn(label: Text('规则名称')),
                          const DataColumn(label: Text('规则类型')),
                          const DataColumn(label: Text('触发条件')),
                          const DataColumn(label: Text('生效时间')),
                          const DataColumn(label: Text('备注')),
                          const DataColumn(label: Text('状态')),
                          if (widget.canManage || widget.canOpenParameters)
                            const DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text('${item.id}')),
                              DataCell(
                                Text(
                                  item.equipmentName?.trim().isNotEmpty == true
                                      ? item.equipmentName!
                                      : item.equipmentType?.trim().isNotEmpty ==
                                            true
                                      ? item.equipmentType!
                                      : '未配置',
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.ruleCode.isEmpty ? '-' : item.ruleCode,
                                ),
                              ),
                              DataCell(Text(item.ruleName)),
                              DataCell(
                                Text(
                                  item.ruleType.isEmpty ? '-' : item.ruleType,
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 200,
                                  ),
                                  child: Text(
                                    item.conditionDesc.isEmpty
                                        ? '-'
                                        : item.conditionDesc,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(_formatDateTime(item.effectiveAt))),
                              DataCell(
                                Text(item.remark.isEmpty ? '-' : item.remark),
                              ),
                              DataCell(Text(item.isEnabled ? '启用' : '停用')),
                              if (widget.canManage || widget.canOpenParameters)
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.canOpenParameters)
                                        TextButton(
                                          key: Key(
                                            'equipment-rule-open-parameters-${item.id}',
                                          ),
                                          onPressed: () => widget
                                              .onOpenParametersForRule(item),
                                          child: Text(
                                            widget.canManageParameters
                                                ? '配置参数'
                                                : '查看参数',
                                          ),
                                        ),
                                      if (widget.canManage)
                                        TextButton(
                                          onPressed: () =>
                                              _showUpsertDialog(item: item),
                                          child: const Text('编辑'),
                                        ),
                                      if (widget.canManage)
                                        TextButton(
                                          onPressed: () => _toggleRule(item),
                                          child: Text(
                                            item.isEnabled ? '停用' : '启用',
                                          ),
                                        ),
                                      if (widget.canManage)
                                        TextButton(
                                          onPressed: () => _deleteRule(item),
                                          child: Text(
                                            '删除',
                                            style: TextStyle(
                                              color: theme.colorScheme.error,
                                            ),
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
          ),
        ],
      ),
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
  bool _loading = false;
  String _message = '';
  int _total = 0;
  final _keywordController = TextEditingController();
  final _equipmentTypeController = TextEditingController();
  int? _equipmentFilterId;
  bool? _isEnabledFilter;
  _RuleParameterScope? _activeRuleScope;
  List<EquipmentRuntimeParameterItem> _items = const [];

  void applyRuleScope(_RuleParameterScope scope) {
    _equipmentTypeController.text = scope.equipmentType?.trim() ?? '';
    setState(() {
      _activeRuleScope = scope;
      _equipmentFilterId = scope.equipmentId;
      _isEnabledFilter = scope.isEnabled;
    });
    _load();
  }

  void _clearRuleScope() {
    _equipmentTypeController.clear();
    setState(() {
      _activeRuleScope = null;
      _equipmentFilterId = null;
      _isEnabledFilter = null;
    });
    _load();
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

  Future<DateTime?> _pickEffectiveDate(DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    return picked;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  Future<void> _load() async {
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
      );
      if (!mounted) return;
      setState(() {
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
    final codeCtrl = TextEditingController(text: item?.paramCode ?? '');
    final nameCtrl = TextEditingController(text: item?.paramName ?? '');
    final unitCtrl = TextEditingController(text: item?.unit ?? '');
    final stdCtrl = TextEditingController(text: item?.standardValue ?? '');
    final upperCtrl = TextEditingController(text: item?.upperLimit ?? '');
    final lowerCtrl = TextEditingController(text: item?.lowerLimit ?? '');
    final remarkCtrl = TextEditingController(text: item?.remark ?? '');
    int? selectedEquipmentId = item?.equipmentId;
    final equipmentTypeCtrl = TextEditingController(
      text: item?.equipmentType ?? '',
    );
    DateTime? selectedEffectiveAt = item?.effectiveAt;
    bool isEnabled = item?.isEnabled ?? true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(item == null ? '新增运行参数' : '编辑运行参数'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: '参数编码 *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '参数名称 *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: '单位'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stdCtrl,
                  decoration: const InputDecoration(labelText: '默认值'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: upperCtrl,
                  decoration: const InputDecoration(labelText: '上限'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: lowerCtrl,
                  decoration: const InputDecoration(labelText: '下限'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: remarkCtrl,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: selectedEquipmentId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('适用全部设备'),
                    ),
                    ...widget.equipmentOptions.map(
                      (entry) => DropdownMenuItem<int?>(
                        value: entry.id,
                        child: Text('${entry.code} ${entry.name}'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setStateDialog(() => selectedEquipmentId = value);
                  },
                  decoration: const InputDecoration(labelText: '适用设备'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: equipmentTypeCtrl,
                  decoration: const InputDecoration(labelText: '适用设备类型'),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await _pickEffectiveDate(
                      selectedEffectiveAt,
                    );
                    if (picked != null) {
                      setStateDialog(() => selectedEffectiveAt = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '生效时间'),
                    child: Text(_formatDateTime(selectedEffectiveAt)),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('启用'),
                  value: isEnabled,
                  onChanged: (value) {
                    setStateDialog(() => isEnabled = value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('参数编码和名称不能为空')));
      return;
    }
    final standardValue = stdCtrl.text.trim();
    final upperLimit = upperCtrl.text.trim();
    final lowerLimit = lowerCtrl.text.trim();
    final parsedStandard = standardValue.isEmpty
        ? null
        : double.tryParse(standardValue);
    final parsedUpper = upperLimit.isEmpty ? null : double.tryParse(upperLimit);
    final parsedLower = lowerLimit.isEmpty ? null : double.tryParse(lowerLimit);
    if ((standardValue.isNotEmpty && parsedStandard == null) ||
        (upperLimit.isNotEmpty && parsedUpper == null) ||
        (lowerLimit.isNotEmpty && parsedLower == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('默认值、上限、下限必须为有效数字')));
      return;
    }
    if (parsedUpper != null &&
        parsedLower != null &&
        parsedLower > parsedUpper) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('下限不能大于上限')));
      return;
    }
    if (selectedEquipmentId == null && equipmentTypeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择适用设备或填写设备类型')));
      return;
    }

    try {
      if (item == null) {
        await widget.service.createRuntimeParameter(
          equipmentId: selectedEquipmentId,
          equipmentType: equipmentTypeCtrl.text.trim().isEmpty
              ? null
              : equipmentTypeCtrl.text.trim(),
          paramCode: codeCtrl.text.trim(),
          paramName: nameCtrl.text.trim(),
          unit: unitCtrl.text.trim(),
          standardValue: standardValue.isEmpty ? null : standardValue,
          upperLimit: upperLimit.isEmpty ? null : upperLimit,
          lowerLimit: lowerLimit.isEmpty ? null : lowerLimit,
          effectiveAt: selectedEffectiveAt,
          isEnabled: isEnabled,
          remark: remarkCtrl.text.trim(),
        );
      } else {
        await widget.service.updateRuntimeParameter(
          paramId: item.id,
          equipmentId: selectedEquipmentId,
          equipmentType: equipmentTypeCtrl.text.trim().isEmpty
              ? null
              : equipmentTypeCtrl.text.trim(),
          paramCode: codeCtrl.text.trim(),
          paramName: nameCtrl.text.trim(),
          unit: unitCtrl.text.trim(),
          standardValue: standardValue.isEmpty ? null : standardValue,
          upperLimit: upperLimit.isEmpty ? null : upperLimit,
          lowerLimit: lowerLimit.isEmpty ? null : lowerLimit,
          effectiveAt: selectedEffectiveAt,
          isEnabled: isEnabled,
          remark: remarkCtrl.text.trim(),
        );
      }
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

  Future<void> _deleteParam(EquipmentRuntimeParameterItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除参数「${item.paramName}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '参数名称/编码',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _equipmentTypeController,
                  decoration: const InputDecoration(
                    labelText: '设备类型',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _clearRuleScopeFlag(),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int?>(
                  initialValue: _equipmentFilterId,
                  decoration: const InputDecoration(
                    labelText: '适用设备',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('全部设备'),
                    ),
                    ...widget.equipmentOptions.map(
                      (entry) => DropdownMenuItem<int?>(
                        value: entry.id,
                        child: Text(entry.name),
                      ),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          _clearRuleScopeFlag();
                          setState(() => _equipmentFilterId = value);
                          _load();
                        },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _isEnabledFilter,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    border: OutlineInputBorder(),
                    isDense: true,
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
                          _load();
                        },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: '查询',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
              const Spacer(),
              if (widget.canManage)
                ElevatedButton.icon(
                  onPressed: _loading ? null : () => _showUpsertDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('新增参数'),
                ),
            ],
          ),
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
              child: Row(
                children: [
                  Expanded(
                    child: Text('当前按规则作用范围查看参数：${_activeRuleScope!.summary}'),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _clearRuleScope,
                    child: const Text('清除范围'),
                  ),
                ],
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('暂无运行参数'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('ID')),
                          const DataColumn(label: Text('适用设备')),
                          const DataColumn(label: Text('参数编码')),
                          const DataColumn(label: Text('参数名称')),
                          const DataColumn(label: Text('单位')),
                          const DataColumn(label: Text('默认值')),
                          const DataColumn(label: Text('上限')),
                          const DataColumn(label: Text('下限')),
                          const DataColumn(label: Text('生效时间')),
                          const DataColumn(label: Text('状态')),
                          const DataColumn(label: Text('备注')),
                          if (widget.canManage)
                            const DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text('${item.id}')),
                              DataCell(
                                Text(
                                  item.equipmentName?.trim().isNotEmpty == true
                                      ? item.equipmentName!
                                      : item.equipmentType?.trim().isNotEmpty ==
                                            true
                                      ? item.equipmentType!
                                      : '未配置',
                                ),
                              ),
                              DataCell(Text(item.paramCode)),
                              DataCell(Text(item.paramName)),
                              DataCell(
                                Text(item.unit.isEmpty ? '-' : item.unit),
                              ),
                              DataCell(Text(item.standardValue ?? '-')),
                              DataCell(Text(item.upperLimit ?? '-')),
                              DataCell(Text(item.lowerLimit ?? '-')),
                              DataCell(Text(_formatDateTime(item.effectiveAt))),
                              DataCell(Text(item.isEnabled ? '启用' : '停用')),
                              DataCell(
                                Text(item.remark.isEmpty ? '-' : item.remark),
                              ),
                              if (widget.canManage)
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _showUpsertDialog(item: item),
                                        child: const Text('编辑'),
                                      ),
                                      TextButton(
                                        onPressed: () => _toggleParam(item),
                                        child: Text(
                                          item.isEnabled ? '停用' : '启用',
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => _deleteParam(item),
                                        child: Text(
                                          '删除',
                                          style: TextStyle(
                                            color: theme.colorScheme.error,
                                          ),
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
          ),
        ],
      ),
    );
  }
}
