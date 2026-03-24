import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/product_models.dart';
import '../services/api_exception.dart';
import '../services/product_service.dart';
import '../widgets/crud_page_header.dart';

const Map<String, String> _statusLabels = {
  'draft': '草稿',
  'effective': '已生效',
  'obsolete': '已失效',
  'disabled': '已停用',
  'inactive': '已失效',
};

const Map<String, Color> _statusColors = {
  'draft': Colors.blue,
  'effective': Colors.green,
  'obsolete': Colors.orange,
  'disabled': Colors.grey,
  'inactive': Colors.orange,
};

class ProductVersionManagementPage extends StatefulWidget {
  const ProductVersionManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.tabCode,
    this.jumpCommand,
    this.onJumpHandled,
    this.onEditVersionParameters,
    required this.canManageVersions,
    this.canActivateVersions = false,
    this.canExportVersionParameters = false,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String tabCode;
  final ProductJumpCommand? jumpCommand;
  final void Function(int seq)? onJumpHandled;
  final void Function(ProductItem product, ProductVersionItem version)?
  onEditVersionParameters;
  final bool canManageVersions;
  final bool canActivateVersions;
  final bool canExportVersionParameters;
  final ProductService? service;

  @override
  State<ProductVersionManagementPage> createState() =>
      _ProductVersionManagementPageState();
}

