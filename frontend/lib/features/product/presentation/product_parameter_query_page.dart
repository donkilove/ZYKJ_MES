import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/services/export_file_service.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_action_dialogs.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_table_section.dart';
import 'package:mes_client/features/product/presentation/product_category_options.dart';
import 'package:mes_client/features/product/services/product_service.dart';

class ProductParameterQueryPage extends StatefulWidget {
  const ProductParameterQueryPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.tabCode,
    this.isCurrentTabVisible = true,
    this.jumpCommand,
    this.onJumpHandled,
    this.service,
    this.canExportParameters = false,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String tabCode;
  final bool isCurrentTabVisible;
  final ProductJumpCommand? jumpCommand;
  final ValueChanged<int>? onJumpHandled;
  final ProductService? service;
  final bool canExportParameters;

  @override
  State<ProductParameterQueryPage> createState() =>
      _ProductParameterQueryPageState();
}

class _ProductParameterQueryPageState extends State<ProductParameterQueryPage> {
  static const int _listPageSize = 200;
  late final ProductService _productService;
  final ExportFileService _exportFileService = const ExportFileService();
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  List<ProductItem> _products = const [];
  int _handledJumpSeq = 0;
  String _selectedCategoryFilter = '';
  bool _scheduledVisibleEmptyRetry = false;

  @override
  void initState() {
    super.initState();
    _productService = widget.service ?? ProductService(widget.session);
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProductParameterQueryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentTabVisible && !oldWidget.isCurrentTabVisible) {
      _retryVisibleEmptyProductsOnTabVisible();
    }
    final command = widget.jumpCommand;
    if (command == null) {
      return;
    }
    if (command.seq == _handledJumpSeq) {
      return;
    }
    if (command.targetTabCode != widget.tabCode) {
      return;
    }
    _handledJumpSeq = command.seq;
    unawaited(_handleJumpCommand(command));
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  ProductItem? _findProductById(int productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  void _reloadProductsFromUserAction() {
    _scheduledVisibleEmptyRetry = false;
    unawaited(_loadProducts());
  }

  void _retryVisibleEmptyProductsOnTabVisible() {
    if (!widget.isCurrentTabVisible ||
        _loading ||
        _products.isNotEmpty ||
        _message.trim().isNotEmpty ||
        _scheduledVisibleEmptyRetry) {
      return;
    }
    _scheduledVisibleEmptyRetry = true;
    unawaited(_loadProducts());
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _productService.listProductsForParameterQuery(
        page: 1,
        pageSize: _listPageSize,
        keyword: _keywordController.text.trim(),
        category: _selectedCategoryFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _products = result.items;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载产品失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<ProductItem> get _filteredProducts {
    return _products;
  }

  Future<void> _handleJumpCommand(ProductJumpCommand command) async {
    _keywordController.text = command.productName;
    await _loadProducts();
    if (!mounted) {
      return;
    }
    if (command.action == 'view') {
      final product = _findProductById(command.productId);
      if (product != null) {
        await _showParametersDialog(product);
        if (mounted) {
          widget.onJumpHandled?.call(command.seq);
        }
      }
    }
  }

  String _linkDisplayName(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return '-';
    }
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final pathSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      if (pathSegment.isNotEmpty) {
        return Uri.decodeComponent(pathSegment);
      }
      return uri.host.isEmpty ? value : uri.host;
    }
    final filename = p.basename(value);
    return filename.isEmpty ? value : filename;
  }

  Future<void> _openLink(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return;
    }

    Uri uri;
    final parsed = Uri.tryParse(value);
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      uri = parsed;
    } else {
      uri = Uri.file(value, windows: true);
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开链接：$value')));
    }
  }

  Widget _buildParameterValueCell(ProductParameterItem item) {
    final value = item.value.trim();
    if (item.type != 'Link') {
      return Text(value.isEmpty ? '-' : value);
    }
    if (value.isEmpty) {
      return const Text('-');
    }
    return TextButton(
      onPressed: () => _openLink(value),
      child: Text(_linkDisplayName(value), overflow: TextOverflow.ellipsis),
    );
  }

  Future<void> _exportParameters() async {
    try {
      final exportFile = await _productService.exportProductParameters(
        keyword: _keywordController.text.trim(),
        category: _selectedCategoryFilter,
        lifecycleStatus: 'active',
        effectiveOnly: true,
      );
      if (exportFile.contentBase64.isEmpty) {
        throw const FormatException('导出内容为空');
      }
      final fallbackName =
          '产品参数查询_${DateTime.now().millisecondsSinceEpoch}.csv';
      final savedPath = await _exportFileService.saveCsvBase64(
        filename: exportFile.filename.isEmpty
            ? fallbackName
            : exportFile.filename,
        contentBase64: exportFile.contentBase64,
      );
      if (savedPath == null) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出成功：$savedPath')));
      }
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败：${_errorMessage(error)}')));
      }
    }
  }

  Future<void> _showParametersDialog(ProductItem product) async {
    if (product.effectiveVersion == 0) {
      await showProductParameterUnavailableDialog(
        context: context,
        productName: product.name,
      );
      return;
    }

    ProductParameterListResult result;
    try {
      result = await _productService.listProductParameters(
        productId: product.id,
        effectiveOnly: true,
      );
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载参数失败：${_errorMessage(error)}')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    await showProductParameterResultDialog(
      context: context,
      result: result,
      buildParameterValueCell: _buildParameterValueCell,
    );
  }

  Widget _buildListView() {
    return MesCrudPageScaffold(
      header: ProductParameterQueryPageHeader(
        loading: _loading,
        onRefresh: _reloadProductsFromUserAction,
      ),
      filters: ProductParameterQueryFilterSection(
        keywordController: _keywordController,
        categoryOptions: productCategoryOptions,
        selectedCategory: _selectedCategoryFilter,
        loading: _loading,
        canExportParameters: widget.canExportParameters,
        onCategoryChanged: (value) {
          setState(() {
            _selectedCategoryFilter = value;
          });
          _reloadProductsFromUserAction();
        },
        onSearch: _reloadProductsFromUserAction,
        onExport: _exportParameters,
      ),
      banner: _message.isEmpty
          ? null
          : ProductParameterQueryFeedbackBanner(message: _message),
      content: ProductParameterQueryTableSection(
        products: _filteredProducts,
        loading: _loading,
        emptyText: '暂无产品',
        formatTime: _formatTime,
        onViewParameters: _showParametersDialog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildListView();
  }
}
