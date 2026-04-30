import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

Future<void> showProcessReferenceDialog({
  required BuildContext context,
  required String title,
  required Future<List<RefEntry>> Function() loader,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ProcessReferenceDialog(title: title, loader: loader),
  );
}

class ProcessReferenceDialog extends StatefulWidget {
  const ProcessReferenceDialog({
    super.key,
    required this.title,
    required this.loader,
  });

  final String title;
  final Future<List<RefEntry>> Function() loader;

  @override
  State<ProcessReferenceDialog> createState() => _ProcessReferenceDialogState();
}

class _ProcessReferenceDialogState extends State<ProcessReferenceDialog> {
  bool _loading = true;
  String _error = '';
  List<RefEntry> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _refTypeLabel(String type) => switch (type) {
    'process' => '工序',
    'user' => '用户',
    'template' => '工艺模板',
    'system_master_template' => '系统母版',
    'order' => '生产工单',
    _ => type,
  };

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: Text(widget.title),
      width: 480,
      content: SizedBox(
        key: const ValueKey('process-reference-dialog'),
        height: 360,
        child: _loading
            ? const MesLoadingState(label: '引用记录加载中...')
            : _error.isNotEmpty
            ? Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            : _items.isEmpty
            ? const Center(child: Text('无引用记录，可安全删除'))
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    dense: true,
                    leading: Chip(
                      label: Text(
                        _refTypeLabel(item.refType),
                        style: const TextStyle(fontSize: 11),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    title: Text(item.refName),
                    subtitle: Text(
                      [
                        '编码/编号：${item.refId}',
                        if (item.detail != null && item.detail!.trim().isNotEmpty)
                          item.detail!,
                      ].join('\n'),
                    ),
                    trailing: Text(
                      item.refId,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
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
