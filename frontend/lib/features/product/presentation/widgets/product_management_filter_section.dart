import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class ProductManagementFilterSection extends StatelessWidget {
  const ProductManagementFilterSection({
    super.key,
    required this.keywordController,
    required this.categoryOptions,
    required this.selectedCategory,
    required this.selectedStatus,
    required this.selectedEffectiveVersion,
    required this.loading,
    required this.canCreateProduct,
    required this.canExportProducts,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onEffectiveVersionChanged,
    required this.onSearch,
    required this.onCreate,
    required this.onExport,
  });

  final TextEditingController keywordController;
  final List<String> categoryOptions;
  final String selectedCategory;
  final String selectedStatus;
  final String selectedEffectiveVersion;
  final bool loading;
  final bool canCreateProduct;
  final bool canExportProducts;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onEffectiveVersionChanged;
  final VoidCallback onSearch;
  final VoidCallback onCreate;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-management-filter-section'),
      child: MesFilterBar(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
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
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: '分类筛选',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('全部')),
                  ...categoryOptions.map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: loading ? null : (value) => onCategoryChanged(value ?? ''),
              ),
            ),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: '状态筛选',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(value: '', child: Text('全部')),
                  DropdownMenuItem<String>(value: 'active', child: Text('启用')),
                  DropdownMenuItem<String>(value: 'inactive', child: Text('停用')),
                ],
                onChanged: loading ? null : (value) => onStatusChanged(value ?? ''),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: selectedEffectiveVersion,
                decoration: const InputDecoration(
                  labelText: '生效版本',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(value: '', child: Text('全部')),
                  DropdownMenuItem<String>(value: 'yes', child: Text('有生效版本')),
                  DropdownMenuItem<String>(value: 'no', child: Text('无生效版本')),
                ],
                onChanged: loading
                    ? null
                    : (value) => onEffectiveVersionChanged(value ?? ''),
              ),
            ),
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('搜索产品'),
            ),
            FilledButton.icon(
              onPressed: loading || !canCreateProduct ? null : onCreate,
              icon: const Icon(Icons.add),
              label: const Text('添加产品'),
            ),
            OutlinedButton.icon(
              onPressed: loading || !canExportProducts ? null : onExport,
              icon: const Icon(Icons.download),
              label: const Text('导出产品'),
            ),
          ],
        ),
      ),
    );
  }
}
