import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_history_timeline.dart';
import 'package:mes_client/features/product/presentation/widgets/product_related_info_section.dart';

class ProductDetailDrawer extends StatelessWidget {
  const ProductDetailDrawer({
    super.key,
    required this.detail,
    required this.paramSearch,
    required this.onParamSearchChanged,
    required this.onClose,
    required this.formatTime,
    required this.lifecycleLabel,
    required this.versionLifecycleLabel,
    required this.formatDisplayVersion,
    required this.changeTypeLabel,
  });

  final ProductDetailResult detail;
  final String paramSearch;
  final ValueChanged<String> onParamSearchChanged;
  final VoidCallback onClose;
  final String Function(DateTime value) formatTime;
  final String Function(String value) lifecycleLabel;
  final String Function(String value) versionLifecycleLabel;
  final String Function(int value) formatDisplayVersion;
  final String Function(String value) changeTypeLabel;

  @override
  Widget build(BuildContext context) {
    final product = detail.product;
    final currentVersion = product.currentVersion > 0
        ? formatDisplayVersion(product.currentVersion)
        : '-';
    final effectiveVersion = product.effectiveVersion > 0
        ? formatDisplayVersion(product.effectiveVersion)
        : '无';
    final filteredParams = detail.detailParameters.items.where((item) {
      if (paramSearch.trim().isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(paramSearch.toLowerCase());
    }).toList();

    return KeyedSubtree(
      key: const ValueKey('product-detail-drawer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '产品详情 - ${product.name}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '页内侧边栏展示完整详情快照',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '基本信息',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  _detailRow('产品名称', product.name),
                  _detailRow('产品分类', product.category.isEmpty ? '-' : product.category),
                  _detailRow('状态', lifecycleLabel(product.lifecycleStatus)),
                  _detailRow('当前版本', currentVersion),
                  _detailRow('生效版本', effectiveVersion),
                  _detailRow('备注', product.remark.isEmpty ? '-' : product.remark),
                  _detailRow('创建时间', formatTime(product.createdAt)),
                  _detailRow('更新时间', formatTime(product.updatedAt)),
                  const SizedBox(height: 16),
                  Text(
                    '${detail.detailParameters.parameterScope == 'effective' ? '当前生效参数快照' : '当前版本参数快照'}（${detail.detailParameters.versionLabel}）',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  if ((detail.detailParameterMessage ?? '').isNotEmpty) ...[
                    Text(detail.detailParameterMessage!),
                    const SizedBox(height: 8),
                  ],
                  if (detail.detailParameters.items.isEmpty)
                    const Text('暂无参数', style: TextStyle(color: Colors.grey))
                  else ...[
                    SizedBox(
                      width: 240,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: '搜索参数名称',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: onParamSearchChanged,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowHeight: 36,
                        dataRowMinHeight: 32,
                        dataRowMaxHeight: 40,
                        columns: const [
                          DataColumn(label: Text('参数名')),
                          DataColumn(label: Text('分组')),
                          DataColumn(label: Text('类型')),
                          DataColumn(label: Text('值')),
                          DataColumn(label: Text('说明')),
                        ],
                        rows: filteredParams.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.name)),
                              DataCell(Text(item.category)),
                              DataCell(Text(item.type)),
                              DataCell(
                                Text(
                                  item.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.description.isEmpty ? '-' : item.description,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '关联信息',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  if (detail.relatedInfoSections.isEmpty)
                    const Text('暂无关联信息', style: TextStyle(color: Colors.grey))
                  else
                    ...detail.relatedInfoSections.map(
                      (section) => ProductRelatedInfoSectionCard(section: section),
                    ),
                  const SizedBox(height: 16),
                  ProductHistoryTimeline(
                    items: detail.historyItems,
                    formatTime: formatTime,
                    changeTypeLabel: changeTypeLabel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
