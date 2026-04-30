import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';

Future<bool?> showTemplateActionConfirmDialog({
  required BuildContext context,
  required CraftService craftService,
  required CraftTemplateItem item,
  required String title,
  required String confirmText,
  required String description,
  required VoidCallback onLogout,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => _TemplateActionConfirmDialog(
      craftService: craftService,
      item: item,
      title: title,
      confirmText: confirmText,
      description: description,
      onLogout: onLogout,
    ),
  );
}

class _TemplateActionConfirmDialog extends StatefulWidget {
  const _TemplateActionConfirmDialog({
    required this.craftService,
    required this.item,
    required this.title,
    required this.confirmText,
    required this.description,
    required this.onLogout,
  });

  final CraftService craftService;
  final CraftTemplateItem item;
  final String title;
  final String confirmText;
  final String description;
  final VoidCallback onLogout;

  @override
  State<_TemplateActionConfirmDialog> createState() => _TemplateActionConfirmDialogState();
}

class _TemplateActionConfirmDialogState extends State<_TemplateActionConfirmDialog> {
  bool _loading = true;
  String _error = '';
  CraftTemplateImpactAnalysis? _analysis;

  @override
  void initState() {
    super.initState();
    _loadImpactAnalysis();
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

  bool get _isBlocked => (_analysis?.blockedOrders ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MesDialog(
        title: Text('分析中'),
        width: 400,
        content: MesLoadingState(label: '正在分析操作影响...'),
      );
    }

    if (_error.isNotEmpty) {
      return MesDialog(
        title: const Text('错误'),
        width: 400,
        content: Text('分析失败: $_error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    final analysis = _analysis!;

    return MesDialog(
      title: Text(widget.title),
      width: 680,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_isBlocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.error.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block_flipped, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '当前存在 ${analysis.blockedOrders} 条阻断级引用，后端会拦截本次${widget.confirmText}；请先处理进行中工单后再操作。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _buildSummaryWrap(context, analysis),
            const SizedBox(height: 16),
            _buildActionImpactPreview(context, analysis),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isBlocked ? null : () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmText == '删除' ? Theme.of(context).colorScheme.error : null,
          ),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }

  Widget _buildSummaryWrap(BuildContext context, CraftTemplateImpactAnalysis analysis) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Tag(label: '总计 ${analysis.totalOrders} 订单', color: Colors.blue),
        _Tag(label: '待开工 ${analysis.pendingOrders}', color: Colors.grey),
        _Tag(label: '生产中 ${analysis.inProgressOrders}', color: Colors.orange),
        _Tag(label: '可同步 ${analysis.syncableOrders}', color: Colors.green),
        _Tag(label: '受阻 ${analysis.blockedOrders}', color: Colors.red),
      ],
    );
  }

  Widget _buildActionImpactPreview(BuildContext context, CraftTemplateImpactAnalysis analysis) {
    final previewReferences = analysis.referenceItems.take(5).toList();
    if (previewReferences.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('影响预览 (Top 5)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...previewReferences.map(
                (ref) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '· ${_referenceTitle(ref)}${ref.detail != null ? " (${ref.detail})" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (analysis.referenceItems.length > 5)
                Text(
                  '... 更多内容请查看详细分析报告',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
