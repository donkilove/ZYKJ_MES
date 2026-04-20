import 'package:flutter/material.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_row_model.dart';

class ProductParameterEditorTable extends StatelessWidget {
  const ProductParameterEditorTable({
    super.key,
    this.rows = const [],
    this.visibleRows = const [],
    this.editorReadOnly = false,
    this.editorSubmitting = false,
    this.onTypeChanged,
    this.onValueChanged,
    this.onDescriptionChanged,
    this.onCategoryChanged,
    this.onDeleteRow,
    this.onReorder,
    this.child,
  });

  final List<ProductParameterEditorRowModel> rows;
  final List<ProductParameterEditorRowModel> visibleRows;
  final bool editorReadOnly;
  final bool editorSubmitting;
  final void Function(ProductParameterEditorRowModel row, String value)?
  onTypeChanged;
  final void Function(ProductParameterEditorRowModel row, String value)?
  onValueChanged;
  final void Function(ProductParameterEditorRowModel row)? onDescriptionChanged;
  final void Function(ProductParameterEditorRowModel row)? onCategoryChanged;
  final void Function(ProductParameterEditorRowModel row)? onDeleteRow;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child != null) {
      return KeyedSubtree(
        key: const ValueKey('product-parameter-editor-table'),
        child: child!,
      );
    }

    return KeyedSubtree(
      key: const ValueKey('product-parameter-editor-table'),
      child: ListView.builder(
        itemCount: visibleRows.length,
        itemBuilder: (context, index) {
          final row = visibleRows[index];
          return Card(
            key: ValueKey(row.rowId),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.nameController,
                      readOnly: editorReadOnly,
                      decoration: const InputDecoration(
                        labelText: '参数名',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.categoryController,
                      readOnly: editorReadOnly,
                      onChanged: editorReadOnly
                          ? null
                          : (_) => onCategoryChanged?.call(row),
                      decoration: const InputDecoration(
                        labelText: '分组',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: row.parameterType,
                      decoration: const InputDecoration(
                        labelText: '类型',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem<String>(value: 'Text', child: Text('Text')),
                        DropdownMenuItem<String>(value: 'Link', child: Text('Link')),
                      ],
                      onChanged: editorReadOnly || editorSubmitting
                          ? null
                          : (value) => onTypeChanged?.call(row, value ?? 'Text'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.valueController,
                      readOnly: editorReadOnly,
                      onChanged: editorReadOnly
                          ? null
                          : (value) => onValueChanged?.call(row, value),
                      decoration: const InputDecoration(
                        labelText: '值',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.descriptionController,
                      readOnly: editorReadOnly,
                      onChanged: editorReadOnly
                          ? null
                          : (_) => onDescriptionChanged?.call(row),
                      decoration: const InputDecoration(
                        labelText: '说明',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '删除',
                    onPressed: editorSubmitting || editorReadOnly
                        ? null
                        : () => onDeleteRow?.call(row),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
