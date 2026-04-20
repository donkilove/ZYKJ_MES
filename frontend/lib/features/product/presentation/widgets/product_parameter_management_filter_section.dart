import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class ProductParameterManagementFilterSection extends StatelessWidget {
  const ProductParameterManagementFilterSection({
    super.key,
    required this.keywordController,
    required this.selectedCategory,
    required this.loading,
    required this.onCategoryChanged,
    required this.onSearch,
  });

  final TextEditingController keywordController;
  final String selectedCategory;
  final bool loading;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-filter-section'),
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
                items: const [
                  DropdownMenuItem<String>(value: '', child: Text('全部')),
                  DropdownMenuItem<String>(value: '贴片', child: Text('贴片')),
                  DropdownMenuItem<String>(value: 'DTU', child: Text('DTU')),
                  DropdownMenuItem<String>(value: '套件', child: Text('套件')),
                ],
                onChanged: loading ? null : (value) => onCategoryChanged(value ?? ''),
              ),
            ),
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('搜索'),
            ),
          ],
        ),
      ),
    );
  }
}
