import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_list_detail_shell.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_selector_panel.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_toolbar.dart';
import 'package:mes_client/features/product/services/product_service.dart';

const Map<String, String> _statusLabels = {
  'draft': '草稿',
  'effective': '已生效',
  'obsolete': '已失效',
  'disabled': '已停用',
  'inactive': '已失效',
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
  String _pageMessage = '';
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.jumpCommand?.seq != cmd.seq) {
          return;
        }
        _handleJump(cmd);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _pageMessage = '';
    });
    try {
      final result = await _service.listProducts(
        page: _productPage,
        pageSize: _productPageSize,
        keyword: _productKeyword.isEmpty ? null : _productKeyword,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _products = result.items;
        _productTotal = result.total;
        _pageMessage = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pageMessage = '加载产品列表失败：$error';
      });
      _showError('加载产品列表失败: $error');
    } finally {
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
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
      _pageMessage = '';
    });
    try {
      final result = await _service.listProductVersions(productId: product.id);
      if (!mounted) {
        return;
      }
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
        _pageMessage = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pageMessage = '加载版本列表失败：$error';
      });
      _showError('加载版本列表失败: $error');
    } finally {
      if (mounted) {
        setState(() => _loadingVersions = false);
      }
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

  ProductVersionItem? get _effectiveVersion {
    for (final item in _versions) {
      if (item.lifecycleStatus == 'effective') {
        return item;
      }
    }
    return null;
  }

  bool get _hasDraftVersion {
    for (final item in _versions) {
      if (item.lifecycleStatus == 'draft') {
        return true;
      }
    }
    return false;
  }

  int get _productTotalPages {
    if (_productTotal <= 0) {
      return 1;
    }
    return ((_productTotal - 1) ~/ _productPageSize) + 1;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
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
        setState(() {
          _pageMessage = '刷新产品状态失败：$e';
        });
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

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduct = _selectedProduct;
    final selectedVersion = _selectedVersion;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductVersionPageHeader(
            loading: _loadingProducts || _loadingVersions,
            onRefresh: _refreshPage,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: MesListDetailShell(
              banner: ProductVersionFeedbackBanner(
                message: _pageMessage,
                hasDraft: _hasDraftVersion,
                product: selectedProduct,
                effectiveVersion: _effectiveVersion,
                formatDate: _formatDate,
              ),
              sidebar: ProductSelectorPanel(
                searchController: _searchController,
                loading: _loadingProducts,
                products: _products,
                selectedProductId: selectedProduct?.id,
                page: _productPage,
                totalPages: _productTotalPages,
                total: _productTotal,
                onSearchSubmitted: (value) {
                  _productKeyword = value.trim();
                  _productPage = 1;
                  _loadProducts();
                },
                onRefresh: _loadProducts,
                onSelectProduct: (product) => _loadVersions(product),
                onPreviousPage: _productPage > 1
                    ? () {
                        _productPage -= 1;
                        _loadProducts();
                      }
                    : null,
                onNextPage: _productPage < _productTotalPages
                    ? () {
                        _productPage += 1;
                        _loadProducts();
                      }
                    : null,
              ),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProductVersionToolbar(
                    product: selectedProduct,
                    selectedVersion: selectedVersion,
                    hasDraft: _hasDraftVersion,
                    canManageVersions: widget.canManageVersions,
                    canActivateVersions: widget.canActivateVersions,
                    canExportVersionParameters:
                        widget.canExportVersionParameters,
                    onCreateVersion: _createVersion,
                    onCopyVersion: () {
                      if (selectedVersion != null) {
                        _copyVersion(selectedVersion);
                      }
                    },
                    onEditVersionNote: () {
                      if (selectedVersion != null) {
                        _editVersionNote(selectedVersion);
                      }
                    },
                    onExportParameters: () {
                      if (selectedVersion != null) {
                        _exportVersionParams(selectedVersion);
                      }
                    },
                    onActivateVersion: () {
                      if (selectedVersion != null) {
                        _activateVersion(selectedVersion);
                      }
                    },
                    onRefresh: () {
                      if (selectedProduct != null) {
                        _loadVersions(selectedProduct);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: selectedProduct == null
                        ? const Center(child: Text('请在左侧选择产品'))
                        : ProductVersionTableSection(
                            versions: _versions,
                            loading: _loadingVersions,
                            selectedVersionNumber: _selectedVersionNumber,
                            canManageVersions: widget.canManageVersions,
                            canActivateVersions: widget.canActivateVersions,
                            canExportVersionParameters:
                                widget.canExportVersionParameters,
                            onSelectVersion: (versionNumber) {
                              setState(() {
                                _selectedVersionNumber = versionNumber;
                              });
                            },
                            onShowDetail: _showVersionDetail,
                            onActivate: _activateVersion,
                            onCopy: _copyVersion,
                            onEditNote: _editVersionNote,
                            onEditParameters: _navigateToEditParams,
                            onExport: _exportVersionParams,
                            onDisable: _disableVersion,
                            onDelete: _deleteVersion,
                            formatDate: _formatDate,
                          ),
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