class _ProductVersionManagementPageState
    extends State<ProductVersionManagementPage> {
  late final ProductService _service;

  List<ProductItem> _products = [];
  int _productTotal = 0;
  int _productPage = 1;
  static const int _productPageSize = 50;
  bool _loadingProducts = false;
  String _productKeyword = '';
  final TextEditingController _searchController = TextEditingController();

  ProductItem? _selectedProduct;
  List<ProductVersionItem> _versions = [];
  bool _loadingVersions = false;
  int? _selectedVersionNumber;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductService(widget.session);
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProductVersionManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cmd = widget.jumpCommand;
    if (cmd != null &&
        cmd.targetTabCode == widget.tabCode &&
        cmd.seq != oldWidget.jumpCommand?.seq) {
      _handleJump(cmd);
    }
  }

  void _handleJump(ProductJumpCommand cmd) {
    widget.onJumpHandled?.call(cmd.seq);
    _selectProductById(cmd.productId);
  }

  Future<void> _selectProductById(int productId) async {
    try {
      final product = await _service.getProduct(productId: productId);
      setState(() {
        _selectedProduct = product;
      });
      await _loadVersions(product);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final result = await _service.listProducts(
        page: _productPage,
        pageSize: _productPageSize,
        keyword: _productKeyword.isEmpty ? null : _productKeyword,
      );
      setState(() {
        _products = result.items;
        _productTotal = result.total;
      });
    } catch (e) {
      if (mounted) _showError('加载产品列表失败: $e');
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _loadVersions(
    ProductItem product, {
    int? preferredVersionNumber,
  }) async {
    setState(() {
      _selectedProduct = product;
      _loadingVersions = true;
      _versions = [];
      _selectedVersionNumber = null;
    });
    try {
      final result = await _service.listProductVersions(productId: product.id);
      setState(() {
        _versions = result.items;
        int? matchedVersionNumber;
        if (preferredVersionNumber != null) {
          for (final item in result.items) {
            if (item.version == preferredVersionNumber) {
              matchedVersionNumber = item.version;
              break;
            }
          }
        }
        _selectedVersionNumber =
            matchedVersionNumber ??
            (result.items.isEmpty ? null : result.items.first.version);
      });
    } catch (e) {
      if (mounted) _showError('加载版本列表失败: $e');
    } finally {
      if (mounted) setState(() => _loadingVersions = false);
    }
  }

  ProductVersionItem? get _selectedVersion {
    final selectedVersionNumber = _selectedVersionNumber;
    if (selectedVersionNumber == null) {
      return null;
    }
    for (final item in _versions) {
      if (item.version == selectedVersionNumber) {
        return item;
      }
    }
    return _versions.isEmpty ? null : _versions.first;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Future<void> _createVersion() async {
    final product = _selectedProduct;
    if (product == null) return;
    try {
      await _service.createProductVersion(productId: product.id);
      _showSuccess('新建版本成功');
      await _reloadSelectedProductAndVersions(product.id);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('新建版本失败: $e');
    }
  }

  Future<void> _copyVersion(ProductVersionItem source) async {
    final product = _selectedProduct;
    if (product == null) return;
    try {
      await _service.copyProductVersion(
        productId: product.id,
        sourceVersion: source.version,
      );
      _showSuccess('复制版本成功（来源：${source.versionLabel}）');
      await _reloadSelectedProductAndVersions(product.id);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('复制版本失败: $e');
    }
  }

  Future<void> _activateVersion(ProductVersionItem rev) async {
    final product = _selectedProduct;
    if (product == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认生效'),
        content: Text('确认将版本 ${rev.versionLabel} 设为生效版本？\n生效后，当前生效版本将自动变为已失效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认生效'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.activateProductVersion(
        productId: product.id,
        version: rev.version,
        confirmed: true,
        expectedEffectiveVersion: product.effectiveVersion,
      );
      await _reloadSelectedProductAndVersions(product.id);
      _showSuccess('版本 ${rev.versionLabel} 已生效');
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('生效失败: $e');
    }
  }

  Future<void> _disableVersion(ProductVersionItem rev) async {
    final product = _selectedProduct;
    if (product == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认停用'),
        content: Text('确认停用版本 ${rev.versionLabel}？停用后不可直接恢复，如需再次使用请复制出新草稿。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认停用'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.disableProductVersion(
        productId: product.id,
        version: rev.version,
      );
      final refreshedProduct = await _reloadSelectedProductAndVersions(
        product.id,
      );
      _showSuccess(
        refreshedProduct != null &&
                refreshedProduct.lifecycleStatus == 'inactive'
            ? '版本 ${rev.versionLabel} 已停用，产品因无生效版本已同步停用'
            : '版本 ${rev.versionLabel} 已停用',
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('停用失败: $e');
    }
  }

  Future<void> _deleteVersion(ProductVersionItem rev) async {
    final product = _selectedProduct;
    if (product == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确认删除草稿版本 ${rev.versionLabel}？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteProductVersion(
        productId: product.id,
        version: rev.version,
      );
      _showSuccess('版本 ${rev.versionLabel} 已删除');
      await _reloadSelectedProductAndVersions(product.id);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('删除失败: $e');
    }
  }

  Future<void> _showVersionDetail(ProductVersionItem rev) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('版本详情 - ${rev.versionLabel}'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('版本号', rev.versionLabel),
                _detailRow(
                  '状态',
                  _statusLabels[rev.lifecycleStatus] ?? rev.lifecycleStatus,
                ),
                _detailRow('变更摘要', rev.note ?? '-'),
                _detailRow('来源版本', rev.sourceVersionLabel ?? '-'),
                _detailRow('创建人', rev.createdByUsername ?? '-'),
                _detailRow('创建时间', _formatDate(rev.createdAt)),
                if (rev.updatedAt != null)
                  _detailRow('最后更新', _formatDate(rev.updatedAt!)),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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

  Future<void> _editVersionNote(ProductVersionItem rev) async {
    final product = _selectedProduct;
    if (product == null) return;
    final controller = TextEditingController(text: rev.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑备注 - ${rev.versionLabel}'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLength: 256,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '版本备注',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      await _service.updateProductVersionNote(
        productId: product.id,
        version: rev.version,
        note: result,
      );
      _showSuccess('备注已更新');
      await _loadVersions(product);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('更新备注失败: $e');
    }
  }

  void _navigateToEditParams(ProductVersionItem rev) {
    final product = _selectedProduct;
    if (product == null) return;
    widget.onEditVersionParameters?.call(product, rev);
  }

  Future<ProductItem?> _reloadSelectedProductAndVersions(int productId) async {
    try {
      final product = await _service.getProduct(productId: productId);
      if (!mounted) return null;
      await _loadVersions(
        product,
        preferredVersionNumber: _selectedVersionNumber,
      );
      return product;
    } catch (e) {
      if (mounted) {
        _showError('刷新产品状态失败: $e');
      }
      return null;
    }
  }

  Future<void> _refreshPage() async {
    final selectedProductId = _selectedProduct?.id;
    await _loadProducts();
    if (!mounted || selectedProductId == null) {
      return;
    }
    await _reloadSelectedProductAndVersions(selectedProductId);
  }

  Future<void> _exportVersionParams(ProductVersionItem rev) async {
    final product = _selectedProduct;
    if (product == null) return;
    try {
      final bytes = await _service.exportProductVersionParameters(
        productId: product.id,
        version: rev.version,
      );
      final fileName = '${product.name}_${rev.versionLabel}_参数.csv';
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null) return;
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/csv',
        name: fileName,
      );
      await file.saveTo(location.path);
      _showSuccess('导出成功');
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('导出失败: $e');
    }
  }

  Widget _buildProductList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '搜索产品名称',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) {
                    _productKeyword = v.trim();
                    _productPage = 1;
                    _loadProducts();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadProducts,
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        if (_loadingProducts)
          const LinearProgressIndicator()
        else
          Expanded(
            child: _products.isEmpty
                ? const Center(child: Text('暂无产品'))
                : ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      final p = _products[i];
                      final selected = _selectedProduct?.id == p.id;
                      return ListTile(
                        selected: selected,
                        selectedTileColor: Theme.of(
                          ctx,
                        ).colorScheme.primaryContainer,
                        title: Text(p.name, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          p.category.isEmpty ? '无分类' : p.category,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: p.lifecycleStatus == 'inactive'
                            ? const Chip(
                                label: Text(
                                  '停用',
                                  style: TextStyle(fontSize: 11),
                                ),
                                padding: EdgeInsets.zero,
                              )
                            : null,
                        onTap: () => _loadVersions(p),
                      );
                    },
                  ),
          ),
        if (_productTotal > _productPageSize)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _productPage > 1
                    ? () {
                        _productPage--;
                        _loadProducts();
                      }
                    : null,
              ),
              Text(
                '$_productPage / ${(_productTotal / _productPageSize).ceil()}',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _productPage * _productPageSize < _productTotal
                    ? () {
                        _productPage++;
                        _loadProducts();
                      }
                    : null,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildVersionList() {
    final product = _selectedProduct;
    if (product == null) {
      return const Center(child: Text('请在左侧选择产品'));
    }

    final hasDraft = _versions.any((v) => v.lifecycleStatus == 'draft');
    final selectedVersion = _selectedVersion;
    ProductVersionItem? effectiveRevision;
    for (final version in _versions) {
      if (version.lifecycleStatus == 'effective') {
        effectiveRevision = version;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selectedVersion != null)
                Expanded(
                  flex: 2,
                  child: Text(
                    '当前选中：${selectedVersion.versionLabel} / ${_statusLabels[selectedVersion.lifecycleStatus] ?? selectedVersion.lifecycleStatus}',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(width: 8),
              if (widget.canManageVersions) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新建版本'),
                  onPressed: hasDraft ? null : _createVersion,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制版本'),
                  onPressed: selectedVersion == null
                      ? null
                      : () => _copyVersion(selectedVersion),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('编辑版本说明'),
                  onPressed: selectedVersion == null
                      ? null
                      : () => _editVersionNote(selectedVersion),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.canExportVersionParameters)
                OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('导出参数'),
                  onPressed: selectedVersion == null
                      ? null
                      : () => _exportVersionParams(selectedVersion),
                ),
              if (widget.canActivateVersions) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.task_alt, size: 16),
                  label: const Text('立即生效'),
                  onPressed:
                      selectedVersion == null ||
                          selectedVersion.lifecycleStatus != 'draft'
                      ? null
                      : () => _activateVersion(selectedVersion),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadVersions(product),
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        if (hasDraft)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '已存在草稿版本，请先完成或删除当前草稿后再新建版本',
              style: TextStyle(color: Colors.orange[700], fontSize: 12),
            ),
          ),
        if (effectiveRevision != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '最近一次生效结果：${effectiveRevision.versionLabel} 已生效'
                        '${effectiveRevision.effectiveAt != null ? '（${_formatDate(effectiveRevision.effectiveAt!)}）' : ''}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (effectiveRevision == null && product.lifecycleStatus == 'inactive')
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Card(
              color: Colors.orange.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product.inactiveReason?.isNotEmpty == true
                            ? product.inactiveReason!
                            : '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Divider(height: 1),
        if (_loadingVersions)
          const LinearProgressIndicator()
        else
          Expanded(
            child: _versions.isEmpty
                ? const Center(child: Text('暂无版本记录'))
                : SingleChildScrollView(
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
                      rows: _versions
                          .map((rev) => _buildVersionRow(rev))
                          .toList(),
                    ),
                  ),
          ),
      ],
    );
  }

  DataRow _buildVersionRow(ProductVersionItem rev) {
    final statusLabel =
        _statusLabels[rev.lifecycleStatus] ?? rev.lifecycleStatus;
    final statusColor = _statusColors[rev.lifecycleStatus] ?? Colors.grey;
    final isDraft = rev.lifecycleStatus == 'draft';
    final isEffective = rev.lifecycleStatus == 'effective';
    final isObsolete = rev.lifecycleStatus == 'obsolete';

    final effectiveTimeText = rev.effectiveAt != null
        ? _formatDate(rev.effectiveAt!)
        : '-';

    return DataRow(
      selected: _selectedVersionNumber == rev.version,
      onSelectChanged: (_) {
        setState(() {
          _selectedVersionNumber = rev.version;
        });
      },
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rev.versionLabel,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (isEffective) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
              ],
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
          ),
        ),
        DataCell(
          Text(
            rev.note != null && rev.note!.isNotEmpty ? rev.note! : '-',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text(rev.sourceVersionLabel ?? '-')),
        DataCell(Text(rev.createdByUsername ?? '-')),
        DataCell(Text(_formatDate(rev.createdAt))),
        DataCell(Text(effectiveTimeText)),
        DataCell(
          (widget.canManageVersions ||
                  widget.canActivateVersions ||
                  widget.canExportVersionParameters)
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'detail', child: Text('查看详情')),
                    if (widget.canActivateVersions && isDraft)
                      const PopupMenuItem(
                        value: 'activate',
                        child: Text('立即生效'),
                      ),
                    if (widget.canManageVersions &&
                        (isDraft ||
                            isEffective ||
                            isObsolete ||
                            rev.lifecycleStatus == 'disabled'))
                      const PopupMenuItem(value: 'copy', child: Text('复制版本')),
                    if (widget.canManageVersions)
                      const PopupMenuItem(
                        value: 'editNote',
                        child: Text('编辑版本说明'),
                      ),
                    PopupMenuItem(
                      value: 'editParams',
                      child: Text(isDraft ? '维护参数' : '查看参数'),
                    ),
                    if (widget.canExportVersionParameters)
                      const PopupMenuItem(
                        value: 'export',
                        child: Text('导出版本参数'),
                      ),
                    if (widget.canManageVersions && (isEffective || isObsolete))
                      const PopupMenuItem(
                        value: 'disable',
                        child: Text('停用版本'),
                      ),
                    if (widget.canManageVersions && isDraft)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '删除版本',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                  onSelected: (action) {
                    switch (action) {
                      case 'detail':
                        _showVersionDetail(rev);
                      case 'activate':
                        _activateVersion(rev);
                      case 'copy':
                        _copyVersion(rev);
                      case 'editNote':
                        _editVersionNote(rev);
                      case 'editParams':
                        _navigateToEditParams(rev);
                      case 'export':
                        _exportVersionParams(rev);
                      case 'disable':
                        _disableVersion(rev);
                      case 'delete':
                        _deleteVersion(rev);
                    }
                  },
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CrudPageHeader(title: '版本管理', onRefresh: _refreshPage),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: _buildProductList(),
                  ),
                ),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(left: 8),
                    child: _buildVersionList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
