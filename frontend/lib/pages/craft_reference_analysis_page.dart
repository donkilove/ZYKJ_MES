import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';

enum _QueryMode { stage, process, template, product }

class _ProductOption {
  const _ProductOption({required this.id, required this.name});

  final int id;
  final String name;
}

class CraftReferenceAnalysisPage extends StatefulWidget {
  const CraftReferenceAnalysisPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onNavigate,
    this.craftService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final void Function({required String moduleCode, String? jumpTarget})
  onNavigate;
  final CraftService? craftService;

  @override
  State<CraftReferenceAnalysisPage> createState() =>
      _CraftReferenceAnalysisPageState();
}

class _CraftReferenceAnalysisPageState
    extends State<CraftReferenceAnalysisPage> {
  late final CraftService _service;

  bool _loadingBase = false;
  String _message = '';

  List<CraftStageItem> _stages = const [];
  List<CraftProcessItem> _processes = const [];
  List<CraftTemplateItem> _templates = const [];
  List<_ProductOption> _productOptions = const [];

  _QueryMode _queryMode = _QueryMode.stage;

  CraftStageItem? _selectedStage;
  CraftProcessItem? _selectedProcess;
  CraftTemplateItem? _selectedTemplate;
  _ProductOption? _selectedProduct;

  bool _loadingRef = false;
  CraftStageReferenceResult? _stageRefResult;
  CraftProcessReferenceResult? _processRefResult;
  CraftTemplateReferenceResult? _templateRefResult;
  CraftProductTemplateReferenceResult? _productRefResult;

  final _stageSearchController = TextEditingController();
  final _processSearchController = TextEditingController();
  final _templateSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  String _stageKeyword = '';
  String _processKeyword = '';
  String _templateKeyword = '';
  String _productKeyword = '';

  @override
  void initState() {
    super.initState();
    _service = widget.craftService ?? CraftService(widget.session);
    _loadBaseData();
  }

  @override
  void dispose() {
    _stageSearchController.dispose();
    _processSearchController.dispose();
    _templateSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) =>
      error is ApiException ? error.message : error.toString();

  Future<void> _loadBaseData() async {
    setState(() {
      _loadingBase = true;
      _message = '';
    });
    try {
      final stageResult = await _service.listStages(
        pageSize: 500,
        enabled: null,
      );
      final processResult = await _service.listProcesses(
        pageSize: 500,
        enabled: null,
      );
      final templateResult = await _service.listTemplates(
        pageSize: 500,
        enabled: null,
      );
      if (!mounted) return;
      setState(() {
        _stages = [...stageResult.items]
          ..sort((a, b) {
            final c = a.sortOrder.compareTo(b.sortOrder);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
        _processes = [...processResult.items];
        _templates = [...templateResult.items]
          ..sort((a, b) => a.templateName.compareTo(b.templateName));
        final products = <int, String>{};
        for (final item in _templates) {
          products[item.productId] = item.productName;
        }
        final productRows =
            products.entries
                .map(
                  (entry) => _ProductOption(id: entry.key, name: entry.value),
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        _productOptions = productRows;
      });
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载数据失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) setState(() => _loadingBase = false);
    }
  }

  Future<void> _loadStageReferences(CraftStageItem stage) async {
    setState(() {
      _selectedStage = stage;
      _selectedProcess = null;
      _selectedTemplate = null;
      _selectedProduct = null;
      _stageRefResult = null;
      _processRefResult = null;
      _templateRefResult = null;
      _productRefResult = null;
      _loadingRef = true;
    });
    try {
      final result = await _service.getStageReferences(stageId: stage.id);
      if (!mounted) return;
      setState(() => _stageRefResult = result);
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查询引用失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRef = false);
    }
  }

  Future<void> _loadProcessReferences(CraftProcessItem process) async {
    setState(() {
      _selectedProcess = process;
      _selectedStage = null;
      _selectedTemplate = null;
      _selectedProduct = null;
      _stageRefResult = null;
      _processRefResult = null;
      _templateRefResult = null;
      _productRefResult = null;
      _loadingRef = true;
    });
    try {
      final result = await _service.getProcessReferences(processId: process.id);
      if (!mounted) return;
      setState(() => _processRefResult = result);
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查询引用失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRef = false);
    }
  }

  Future<void> _loadTemplateReferences(CraftTemplateItem template) async {
    setState(() {
      _selectedTemplate = template;
      _selectedStage = null;
      _selectedProcess = null;
      _selectedProduct = null;
      _stageRefResult = null;
      _processRefResult = null;
      _templateRefResult = null;
      _productRefResult = null;
      _loadingRef = true;
    });
    try {
      final result = await _service.getTemplateReferences(
        templateId: template.id,
      );
      if (!mounted) return;
      setState(() => _templateRefResult = result);
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查询引用失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRef = false);
    }
  }

  Future<void> _loadProductTemplateReferences(_ProductOption product) async {
    setState(() {
      _selectedProduct = product;
      _selectedTemplate = null;
      _selectedStage = null;
      _selectedProcess = null;
      _stageRefResult = null;
      _processRefResult = null;
      _templateRefResult = null;
      _productRefResult = null;
      _loadingRef = true;
    });
    try {
      final result = await _service.getProductTemplateReferences(
        productId: product.id,
      );
      if (!mounted) return;
      setState(() => _productRefResult = result);
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查询引用失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRef = false);
    }
  }

  List<CraftStageItem> get _filteredStages {
    if (_stageKeyword.isEmpty) return _stages;
    final kw = _stageKeyword.toLowerCase();
    return _stages
        .where(
          (s) =>
              s.code.toLowerCase().contains(kw) ||
              s.name.toLowerCase().contains(kw),
        )
        .toList();
  }

  List<CraftProcessItem> get _filteredProcesses {
    if (_processKeyword.isEmpty) return _processes;
    final kw = _processKeyword.toLowerCase();
    return _processes
        .where(
          (p) =>
              p.code.toLowerCase().contains(kw) ||
              p.name.toLowerCase().contains(kw) ||
              (p.stageName?.toLowerCase().contains(kw) ?? false),
        )
        .toList();
  }

  List<CraftTemplateItem> get _filteredTemplates {
    if (_templateKeyword.isEmpty) return _templates;
    final kw = _templateKeyword.toLowerCase();
    return _templates
        .where(
          (t) =>
              t.templateName.toLowerCase().contains(kw) ||
              t.productName.toLowerCase().contains(kw),
        )
        .toList();
  }

  List<_ProductOption> get _filteredProducts {
    if (_productKeyword.isEmpty) return _productOptions;
    final kw = _productKeyword.toLowerCase();
    return _productOptions
        .where((item) => item.name.toLowerCase().contains(kw))
        .toList();
  }

  Widget _buildRefTypeChip(String refType) {
    final (label, color) = switch (refType) {
      'process' => ('工序', Colors.blue),
      'user' => ('用户', Colors.purple),
      'template' => ('工艺模板', Colors.teal),
      'template_reuse' => ('模板复用', Colors.teal),
      'system_master_template' => ('系统母版', Colors.indigo),
      'template_revision' => ('模板历史版本', Colors.teal),
      'system_master_revision' => ('母版历史版本', Colors.indigo),
      'order' => ('生产工单', Colors.orange),
      _ => (refType, Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRiskChip(String? riskLevel) {
    if (riskLevel == null || riskLevel == 'none') {
      return const SizedBox.shrink();
    }
    final (label, color) = switch (riskLevel) {
      'high' => ('高风险', Colors.red),
      'medium' => ('中风险', Colors.deepOrange),
      _ => ('低风险', Colors.amber),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildStatusChip(String? refStatus) {
    if (refStatus == null || refStatus.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final status = refStatus.trim();
    final color = switch (status) {
      '正在使用' => Colors.blue,
      '可同步' => Colors.green,
      '不可同步' => Colors.red,
      '历史引用' => Colors.grey,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.45)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  String _jumpLabel(CraftReferenceItem item) {
    final module = (item.jumpModule ?? '').trim();
    if (module.isEmpty) return '查看来源';
    return switch (module) {
      'production' => '跳转生产模块',
      'user' => '跳转用户模块',
      'product' => '跳转产品模块',
      'equipment' => '跳转设备模块',
      'quality' => '跳转品质模块',
      'craft' => '跳转工艺模块',
      _ => '查看来源',
    };
  }

  String _jumpLabelForRow({String? jumpModule}) {
    final module = (jumpModule ?? '').trim();
    if (module.isEmpty) return '查看来源';
    return switch (module) {
      'production' => '跳转生产模块',
      'user' => '跳转用户模块',
      'product' => '跳转产品模块',
      'equipment' => '跳转设备模块',
      'quality' => '跳转品质模块',
      'craft' => '跳转工艺模块',
      _ => '查看来源',
    };
  }

  void _navigateByTarget({
    required BuildContext context,
    required String? module,
    required String? target,
  }) {
    final normalizedTarget = (target ?? '').trim();
    final normalizedModule = (module ?? '').trim();
    if (normalizedTarget.isEmpty || normalizedModule.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可跳转来源')));
      return;
    }
    widget.onNavigate(
      moduleCode: normalizedModule,
      jumpTarget: normalizedTarget,
    );
  }

  Widget _buildReferenceList(List<CraftReferenceItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('无引用记录，可安全删除'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          dense: true,
          leading: _buildRefTypeChip(item.refType),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.refName),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildStatusChip(item.refStatus),
                  _buildRiskChip(item.riskLevel),
                ],
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.detail != null) Text(item.detail!),
              if ((item.refCode ?? '').trim().isNotEmpty)
                Text(
                  '编码/编号：${item.refCode}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (item.jumpTarget != null && item.jumpTarget!.trim().isNotEmpty)
                Text(
                  '来源：${item.jumpTarget}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (item.riskNote != null)
                Text(
                  item.riskNote!,
                  style: TextStyle(
                    fontSize: 11,
                    color: item.riskLevel == 'high'
                        ? Colors.red
                        : Colors.amber.shade800,
                  ),
                ),
            ],
          ),
          trailing: SizedBox(
            width: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '#${item.refId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    _navigateByTarget(
                      context: context,
                      module: item.jumpModule,
                      target: item.jumpTarget,
                    );
                  },
                  child: Text(_jumpLabel(item)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultPanel(ThemeData theme) {
    if (_selectedStage == null &&
        _selectedProcess == null &&
        _selectedTemplate == null &&
        _selectedProduct == null) {
      return const Center(child: Text('请在左侧选择工段、工序或模板以查看引用情况'));
    }
    if (_loadingRef) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stageRefResult != null) {
      final r = _stageRefResult!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '工段引用分析：${r.stageName} (${r.stageCode})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 12),
              Chip(
                label: Text('共 ${r.total} 处引用'),
                backgroundColor: r.total == 0
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildReferenceList(r.items)),
        ],
      );
    }

    if (_processRefResult != null) {
      final r = _processRefResult!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '工序引用分析：${r.processName} (${r.processCode})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 12),
              Chip(
                label: Text('共 ${r.total} 处引用'),
                backgroundColor: r.total == 0
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildReferenceList(r.items)),
        ],
      );
    }

    if (_templateRefResult != null) {
      final r = _templateRefResult!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '模板引用分析：${r.templateName}',
                style: theme.textTheme.titleMedium,
              ),
              Text('(${r.productName})', style: theme.textTheme.bodySmall),
              Chip(
                label: Text('共 ${r.total} 处引用'),
                backgroundColor: r.total == 0
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
              ),
              if (r.orderReferenceCount > 0) ...[
                Chip(
                  label: Text('生产工单 ${r.orderReferenceCount}'),
                  backgroundColor: Colors.orange.withValues(alpha: 0.12),
                ),
              ],
              if (r.userStageReferenceCount > 0) ...[
                Chip(
                  label: Text('用户工段 ${r.userStageReferenceCount}'),
                  backgroundColor: Colors.blue.withValues(alpha: 0.12),
                ),
              ],
              if (r.templateReuseReferenceCount > 0) ...[
                Chip(
                  label: Text('模板复用 ${r.templateReuseReferenceCount}'),
                  backgroundColor: Colors.teal.withValues(alpha: 0.12),
                ),
              ],
              if (r.hasBlockingReferences) ...[
                Chip(
                  label: Text('阻断 ${r.blockingReferenceCount}'),
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildReferenceList(r.items)),
        ],
      );
    }

    if (_productRefResult != null) {
      final r = _productRefResult!;
      final grouped = <int, List<CraftProductTemplateReferenceRow>>{};
      for (final row in r.items) {
        grouped.putIfAbsent(row.templateId, () => []).add(row);
      }
      final templateIds = grouped.keys.toList()..sort();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '按产品查询：${r.productName}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 12),
              Chip(
                label: Text(
                  '模板 ${r.totalTemplates} 个 / 引用 ${r.totalReferences} 条',
                ),
                backgroundColor: Colors.blue.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: templateIds.isEmpty
                ? const Center(child: Text('该产品下暂无模板引用'))
                : ListView.separated(
                    itemCount: templateIds.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final templateId = templateIds[index];
                      final rows = grouped[templateId] ?? const [];
                      final first = rows.first;
                      return ExpansionTile(
                        title: Text(
                          '${first.templateName} (${first.lifecycleStatus})',
                        ),
                        subtitle: Text('引用 ${rows.length} 条'),
                        children: rows
                            .map(
                              (row) => ListTile(
                                dense: true,
                                leading: _buildRefTypeChip(row.refType),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(row.refName),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        _buildStatusChip(row.refStatus),
                                        _buildRiskChip(row.riskLevel),
                                      ],
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  [
                                    if ((row.detail ?? '').trim().isNotEmpty)
                                      row.detail!.trim(),
                                    if ((row.refCode ?? '').trim().isNotEmpty)
                                      '编码/编号：${row.refCode!.trim()}',
                                    if ((row.jumpTarget ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      row.jumpTarget!.trim(),
                                    if ((row.riskNote ?? '').trim().isNotEmpty)
                                      row.riskNote!.trim(),
                                  ].join(' · '),
                                ),
                                trailing: SizedBox(
                                  width: 180,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '#${row.refId}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: 4),
                                      TextButton(
                                        onPressed: () {
                                          _navigateByTarget(
                                            context: context,
                                            module: row.jumpModule,
                                            target: row.jumpTarget,
                                          );
                                        },
                                        child: Text(
                                          _jumpLabelForRow(
                                            jumpModule: row.jumpModule,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildModeTab(ThemeData theme) {
    return SegmentedButton<_QueryMode>(
      segments: const [
        ButtonSegment(value: _QueryMode.stage, label: Text('工段')),
        ButtonSegment(value: _QueryMode.process, label: Text('工序')),
        ButtonSegment(value: _QueryMode.template, label: Text('模板')),
        ButtonSegment(value: _QueryMode.product, label: Text('按产品')),
      ],
      selected: {_queryMode},
      onSelectionChanged: (s) {
        setState(() {
          _queryMode = s.first;
          _selectedStage = null;
          _selectedProcess = null;
          _selectedTemplate = null;
          _selectedProduct = null;
          _stageRefResult = null;
          _processRefResult = null;
          _templateRefResult = null;
          _productRefResult = null;
        });
      },
    );
  }

  Widget _buildSelectorPanel(ThemeData theme) {
    switch (_queryMode) {
      case _QueryMode.stage:
        return SizedBox(
          width: 240,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('工段', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _stageSearchController,
                    decoration: const InputDecoration(
                      hintText: '搜索工段',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                    ),
                    onChanged: (v) => setState(() => _stageKeyword = v.trim()),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredStages.length,
                      itemBuilder: (context, index) {
                        final stage = _filteredStages[index];
                        final selected = _selectedStage?.id == stage.id;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.4),
                          title: Text(stage.name),
                          subtitle: Text(stage.code),
                          onTap: () => _loadStageReferences(stage),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case _QueryMode.process:
        return SizedBox(
          width: 260,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('工序', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _processSearchController,
                    decoration: const InputDecoration(
                      hintText: '搜索工序',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => _processKeyword = v.trim()),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredProcesses.length,
                      itemBuilder: (context, index) {
                        final process = _filteredProcesses[index];
                        final selected = _selectedProcess?.id == process.id;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.4),
                          title: Text(process.name),
                          subtitle: Text(
                            '${process.stageName ?? '-'} · ${process.code}',
                          ),
                          onTap: () => _loadProcessReferences(process),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case _QueryMode.template:
        return SizedBox(
          width: 280,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('工艺模板', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _templateSearchController,
                    decoration: const InputDecoration(
                      hintText: '搜索模板/产品',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => _templateKeyword = v.trim()),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredTemplates.length,
                      itemBuilder: (context, index) {
                        final template = _filteredTemplates[index];
                        final selected = _selectedTemplate?.id == template.id;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.4),
                          title: Text(template.templateName),
                          subtitle: Text(
                            '${template.productName} · ${template.lifecycleStatus}',
                          ),
                          onTap: () => _loadTemplateReferences(template),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case _QueryMode.product:
        return SizedBox(
          width: 280,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('按产品查询模板引用', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _productSearchController,
                    decoration: const InputDecoration(
                      hintText: '搜索产品',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => _productKeyword = v.trim()),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final selected = _selectedProduct?.id == product.id;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.4),
                          title: Text(product.name),
                          subtitle: Text('#${product.id}'),
                          onTap: () => _loadProductTemplateReferences(product),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
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
              Text(
                '工艺引用分析',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loadingBase ? null : _loadBaseData,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildModeTab(theme),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingBase
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSelectorPanel(theme),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _buildResultPanel(theme),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
