import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';

Future<void> showTemplateDetailDialog({
  required BuildContext context,
  required CraftService craftService,
  required CraftTemplateItem item,
  required VoidCallback onLogout,
}) async {
  showDialog<void>(
    context: context,
    builder: (context) => _TemplateDetailDialog(
      craftService: craftService,
      item: item,
      onLogout: onLogout,
    ),
  );
}

class _TemplateDetailDialog extends StatefulWidget {
  const _TemplateDetailDialog({
    required this.craftService,
    required this.item,
    required this.onLogout,
  });

  final CraftService craftService;
  final CraftTemplateItem item;
  final VoidCallback onLogout;

  @override
  State<_TemplateDetailDialog> createState() => _TemplateDetailDialogState();
}

class _TemplateDetailDialogState extends State<_TemplateDetailDialog> {
  bool _loading = true;
  String _error = '';
  CraftTemplateDetail? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await widget.craftService.getTemplateDetail(
        templateId: widget.item.id,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  String _lifecycleLabel(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return '草稿';
      case 'PUBLISHED':
        return '已发布';
      case 'ARCHIVED':
        return '已存档';
      default:
        return status;
    }
  }

  String _templateSourceLabel(CraftTemplateItem item) {
    if (item.sourceTemplateId == null || item.sourceTemplateId! <= 0) {
      return '自建';
    }
    return '引用系统母版 #${item.sourceTemplateId}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MesDialog(
        title: Text('加载中'),
        width: 400,
        content: MesLoadingState(label: '正在加载模板详情...'),
      );
    }

    if (_error.isNotEmpty) {
      return MesDialog(
        title: const Text('错误'),
        width: 400,
        content: Text('加载详情失败: $_error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    final item = widget.item;
    final detail = _detail!;

    return MesDialog(
      title: Text('模板详情 - ${item.templateName}'),
      width: 860,
      content: SizedBox(
        height: 520,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Column: Basic Info
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoItem(label: '产品', value: item.productName),
                  _InfoItem(
                    label: '版本',
                    value: 'v${item.version} / 已发布 P${item.publishedVersion}',
                  ),
                  _InfoItem(
                    label: '生命周期',
                    value: _lifecycleLabel(item.lifecycleStatus),
                    valueColor: item.lifecycleStatus.toUpperCase() == 'PUBLISHED'
                        ? Colors.green
                        : Colors.orange,
                  ),
                  _InfoItem(
                    label: '状态',
                    value: item.isEnabled ? '启用' : '停用',
                    valueColor: item.isEnabled ? Colors.blue : Colors.grey,
                  ),
                  _InfoItem(label: '来源', value: _templateSourceLabel(item)),
                  if (item.remark.trim().isNotEmpty)
                    _InfoItem(label: '备注', value: item.remark.trim()),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Steps
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Text(
                        '工艺步骤',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Expanded(
                      child: detail.steps.isEmpty
                          ? const Center(child: Text('暂无步骤'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(8),
                              itemCount: detail.steps.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final step = detail.steps[index];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    child: Text(
                                      '${step.stepOrder}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${step.stageCode} ${step.stageName}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${step.processCode} ${step.processName}',
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
