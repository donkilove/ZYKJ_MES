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
    required this.canManageRules,
    required this.canManageParameters,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canManageRules;
  final bool canManageParameters;

  @override
  State<EquipmentRuleParameterPage> createState() =>
      _EquipmentRuleParameterPageState();
}

class _EquipmentRuleParameterPageState
    extends State<EquipmentRuleParameterPage>
    with SingleTickerProviderStateMixin {
  late final EquipmentService _service;
  late final TabController _innerTabController;

  @override
  void initState() {
    super.initState();
    _service = EquipmentService(widget.session);
    _innerTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _innerTabController,
            tabs: const [
              Tab(text: '设备规则'),
              Tab(text: '运行参数'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTabController,
            children: [
              _RulesTab(
                service: _service,
                onLogout: widget.onLogout,
                canManage: widget.canManageRules,
              ),
              _ParametersTab(
                service: _service,
                onLogout: widget.onLogout,
                canManage: widget.canManageParameters,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 设备规则 Tab ──────────────────────────────────────────────────────────────

class _RulesTab extends StatefulWidget {
  const _RulesTab({
    required this.service,
    required this.onLogout,
    required this.canManage,
  });

  final EquipmentService service;
  final VoidCallback onLogout;
  final bool canManage;

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  bool _loading = false;
  String _message = '';
  int _total = 0;
  bool? _isEnabledFilter;
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

  Future<void> _load() async {
    setState(() { _loading = true; _message = ''; });
    try {
      final result = await widget.service.listEquipmentRules(
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        isEnabled: _isEnabledFilter,
      );
      if (!mounted) return;
      setState(() { _items = result.items; _total = result.total; });
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) { widget.onLogout(); return; }
      setState(() => _message = _errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showUpsertDialog({EquipmentRuleItem? item}) async {
    final nameCtrl = TextEditingController(text: item?.ruleName ?? '');
    final typeCtrl = TextEditingController(text: item?.ruleType ?? '');
    final condCtrl = TextEditingController(text: item?.conditionDesc ?? '');
    final remarkCtrl = TextEditingController(text: item?.remark ?? '');
    bool isEnabled = item?.isEnabled ?? true;

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
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('规则名称不能为空')),
      );
      return;
    }

    try {
      if (item == null) {
        await widget.service.createEquipmentRule(
          ruleName: nameCtrl.text.trim(),
          ruleType: typeCtrl.text.trim(),
          conditionDesc: condCtrl.text.trim(),
          isEnabled: isEnabled,
          remark: remarkCtrl.text.trim(),
        );
      } else {
        await widget.service.updateEquipmentRule(
          ruleId: item.id,
          ruleName: nameCtrl.text.trim(),
          ruleType: typeCtrl.text.trim(),
          conditionDesc: condCtrl.text.trim(),
          isEnabled: isEnabled,
          remark: remarkCtrl.text.trim(),
        );
      }
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) { widget.onLogout(); return; }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errMsg(e))),
      );
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
      if (_isUnauthorized(e)) { widget.onLogout(); return; }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errMsg(e))),
      );
    }
  }

  Future<void> _deleteRule(EquipmentRuleItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除规则「${item.ruleName}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.service.deleteEquipmentRule(item.id);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) { widget.onLogout(); return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMsg(e))));
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
                      : (v) { setState(() => _isEnabledFilter = v); _load(); },
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
              child: Text(_message, style: TextStyle(color: theme.colorScheme.error)),
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
                          const DataColumn(label: Text('规则名称')),
                          const DataColumn(label: Text('规则类型')),
                          const DataColumn(label: Text('触发条件')),
                          const DataColumn(label: Text('状态')),
                          if (widget.canManage)
                            const DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(cells: [
                            DataCell(Text('${item.id}')),
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
                            DataCell(Text(item.isEnabled ? '启用' : '停用')),
                            if (widget.canManage)
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => _showUpsertDialog(item: item),
                                    child: const Text('编辑'),
                                  ),
                                  TextButton(
                                    onPressed: () => _toggleRule(item),
                                    child: Text(item.isEnabled ? '停用' : '启用'),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteRule(item),
                                    child: Text(
                                      '删除',
                                      style: TextStyle(color: theme.colorScheme.error),
                                    ),
                                  ),
                                ],
                              )),
                          ]);
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
    required this.service,
    required this.onLogout,
    required this.canManage,
  });

  final EquipmentService service;
  final VoidCallback onLogout;
  final bool canManage;

  @override
  State<_ParametersTab> createState() => _ParametersTabState();
}

