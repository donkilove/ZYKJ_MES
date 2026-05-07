import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/features/product/presentation/product_category_options.dart';

class ProductParameterManagementPageHeader extends StatelessWidget {
  const ProductParameterManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
    required this.keywordController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onSearch,
  });

  final bool loading;
  final VoidCallback onRefresh;
  final TextEditingController keywordController;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-management-page-header'),
      child: MesRefreshPageHeader(
        onRefresh: loading ? null : onRefresh,
        leading: KeyedSubtree(
          key: const ValueKey('product-parameter-filter-section'),
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
                    const DropdownMenuItem<String>(value: '', child: Text('全部')),
                    ...productCategoryOptions.map(
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
            ],
          ),
        ),
      ),
    );
  }
}
