import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/product_models.dart';
import '../services/api_exception.dart';
import '../services/product_service.dart';

class ProductParameterManagementPage extends StatefulWidget {
  const ProductParameterManagementPage({
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
  State<ProductParameterManagementPage> createState() =>
      _ProductParameterManagementPageState();
}

class _ProductParameterManagementPageState
    extends State<ProductParameterManagementPage> {
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
  void didUpdateWidget(covariant ProductParameterManagementPage oldWidget) {
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
    if (command.action == 'edit') {
      final product = _findProductById(command.productId);
      if (product != null) {
        await _showEditParametersDialog(product);
      }
    }
  }

  Future<void> _showHistoryDialog(ProductItem product) async {
    ProductParameterHistoryListResult? historyResult;
    try {
      historyResult = await _productService.listProductParameterHistory(
        productId: product.id,
        page: 1,
        pageSize: 100,
      );
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载历史失败：${_errorMessage(error)}')),
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
          title: Text('历史修改备注 - ${product.name}'),
          content: SizedBox(
            width: 720,
            child: historyResult!.items.isEmpty
                ? const Center(child: Text('暂无历史记录'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: historyResult.items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = historyResult!.items[index];
                      final keySummary = item.changedKeys.isEmpty
                          ? '-'
                          : item.changedKeys.join(', ');
                      return ListTile(
                        title: Text(item.remark),
                        subtitle: Text(
                          '时间：${_formatTime(item.createdAt)}\n'
                          '操作人：${item.operatorUsername}   修改参数：$keySummary',
                        ),
                        isThreeLine: true,
                      );
                    },
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

  Future<void> _showEditParametersDialog(ProductItem product) async {
    ProductParameterListResult parameterResult;
    try {
      parameterResult = await _productService.listProductParameters(
        productId: product.id,
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

    final remarkController = TextEditingController();
    final rows = parameterResult.items
        .map((item) => _ParameterEditorRow.initial(item.key, item.value))
        .toList();
    if (rows.isEmpty) {
      rows.add(_ParameterEditorRow.initial('', ''));
    }

    if (!mounted) {
      for (final row in rows) {
        row.dispose();
      }
      remarkController.dispose();
      return;
    }

    var submitting = false;
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('编辑产品参数 - ${product.name}'),
              content: SizedBox(
                width: 760,
                height: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: row.keyController,
                                  decoration: const InputDecoration(
                                    labelText: '参数名',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: row.valueController,
                                  decoration: const InputDecoration(
                                    labelText: '参数值',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: '删除本行',
                                onPressed: rows.length <= 1 || submitting
                                    ? null
                                    : () {
                                        final removed = rows.removeAt(index);
                                        removed.dispose();
                                        setDialogState(() {});
                                      },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: submitting
                            ? null
                            : () {
                                rows.add(_ParameterEditorRow.initial('', ''));
                                setDialogState(() {});
                              },
                        icon: const Icon(Icons.add),
                        label: const Text('新增参数'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: remarkController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '本次修改备注（必填）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final remark = remarkController.text.trim();
                          if (remark.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('请填写本次修改备注')),
                            );
                            return;
                          }

                          final items = <ProductParameterItem>[];
                          final keySet = <String>{};
                          for (final row in rows) {
                            final key = row.keyController.text.trim();
                            final value = row.valueController.text.trim();
                            if (key.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('参数名不能为空')),
                              );
                              return;
                            }
                            if (keySet.contains(key)) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('参数名重复：$key')),
                              );
                              return;
                            }
                            keySet.add(key);
                            items.add(ProductParameterItem(key: key, value: value));
                          }

                          setDialogState(() {
                            submitting = true;
                          });

                          try {
                            final updateResult = await _productService
                                .updateProductParameters(
                                  productId: product.id,
                                  remark: remark,
                                  items: items,
                                );
                            if (dialogContext.mounted) {
                              final changed = updateResult.changedKeys.isEmpty
                                  ? '-'
                                  : updateResult.changedKeys.join(', ');
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('更新成功，修改参数：$changed')),
                              );
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (error) {
                            if (_isUnauthorized(error)) {
                              widget.onLogout();
                              return;
                            }
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('更新参数失败：${_errorMessage(error)}'),
                                ),
                              );
                            }
                            setDialogState(() {
                              submitting = false;
                            });
                          }
                        },
                  child: const Text('保存参数'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final row in rows) {
      row.dispose();
    }
    remarkController.dispose();

    if (updated == true) {
      await _loadProducts();
    }
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
                '产品参数管理',
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
                            DataColumn(label: Text('最后修改参数')),
                            DataColumn(label: Text('历史修改备注')),
                            DataColumn(label: Text('编辑产品参数')),
                          ],
                          rows: _products.map((product) {
                            return DataRow(
                              cells: [
                                DataCell(Text(product.name)),
                                DataCell(Text(_formatTime(product.createdAt))),
                                DataCell(Text(_formatTime(product.updatedAt))),
                                DataCell(Text(product.lastParameterSummary ?? '-')),
                                DataCell(
                                  TextButton(
                                    onPressed: () => _showHistoryDialog(product),
                                    child: const Text('查看历史'),
                                  ),
                                ),
                                DataCell(
                                  TextButton(
                                    onPressed: () =>
                                        _showEditParametersDialog(product),
                                    child: const Text('编辑参数'),
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

class _ParameterEditorRow {
  _ParameterEditorRow.initial(String key, String value)
    : keyController = TextEditingController(text: key),
      valueController = TextEditingController(text: value);

  final TextEditingController keyController;
  final TextEditingController valueController;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}
