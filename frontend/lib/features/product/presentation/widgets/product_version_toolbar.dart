import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductVersionToolbar extends StatelessWidget {
  const ProductVersionToolbar({
    super.key,
    required this.product,
    required this.selectedVersion,
    required this.hasDraft,
    required this.canManageVersions,
    required this.canActivateVersions,
    required this.canExportVersionParameters,
    required this.onCreateVersion,
    required this.onCopyVersion,
    required this.onEditVersionNote,
    required this.onExportParameters,
    required this.onActivateVersion,
  });

  final ProductItem? product;
  final ProductVersionItem? selectedVersion;
  final bool hasDraft;
  final bool canManageVersions;
  final bool canActivateVersions;
  final bool canExportVersionParameters;
  final VoidCallback onCreateVersion;
  final VoidCallback onCopyVersion;
  final VoidCallback onEditVersionNote;
  final VoidCallback onExportParameters;
  final VoidCallback onActivateVersion;

  @override
  Widget build(BuildContext context) {
    final selected = selectedVersion;
    final hasProduct = product != null;
    final productTitle = product?.name ?? '请先选择产品';
    final subtitle = selected == null
        ? '当前未选中版本'
        : '当前选中：${selected.versionLabel} / ${_statusLabel(selected.lifecycleStatus)}';

    return KeyedSubtree(
      key: const ValueKey('product-version-toolbar'),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                productTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (canManageVersions)
                    OutlinedButton.icon(
                      onPressed: !hasProduct || hasDraft ? null : onCreateVersion,
                      icon: const Icon(Icons.add),
                      label: const Text('新建版本'),
                    ),
                  if (canManageVersions)
                    OutlinedButton.icon(
                      onPressed: selected == null ? null : onCopyVersion,
                      icon: const Icon(Icons.copy),
                      label: const Text('复制版本'),
                    ),
                  if (canManageVersions)
                    OutlinedButton.icon(
                      onPressed: selected == null ? null : onEditVersionNote,
                      icon: const Icon(Icons.edit_note),
                      label: const Text('编辑版本说明'),
                    ),
                  if (canExportVersionParameters)
                    OutlinedButton.icon(
                      onPressed: selected == null ? null : onExportParameters,
                      icon: const Icon(Icons.download),
                      label: const Text('导出参数'),
                    ),
                  if (canActivateVersions)
                    FilledButton.icon(
                      onPressed:
                          selected == null ||
                              selected.lifecycleStatus != 'draft'
                          ? null
                          : onActivateVersion,
                      icon: const Icon(Icons.task_alt),
                      label: const Text('立即生效'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'draft':
      return '草稿';
    case 'effective':
      return '已生效';
    case 'obsolete':
    case 'inactive':
      return '已失效';
    case 'disabled':
      return '已停用';
    default:
      return status;
  }
}
