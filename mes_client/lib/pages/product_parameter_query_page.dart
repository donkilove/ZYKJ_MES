import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/product_models.dart';
import '../services/api_exception.dart';
import '../services/product_service.dart';

class ProductParameterQueryPage extends StatefulWidget {
  const ProductParameterQueryPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.tabCode,
    this.jumpCommand,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String tabCode;
  final ProductJumpCommand? jumpCommand;

  @override
  State<ProductParameterQueryPage> createState() =>
      _ProductParameterQueryPageState();
}

class _ProductParameterQueryPageState extends State<ProductParameterQueryPage> {
  late final ProductService _productService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<ProductItem> _products = const [];
  int _handledJumpSeq = 0;

  @override
  void initState() {
    super.initState();
    _productService = ProductService(widget.session);
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProductParameterQueryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _productService.listProducts(
        page: 1,
        pageSize: 100,
        keyword: _keywordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _products = result.items;
        _total = result.total;
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
      }
    }
  }

  Future<void> _showParametersDialog(ProductItem product) async {
    ProductParameterListResult result;
    try {
      result = await _productService.listProductParameters(productId: product.id);
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('产品参数 - ${product.name}'),
          content: SizedBox(
            width: 680,
            child: result.items.isEmpty
                ? const Center(child: Text('该产品暂无参数'))
                : SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('参数名')),
                        DataColumn(label: Text('参数值')),
                      ],
                      rows: result.items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.key)),
                            DataCell(Text(item.value)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '产品参数查询',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadProducts,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '搜索产品名称',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadProducts(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _loadProducts,
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('总数：$_total', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                ? const Center(child: Text('暂无产品'))
                : Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('产品名称')),
                            DataColumn(label: Text('创建时间')),
                            DataColumn(label: Text('最后修改时间')),
                            DataColumn(label: Text('查看产品参数')),
                          ],
                          rows: _products.map((product) {
                            return DataRow(
                              cells: [
                                DataCell(Text(product.name)),
                                DataCell(Text(_formatTime(product.createdAt))),
                                DataCell(Text(_formatTime(product.updatedAt))),
                                DataCell(
                                  TextButton(
                                    onPressed: () =>
                                        _showParametersDialog(product),
                                    child: const Text('查看参数'),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
