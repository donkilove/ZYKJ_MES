import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class QualitySupplierManagementPageHeader extends StatelessWidget {
  const QualitySupplierManagementPageHeader({
    super.key,
    required this.loading,
    required this.keywordController,
    required this.enabledFilter,
    required this.onKeywordSubmitted,
    required this.onEnabledChanged,
    required this.onSearch,
    required this.onRefresh,
    required this.onCreate,
  });

  final bool loading;
  final TextEditingController keywordController;
  final bool? enabledFilter;
  final ValueChanged<String> onKeywordSubmitted;
  final ValueChanged<bool?> onEnabledChanged;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('quality-supplier-management-page-header'),
      child: MesRefreshPageHeader(
        leading: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                key: const ValueKey('quality-supplier-keyword-field'),
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索供应商名称',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: onKeywordSubmitted,
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<bool?>(
                initialValue: enabledFilter,
                decoration: const InputDecoration(
                  labelText: '状态筛选',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem<bool?>(value: null, child: Text('全部')),
                  DropdownMenuItem<bool?>(value: true, child: Text('启用')),
                  DropdownMenuItem<bool?>(value: false, child: Text('停用')),
                ],
                onChanged: loading ? null : onEnabledChanged,
              ),
            ),
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('查询'),
            ),
          ],
        ),
        onRefresh: loading ? null : onRefresh,
        actionsBeforeRefresh: [
          PopupMenuButton<String>(
            key: const ValueKey('quality-supplier-operation-menu'),
            tooltip: '操作',
            onSelected: loading
                ? null
                : (value) {
                    if (value == 'create_supplier') {
                      onCreate();
                    }
                  },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'create_supplier',
                child: Text('新增供应商'),
              ),
            ],
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
    );
  }
}
