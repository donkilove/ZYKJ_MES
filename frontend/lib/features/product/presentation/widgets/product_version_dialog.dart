import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_compare_panel.dart';

class ProductVersionDialog extends StatelessWidget {
  const ProductVersionDialog({
    super.key,
    required this.product,
    required this.versions,
    required this.loadingVersions,
    required this.operationLoading,
    required this.compareLoading,
    required this.compareResult,
    required this.fromVersion,
    required this.toVersion,
    required this.operationLabel,
    required this.canCompareVersions,
    required this.canManageVersions,
    required this.canActivateVersions,
    required this.canEditParameters,
    required this.canRollbackVersion,
    required this.onClose,
    required this.onCreateVersion,
    required this.onFromVersionChanged,
    required this.onToVersionChanged,
    required this.onCompare,
    required this.buildVersionActions,
    required this.lifecycleLabel,
    required this.formatTime,
  });

  final ProductItem product;
  final List<ProductVersionItem> versions;
  final bool loadingVersions;
  final bool operationLoading;
  final bool compareLoading;
  final ProductVersionCompareResult? compareResult;
  final int? fromVersion;
  final int? toVersion;
  final String? operationLabel;
  final bool canCompareVersions;
  final bool canManageVersions;
  final bool canActivateVersions;
  final bool canEditParameters;
  final bool canRollbackVersion;
  final VoidCallback onClose;
  final VoidCallback onCreateVersion;
  final ValueChanged<int?> onFromVersionChanged;
  final ValueChanged<int?> onToVersionChanged;
  final VoidCallback onCompare;
  final List<Widget> Function(ProductVersionItem item) buildVersionActions;
  final String Function(String value) lifecycleLabel;
  final String Function(DateTime value) formatTime;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-version-dialog'),
      child: AlertDialog(
        title: Text('版本管理 - ${product.name}'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: operationLoading || loadingVersions
                          ? null
                          : onCreateVersion,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('新建版本'),
                    ),
                  ],
                ),
                if (loadingVersions || operationLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  if (operationLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(operationLabel!),
                  ],
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<int>(
                      value: fromVersion,
                      hint: const Text('起始版本'),
                      items: versions
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.version,
                              child: Text(item.displayVersion),
                            ),
                          )
                          .toList(),
                      onChanged: loadingVersions || operationLoading
                          ? null
                          : onFromVersionChanged,
                    ),
                    DropdownButton<int>(
                      value: toVersion,
                      hint: const Text('目标版本'),
                      items: versions
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.version,
                              child: Text(item.displayVersion),
                            ),
                          )
                          .toList(),
                      onChanged: loadingVersions || operationLoading
                          ? null
                          : onToVersionChanged,
                    ),
                    FilledButton(
                      onPressed: loadingVersions ||
                              operationLoading ||
                              compareLoading ||
                              !canCompareVersions ||
                              fromVersion == null ||
                              toVersion == null
                          ? null
                          : onCompare,
                      child: const Text('版本对比'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (compareResult != null)
                  ProductVersionComparePanel(result: compareResult!),
                const Text('版本列表'),
                const SizedBox(height: 8),
                if (!loadingVersions && versions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('暂无版本记录'),
                  )
                else
                  ...versions.map(
                    (item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.displayVersion} / ${lifecycleLabel(item.lifecycleStatus)}',
                      ),
                      subtitle: Text(
                        [
                          formatTime(item.createdAt),
                          item.createdByUsername ?? '-',
                          if (item.note != null && item.note!.isNotEmpty)
                            item.note!,
                        ].join('  '),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: buildVersionActions(item),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: operationLoading ? null : onClose,
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
