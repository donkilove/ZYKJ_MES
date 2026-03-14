import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';

class CraftReferenceAnalysisPage extends StatefulWidget {
  const CraftReferenceAnalysisPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

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

  // 当前选中的工段/工序
  CraftStageItem? _selectedStage;
  CraftProcessItem? _selectedProcess;

  // 引用结果
  bool _loadingRef = false;
  CraftStageReferenceResult? _stageRefResult;
  CraftProcessReferenceResult? _processRefResult;

  // 搜索关键词
  final _stageSearchController = TextEditingController();
  final _processSearchController = TextEditingController();
  String _stageKeyword = '';
  String _processKeyword = '';

  @override
  void initState() {
    super.initState();
    _service = CraftService(widget.session);
    _loadBaseData();
  }

  @override
  void dispose() {
    _stageSearchController.dispose();
    _processSearchController.dispose();
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
      final stageResult = await _service.listStages(pageSize: 500, enabled: null);
      final processResult = await _service.listProcesses(pageSize: 500, enabled: null);
      if (!mounted) return;
      setState(() {
        _stages = [...stageResult.items]
          ..sort((a, b) {
            final c = a.sortOrder.compareTo(b.sortOrder);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
        _processes = [...processResult.items];
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
      _stageRefResult = null;
      _processRefResult = null;
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
      _stageRefResult = null;
      _processRefResult = null;
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

  Widget _buildRefTypeChip(String refType) {
    final (label, color) = switch (refType) {
      'process' => ('工序', Colors.blue),
      'user' => ('用户', Colors.purple),
      'template' => ('工艺模板', Colors.teal),
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
          title: Text(item.refName),
          subtitle: item.detail != null ? Text(item.detail!) : null,
          trailing: Text(
            '#${item.refId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }

  Widget _buildResultPanel(ThemeData theme) {
    if (_selectedStage == null && _selectedProcess == null) {
      return const Center(
        child: Text('请在左侧选择工段或工序以查看引用情况'),
      );
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

    return const SizedBox.shrink();
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
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loadingBase ? null : _loadBaseData,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingBase
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧：工段列表
                      SizedBox(
                        width: 220,
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
                                  onChanged: (v) =>
                                      setState(() => _stageKeyword = v.trim()),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _filteredStages.length,
                                    itemBuilder: (context, index) {
                                      final stage = _filteredStages[index];
                                      final selected =
                                          _selectedStage?.id == stage.id;
                                      return ListTile(
                                        dense: true,
                                        selected: selected,
                                        selectedTileColor: theme
                                            .colorScheme.primaryContainer
                                            .withValues(alpha: 0.4),
                                        title: Text(stage.name),
                                        subtitle: Text(stage.code),
                                        onTap: () =>
                                            _loadStageReferences(stage),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 中间：工序列表
                      SizedBox(
                        width: 240,
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
                                      final selected =
                                          _selectedProcess?.id == process.id;
                                      return ListTile(
                                        dense: true,
                                        selected: selected,
                                        selectedTileColor: theme
                                            .colorScheme.primaryContainer
                                            .withValues(alpha: 0.4),
                                        title: Text(process.name),
                                        subtitle: Text(
                                          '${process.stageName ?? '-'} · ${process.code}',
                                        ),
                                        onTap: () =>
                                            _loadProcessReferences(process),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 右侧：引用结果
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
