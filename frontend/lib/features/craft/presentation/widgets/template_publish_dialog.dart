import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';

Future<bool?> showTemplatePublishDialog({
  required BuildContext context,
  required CraftService craftService,
  required CraftTemplateItem item,
  required VoidCallback onLogout,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _TemplatePublishDialog(
      craftService: craftService,
      item: item,
      onLogout: onLogout,
    ),
  );
}

class _TemplatePublishDialog extends StatefulWidget {
  const _TemplatePublishDialog({
    required this.craftService,
    required this.item,
    required this.onLogout,
  });

  final CraftService craftService;
  final CraftTemplateItem item;
  final VoidCallback onLogout;

  @override
  State<_TemplatePublishDialog> createState() => _TemplatePublishDialogState();
}

class _TemplatePublishDialogState extends State<_TemplatePublishDialog> {
  bool _loading = true;
  bool _submitting = false;
  String _error = '';
  CraftTemplateImpactAnalysis? _analysis;
  
  final _noteController = TextEditingController();
  bool _syncOrders = false;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _loadImpactAnalysis();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadImpactAnalysis() async {
    try {
      final analysis = await widget.craftService.getTemplateImpactAnalysis(
        templateId: widget.item.id,
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _publish() async {
    if (_syncOrders && !_confirmed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先确认影响后再发布')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.craftService.publishTemplate(
        templateId: widget.item.id,
        applyOrderSync: _syncOrders,
        confirmed: !_syncOrders || _confirmed,
        expectedVersion: widget.item.version,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (e is ApiException && e.statusCode == 401) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MesDialog(
        title: Text('分析中'),
        width: 400,
        content: MesLoadingState(label: '正在进行影响分析...'),
      );
    }

    if (_error.isNotEmpty) {
      return MesDialog(
        title: const Text('错误'),
        width: 400,
        content: Text('获取影响分析失败: $_error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    final analysis = _analysis!;
    final hasBlockedOrders = analysis.items.any((item) => !item.syncable);

    return MesDialog(
      title: Text('发布模板 - ${widget.item.templateName}'),
      width: 860,
      content: SizedBox(
        height: 560,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Column: Analysis Report
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发布影响分析',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryWrap(analysis),
                      const SizedBox(height: 16),
                      if (hasBlockedOrders)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer.withAlpha(50),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Theme.of(context).colorScheme.error.withAlpha(100)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '存在无法同步的订单，发布时会自动跳过受阻订单。',
                                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      _buildReferenceSection(analysis),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Publish Settings
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '发布设置',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 4,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: '发布说明（评审意见）',
                      hintText: '请输入本次发布的说明或评审意见...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('同步更新现有订单'),
                    subtitle: const Text('仅同步可更新状态的订单'),
                    value: _syncOrders,
                    onChanged: (val) => setState(() {
                      _syncOrders = val;
                      if (!val) {
                        _confirmed = false;
                      }
                    }),
                  ),
                  if (_syncOrders)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('我已确认上述影响并继续发布'),
                      value: _confirmed,
                      onChanged: (val) => setState(() => _confirmed = val ?? false),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '注意：发布后，新创建的生产订单将默认使用此版本。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _publish,
          icon: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.publish_rounded, size: 18),
          label: Text(_submitting ? '发布中...' : '确认发布'),
        ),
      ],
    );
  }

  Widget _buildSummaryWrap(CraftTemplateImpactAnalysis analysis) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _AnalysisChip(label: '总计 ${analysis.totalOrders} 订单', color: Colors.blue),
        _AnalysisChip(label: '待开工 ${analysis.pendingOrders}', color: Colors.grey),
        _AnalysisChip(label: '生产中 ${analysis.inProgressOrders}', color: Colors.orange),
        _AnalysisChip(label: '可同步 ${analysis.syncableOrders}', color: Colors.green),
        if (analysis.totalReferences > 0)
          _AnalysisChip(label: '关键引用 ${analysis.totalReferences}', color: Colors.purple),
      ],
    );
  }

  Widget _buildReferenceSection(CraftTemplateImpactAnalysis analysis) {
    if (analysis.referenceItems.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('关键引用对象', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: analysis.referenceItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ref = analysis.referenceItems[index];
              return ListTile(
                dense: true,
                title: Text(_referenceTitle(ref)),
                subtitle: Text('ID: ${ref.refId}'),
              );
            },
          ),
        ),
      ],
    );
  }

  String _referenceTitle(CraftTemplateImpactReferenceItem ref) {
    final code = ref.refCode?.trim();
    final type = ref.refType.trim().isEmpty ? '引用' : ref.refType.trim();
    if (code != null && code.isNotEmpty && code != ref.refName) {
      return '$type: $code ${ref.refName}';
    }
    return '$type: ${ref.refName}';
  }
}

class _AnalysisChip extends StatelessWidget {
  const _AnalysisChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
