import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class ProductParameterQueryFilterSection extends StatelessWidget {
  const ProductParameterQueryFilterSection({
    super.key,
    required this.keywordController,
    required this.categoryOptions,
    required this.selectedCategory,
    required this.loading,
    required this.canExportParameters,
    required this.onCategoryChanged,
    required this.onSearch,
    required this.onExport,
  });

  final TextEditingController keywordController;
  final List<String> categoryOptions;
  final String selectedCategory;
  final bool loading;
  final bool canExportParameters;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onSearch;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-query-filter-section'),
      child: MesFilterBar(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索产品名称',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: '分类筛选',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('全部'),
                  ),
                  ...categoryOptions.map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: loading
                    ? null
                    : (value) => onCategoryChanged(value ?? ''),
              ),
            ),
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('搜索'),
            ),
            OutlinedButton.icon(
              onPressed: loading || !canExportParameters ? null : onExport,
              icon: const Icon(Icons.download),
              label: const Text('导出'),
            ),
          ],
        ),
      ),
    );
  }
}
