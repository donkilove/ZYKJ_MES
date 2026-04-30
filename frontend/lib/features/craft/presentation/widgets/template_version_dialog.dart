import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';

class TemplateVersionDisplayEntry {
  const TemplateVersionDisplayEntry({
    required this.version,
    required this.action,
    required this.note,
    required this.createdBy,
    required this.createdAt,
    required this.steps,
    this.isCurrent = false,
    this.isPublished = false,
  });

  final int version;
  final String action;
  final String note;
  final String createdBy;
  final DateTime createdAt;
  final List<dynamic> steps; // dynamic as they could be different step types but we only need code/name
  final bool isCurrent;
  final bool isPublished;
}

Future<void> showTemplateVersionDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<TemplateVersionDisplayEntry> versions,
  int? highlightVersion,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _TemplateVersionDialog(
      title: title,
      subtitle: subtitle,
      versions: versions,
      highlightVersion: highlightVersion,
    ),
  );
}

class _TemplateVersionDialog extends StatelessWidget {
  const _TemplateVersionDialog({
    required this.title,
    required this.subtitle,
    required this.versions,
    this.highlightVersion,
  });

  final String title;
  final String subtitle;
  final List<TemplateVersionDisplayEntry> versions;
  final int? highlightVersion;

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: Text(title),
      width: 860,
      content: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: versions.isEmpty
                ? const Center(child: Text('暂无历史版本记录'))
                : ListView.separated(
                    itemCount: versions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = versions[index];
                      final isHighlighted = highlightVersion != null && item.version == highlightVersion;
                      
                      return ExpansionTile(
                        initiallyExpanded: isHighlighted,
                        backgroundColor: isHighlighted ? Theme.of(context).colorScheme.primaryContainer.withAlpha(30) : null,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: item.isPublished 
                              ? Colors.green.withAlpha(40) 
                              : (item.isCurrent ? Colors.blue.withAlpha(40) : Colors.grey.withAlpha(40)),
                          child: Text(
                            'v${item.version}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.isPublished 
                                  ? Colors.green 
                                  : (item.isCurrent ? Colors.blue : Colors.grey[700]),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              isHighlighted
                                  ? '${item.action} · 目标版本'
                                  : item.action,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            if (item.isPublished) ...[
                              const SizedBox(width: 8),
                              _StatusTag(label: '已发布', color: Colors.green),
                            ],
                            if (item.isCurrent) ...[
                              const SizedBox(width: 8),
                              _StatusTag(label: '当前', color: Colors.blue),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${item.createdAt.toLocal().toString().split('.')[0]} · 操作人: ${item.createdBy}${item.note.isNotEmpty ? " · ${item.note}" : ""}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        children: [
                          if (item.steps.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('该版本无步骤数据', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                            )
                          else
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                children: item.steps.map((step) {
                                  // Generic access for both step types
                                  final stepOrder = (step as dynamic).stepOrder;
                                  final stageCode = (step as dynamic).stageCode;
                                  final stageName = (step as dynamic).stageName;
                                  final processCode = (step as dynamic).processCode;
                                  final processName = (step as dynamic).processName;

                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: Text('#$stepOrder', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    title: Text('$stageCode $stageName'),
                                    subtitle: Text('$processCode $processName'),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      );
                    },
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

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
