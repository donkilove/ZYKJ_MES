import 'package:flutter/material.dart';

class ProductParameterEditorFooter extends StatelessWidget {
  const ProductParameterEditorFooter({
    super.key,
    required this.remarkController,
    required this.editorReadOnly,
    required this.editorSubmitting,
    required this.onAddRow,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController remarkController;
  final bool editorReadOnly;
  final bool editorSubmitting;
  final VoidCallback onAddRow;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-editor-footer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: editorSubmitting || editorReadOnly ? null : onAddRow,
              icon: const Icon(Icons.add),
              label: const Text('新增参数'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: remarkController,
            maxLines: 2,
            readOnly: editorReadOnly,
            decoration: const InputDecoration(
              labelText: '本次修改备注（必填）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: editorSubmitting ? null : onCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: editorSubmitting || editorReadOnly ? null : onSave,
                child: editorSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存参数'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
