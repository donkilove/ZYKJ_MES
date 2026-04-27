import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductVersionTableSection extends StatelessWidget {
  const ProductVersionTableSection({
    super.key,
    required this.versions,
    required this.loading,
    required this.selectedVersionNumber,
    required this.canManageVersions,
    required this.canActivateVersions,
    required this.canExportVersionParameters,
    required this.onSelectVersion,
    required this.onShowDetail,
    required this.onActivate,
    required this.onCopy,
    required this.onEditNote,
    required this.onEditParameters,
    required this.onExport,
    required this.onDisable,
    required this.onDelete,
    required this.formatDate,
  });

  final List<ProductVersionItem> versions;
  final bool loading;
  final int? selectedVersionNumber;
  final bool canManageVersions;
  final bool canActivateVersions;
  final bool canExportVersionParameters;
  final ValueChanged<int> onSelectVersion;
  final ValueChanged<ProductVersionItem> onShowDetail;
  final ValueChanged<ProductVersionItem> onActivate;
  final ValueChanged<ProductVersionItem> onCopy;
  final ValueChanged<ProductVersionItem> onEditNote;
  final ValueChanged<ProductVersionItem> onEditParameters;
  final ValueChanged<ProductVersionItem> onExport;
  final ValueChanged<ProductVersionItem> onDisable;
  final ValueChanged<ProductVersionItem> onDelete;
  final String Function(DateTime value) formatDate;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-version-table-section'),
      child: MesSectionCard(
        title: '版本列表',
        subtitle: '版本状态、备注、来源版本和动作入口保持既有业务语义。',
        expandChild: true,
        child: loading
            ? const MesLoadingState(label: '版本加载中...')
            : versions.isEmpty
            ? const MesEmptyState(
                title: '暂无版本记录',
                description: '请先创建新版本或复制既有版本。',
              )
            : SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    columns: const [
                      DataColumn(label: Text('版本号')),
                      DataColumn(label: Text('状态')),
                      DataColumn(label: Text('变更摘要')),
                      DataColumn(label: Text('来源版本')),
                      DataColumn(label: Text('创建人')),
                      DataColumn(label: Text('创建时间')),
                      DataColumn(label: Text('生效时间')),
                      DataColumn(label: Text('操作')),
                    ],
                    rows: versions.map((version) {
                      final isDraft = version.lifecycleStatus == 'draft';
                      final isEffective = version.lifecycleStatus == 'effective';
                      final isObsolete = version.lifecycleStatus == 'obsolete';
                      return DataRow(
                        selected: selectedVersionNumber == version.version,
                        onSelectChanged: (_) => onSelectVersion(version.version),
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  version.versionLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isEffective) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: Color(0xFF1B8A5A),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(_buildStatusChip(version.lifecycleStatus)),
                          DataCell(
                            Text(
                              version.note?.trim().isNotEmpty == true
                                  ? version.note!
                                  : '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DataCell(Text(version.sourceVersionLabel ?? '-')),
                          DataCell(Text(version.createdByUsername ?? '-')),
                          DataCell(Text(formatDate(version.createdAt))),
                          DataCell(
                            Text(
                              version.effectiveAt == null
                                  ? '-'
                                  : formatDate(version.effectiveAt!),
                            ),
                          ),
                          DataCell(
                            (canManageVersions ||
                                    canActivateVersions ||
                                    canExportVersionParameters)
                                ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18),
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'detail':
                                          onShowDetail(version);
                                          return;
                                        case 'activate':
                                          onActivate(version);
                                          return;
                                        case 'copy':
                                          onCopy(version);
                                          return;
                                        case 'editNote':
                                          onEditNote(version);
                                          return;
                                        case 'editParams':
                                          onEditParameters(version);
                                          return;
                                        case 'export':
                                          onExport(version);
                                          return;
                                        case 'disable':
                                          onDisable(version);
                                          return;
                                        case 'delete':
                                          onDelete(version);
                                          return;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'detail',
                                        child: Text('查看详情'),
                                      ),
                                      if (canActivateVersions && isDraft)
                                        const PopupMenuItem(
                                          value: 'activate',
                                          child: Text('立即生效'),
                                        ),
                                      if (canManageVersions &&
                                          (isDraft ||
                                              isEffective ||
                                              isObsolete ||
                                              version.lifecycleStatus == 'disabled'))
                                        const PopupMenuItem(
                                          value: 'copy',
                                          child: Text('复制版本'),
                                        ),
                                      if (canManageVersions)
                                        const PopupMenuItem(
                                          value: 'editNote',
                                          child: Text('编辑版本说明'),
                                        ),
                                      PopupMenuItem(
                                        value: 'editParams',
                                        child: Text(isDraft ? '维护参数' : '查看参数'),
                                      ),
                                      if (canExportVersionParameters)
                                        const PopupMenuItem(
                                          value: 'export',
                                          child: Text('导出版本参数'),
                                        ),
                                      if (canManageVersions &&
                                          (isEffective || isObsolete))
                                        const PopupMenuItem(
                                          value: 'disable',
                                          child: Text('停用版本'),
                                        ),
                                      if (canManageVersions && isDraft)
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            '删除版本',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    switch (status) {
      case 'effective':
        return MesStatusChip.success(label: '已生效');
      case 'draft':
        return MesStatusChip.warning(label: '草稿');
      case 'obsolete':
      case 'inactive':
        return MesStatusChip.warning(label: '已失效');
      case 'disabled':
        return MesStatusChip.warning(label: '已停用');
      default:
        return MesStatusChip.warning(label: status);
    }
  }
}
