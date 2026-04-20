import 'package:flutter/material.dart';

class ProductParameterEditorToolbar extends StatelessWidget {
  const ProductParameterEditorToolbar({
    super.key,
    required this.groupFilter,
    required this.categorySuggestions,
    required this.hasUnsavedChanges,
    required this.onGroupChanged,
    required this.onRefresh,
    required this.refreshEnabled,
  });

  final String groupFilter;
  final List<String> categorySuggestions;
  final bool hasUnsavedChanges;
  final ValueChanged<String> onGroupChanged;
  final VoidCallback onRefresh;
  final bool refreshEnabled;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-editor-toolbar'),
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: 180,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '参数分组筛选',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: groupFilter,
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('全部分组')),
                    ...categorySuggestions.map(
                      (item) =>
                          DropdownMenuItem<String>(value: item, child: Text(item)),
                    ),
                  ],
                  onChanged: (value) => onGroupChanged(value ?? ''),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '刷新参数',
            onPressed: refreshEnabled ? onRefresh : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