class _ParametersTabState extends State<_ParametersTab> {
  bool _loading = false;
  String _message = '';
  int _total = 0;
  final _keywordController = TextEditingController();
  List<EquipmentRuntimeParameterItem> _items = const [];

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

  Future<void> _load() async {
    setState(() { _loading = true; _message = ''; });
    try {
      final result = await widget.service.listRuntimeParameters(
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
      );
      if (!mounted) return;
      setState(() { _items = result.items; _total = result.total; });
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) { widget.onLogout(); return; }
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? '新增运行参数' : '编辑运行参数'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: '参数编码 *')),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '参数名称 *')),
              const SizedBox(height: 8),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: '单位')),
              const SizedBox(height: 8),
              TextField(controller: stdCtrl, decoration: const InputDecoration(labelText: '标准值'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: upperCtrl, decoration: const InputDecoration(labelText: '上限'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: lowerCtrl, decoration: const InputDecoration(labelText: '下限'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: remarkCtrl, decoration: const InputDecoration(labelText: '备注')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('参数编码和名称不能为空')),
      );
      return;
    }

    try {
      if (item == null) {
        await widget.service.createRuntimeParameter(
          paramCode: codeCtrl.text.trim(),
          paramName: nameCtrl.text.trim(),
          unit: unitCtrl.text.trim(),
          standardValue: stdCtrl.text.trim().isEmpty ? null : stdCtrl.text.trim(),
          upperLimit: upperCtrl.text.trim().isEmpty ? null : upperCtrl.text.trim(),
          lowerLimit: lowerCtrl.text.trim().isEmpty ? null : lowerCtrl.text.trim(),
          remark: remarkCtrl.text.trim(),
        );
      } else {
        await widget.service.updateRuntimeParameter(
          paramId: item.id,
          paramCode: codeCtrl.text.trim(),
          paramName: nameCtrl.text.trim(),
          unit: unitCtrl.text.trim(),
          standardValue: stdCtrl.text.trim().isEmpty ? null : stdCtrl.text.trim(),
          upperLimit: upperCtrl.text.trim().isEmpty ? null : upperCtrl.text.trim(),
          lowerLimit: lowerCtrl.text.trim().isEmpty ? null : lowerCtrl.text.trim(),
          remark: remarkCtrl.text.trim(),
        );
      }
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) { widget.onLogout(); return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMsg(e))));
    }
  }

  Future<void> _deleteParam(EquipmentRuntimeParameterItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除参数「${item.paramName}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.service.deleteRuntimeParameter(item.id);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) { widget.onLogout(); return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMsg(e))));
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
              IconButton(tooltip: '查询', onPressed: _loading ? null : _load, icon: const Icon(Icons.search)),
              IconButton(tooltip: '刷新', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
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
          Text('总数：$_total', style: theme.textTheme.titleMedium),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message, style: TextStyle(color: theme.colorScheme.error)),
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
                          const DataColumn(label: Text('参数编码')),
                          const DataColumn(label: Text('参数名称')),
                          const DataColumn(label: Text('单位')),
                          const DataColumn(label: Text('标准值')),
                          const DataColumn(label: Text('上限')),
                          const DataColumn(label: Text('下限')),
                          if (widget.canManage)
                            const DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(cells: [
                            DataCell(Text('${item.id}')),
                            DataCell(Text(item.paramCode)),
                            DataCell(Text(item.paramName)),
                            DataCell(Text(item.unit.isEmpty ? '-' : item.unit)),
                            DataCell(Text(item.standardValue ?? '-')),
                            DataCell(Text(item.upperLimit ?? '-')),
                            DataCell(Text(item.lowerLimit ?? '-')),
                            if (widget.canManage)
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => _showUpsertDialog(item: item),
                                    child: const Text('编辑'),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteParam(item),
                                    child: Text(
                                      '删除',
                                      style: TextStyle(color: theme.colorScheme.error),
                                    ),
                                  ),
                                ],
                              )),
                          ]);
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
