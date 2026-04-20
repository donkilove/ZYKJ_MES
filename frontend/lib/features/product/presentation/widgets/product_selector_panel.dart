import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductSelectorPanel extends StatelessWidget {
  const ProductSelectorPanel({
    super.key,
    required this.searchController,
    required this.loading,
    required this.products,
    required this.selectedProductId,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onSearchSubmitted,
    required this.onRefresh,
    required this.onSelectProduct,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final TextEditingController searchController;
  final bool loading;
  final List<ProductItem> products;
  final int? selectedProductId;
  final int page;
  final int totalPages;
  final int total;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onRefresh;
  final ValueChanged<ProductItem> onSelectProduct;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-selector-panel'),
      child: MesSectionCard(
        title: '产品列表',
        subtitle: '先定位产品，再进入右侧版本工作区。',
        expandChild: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: '搜索产品名称',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: onSearchSubmitted,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (loading)
              const LinearProgressIndicator()
            else if (products.isEmpty)
              const Expanded(
                child: MesEmptyState(
                  title: '暂无产品',
                  description: '可尝试修改关键词后重新查询。',
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final selected = product.id == selectedProductId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        selected: selected,
                        title: Text(
                          product.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          product.category.isEmpty ? '无分类' : product.category,
                        ),
                        trailing: product.lifecycleStatus == 'inactive'
                            ? MesStatusChip.warning(label: '停用')
                            : null,
                        onTap: () => onSelectProduct(product),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            MesPaginationBar(
              page: page,
              totalPages: totalPages,
              total: total,
              loading: loading,
              onPrevious: onPreviousPage,
              onNext: onNextPage,
            ),
          ],
        ),
      ),
    );
  }
}
