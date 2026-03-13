import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/product_models.dart';
import '../services/api_exception.dart';
import '../services/product_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/unified_list_table_header_style.dart';

const List<String> _productCategoryOptions = ['贴片', 'DTU', '套件'];

enum _ProductTableAction {
  deactivate,
  reactivate,
  version,
  viewParams,
  editParams,
  delete,
}

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canCreateProduct,
    required this.canDeleteProduct,
    required this.canUpdateLifecycle,
    required this.canViewVersions,
    required this.canCompareVersions,
    required this.canRollbackVersion,
    required this.canViewImpactAnalysis,
    required this.canViewParameters,
    required this.canEditParameters,
    required this.onViewParameters,
    required this.onEditParameters,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canCreateProduct;
  final bool canDeleteProduct;
  final bool canUpdateLifecycle;
  final bool canViewVersions;
  final bool canCompareVersions;
  final bool canRollbackVersion;
  final bool canViewImpactAnalysis;
  final bool canViewParameters;
  final bool canEditParameters;
  final ValueChanged<ProductItem> onViewParameters;
  final ValueChanged<ProductItem> onEditParameters;

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  late final ProductService _productService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  String _selectedCategoryFilter = '';
  int _total = 0;
  List<ProductItem> _products = const [];

  @override
  void initState() {
    super.initState();
    _productService = ProductService(widget.session);
    _loadProducts();
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

  void _showPermissionDenied(String actionLabel) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('没有权限执行“$actionLabel”')));
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

  String _lifecycleLabel(String value) {
    switch (value) {
      case 'active':
        return '启用';
      case 'draft':
        return '草稿';
      case 'pending_review':
        return '待审核';
      case 'effective':
        return '启用';
      case 'inactive':
        return '停用';
      case 'obsolete':
        return '已废弃';
      default:
        return value;
    }
  }

  String _formatDisplayVersion(int version) {
    return 'V1.$version';
  }

  Future<bool> _confirmImpact(
    ProductImpactAnalysisResult impact, {
    required String title,
  }) async {
    if (!impact.requiresConfirmation) {
      return false;
    }
    final confirmed = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '存在 ${impact.totalOrders} 条未完工订单（待开工 ${impact.pendingOrders}，生产中 ${impact.inProgressOrders}）。',
                ),
                const SizedBox(height: 8),
                const Text('继续操作将按你的确认强制执行。'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView(
                    children: impact.items
                        .take(20)
                        .map(
                          (item) => Text(
                            '${item.orderCode} / ${item.orderStatus} ${item.reason ?? ''}',
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认继续'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<String?> _promptInactiveReason() async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showLockedFormDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('停用产品'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '停用原因',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入停用原因';
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(reasonController.text.trim());
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();
    return result;
  }

  Future<void> _changeLifecycle(
    ProductItem product,
    String targetStatus,
  ) async {
    if (!widget.canUpdateLifecycle) {
      _showPermissionDenied('更新产品生命周期');
      return;
    }

    String? inactiveReason;
    if (targetStatus == 'inactive') {
      inactiveReason = await _promptInactiveReason();
      if (inactiveReason == null) {
        return;
      }
    }

    bool confirmed = false;
    if (widget.canViewImpactAnalysis) {
      try {
        final impact = await _productService.getProductImpactAnalysis(
          productId: product.id,
          operation: 'lifecycle',
          targetStatus: targetStatus,
        );
        if (impact.requiresConfirmation) {
          confirmed = await _confirmImpact(impact, title: '变更影响确认');
          if (!confirmed) {
            return;
          }
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        if (_isUnauthorized(error)) {
          widget.onLogout();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载影响分析失败：${_errorMessage(error)}')),
        );
        return;
      }
    }

    try {
      await _productService.updateProductLifecycle(
        productId: product.id,
        payload: ProductLifecycleUpdateRequest(
          targetStatus: targetStatus,
          confirmed: confirmed,
          inactiveReason: inactiveReason,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('产品生命周期已更新')));
      await _loadProducts();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生命周期更新失败：${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _showVersionDialog(ProductItem product) async {
    if (!widget.canViewVersions) {
      _showPermissionDenied('查看产品版本');
      return;
    }

    ProductVersionListResult versions;
    try {
      versions = await _productService.listProductVersions(
        productId: product.id,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载版本失败：${_errorMessage(error)}')));
      return;
    }
    if (!mounted) {
      return;
    }

    int? fromVersion;
    int? toVersion;
    ProductVersionCompareResult? compareResult;

    await showLockedFormDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final versionItems = versions.items;
            fromVersion ??= versionItems.isNotEmpty
                ? versionItems.first.version
                : null;
            toVersion ??= versionItems.length >= 2
                ? versionItems[1].version
                : fromVersion;
            return AlertDialog(
              title: Text('版本管理 - ${product.name}'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<int>(
                            value: fromVersion,
                            hint: const Text('起始版本'),
                            items: versionItems
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: item.version,
                                    child: Text(item.displayVersion),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setLocalState(() {
                                fromVersion = value;
                              });
                            },
                          ),
                          DropdownButton<int>(
                            value: toVersion,
                            hint: const Text('目标版本'),
                            items: versionItems
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: item.version,
                                    child: Text(item.displayVersion),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setLocalState(() {
                                toVersion = value;
                              });
                            },
                          ),
                          FilledButton(
                            onPressed:
                                !widget.canCompareVersions ||
                                    fromVersion == null ||
                                    toVersion == null
                                ? null
                                : () async {
                                    try {
                                      final result = await _productService
                                          .compareProductVersions(
                                            productId: product.id,
                                            fromVersion: fromVersion!,
                                            toVersion: toVersion!,
                                          );
                                      setLocalState(() {
                                        compareResult = result;
                                      });
                                    } catch (error) {
                                      if (_isUnauthorized(error)) {
                                        widget.onLogout();
                                        return;
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '版本对比失败：${_errorMessage(error)}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: const Text('版本对比'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (compareResult != null) ...[
                        Text(
                          '对比结果：新增 ${compareResult!.addedItems}，移除 ${compareResult!.removedItems}，变更 ${compareResult!.changedItems}',
                        ),
                        const SizedBox(height: 6),
                        ...compareResult!.items
                            .map(
                              (item) => Text(
                                '[${item.diffType}] ${item.key} | ${item.fromValue ?? '-'} -> ${item.toValue ?? '-'}',
                              ),
                            )
                            .take(50),
                        const Divider(height: 20),
                      ],
                      const Text('版本列表'),
                      const SizedBox(height: 8),
                      ...versions.items.map(
                        (item) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${item.displayVersion} / ${item.action} / ${_lifecycleLabel(item.lifecycleStatus)}',
                          ),
                          subtitle: Text(
                            '${_formatTime(item.createdAt)} ${item.createdByUsername ?? '-'} ${item.note ?? ''}',
                          ),
                          trailing: TextButton(
                            onPressed: !widget.canRollbackVersion
                                ? null
                                : () async {
                                    try {
                                      var confirmed = false;
                                      if (widget.canViewImpactAnalysis) {
                                        final impact = await _productService
                                            .getProductImpactAnalysis(
                                              productId: product.id,
                                              operation: 'rollback',
                                              targetVersion: item.version,
                                            );
                                        if (impact.requiresConfirmation) {
                                          confirmed = await _confirmImpact(
                                            impact,
                                            title: '回滚影响确认',
                                          );
                                          if (!confirmed) {
                                            return;
                                          }
                                        }
                                      }

                                      await _productService.rollbackProduct(
                                        productId: product.id,
                                        targetVersion: item.version,
                                        confirmed: confirmed,
                                        note: '回滚到${item.displayVersion}',
                                      );
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '已回滚到 ${item.displayVersion}',
                                            ),
                                          ),
                                        );
                                        await _loadProducts();
                                      }
                                    } catch (error) {
                                      if (_isUnauthorized(error)) {
                                        widget.onLogout();
                                        return;
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '版本回滚失败：${_errorMessage(error)}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: const Text('回滚到此版本'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
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
        category: _selectedCategoryFilter,
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

  Future<void> _showCreateProductDialog() async {
    if (!widget.canCreateProduct) {
      _showPermissionDenied('创建产品');
      return;
    }

    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedCategory = _productCategoryOptions.first;

    final created = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('添加产品'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '产品名称',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入产品名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: '产品分类',
                          border: OutlineInputBorder(),
                        ),
                        items: _productCategoryOptions
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setLocalState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    try {
                      await _productService.createProduct(
                        name: nameController.text.trim(),
                        category: selectedCategory,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    } catch (error) {
                      if (_isUnauthorized(error)) {
                        widget.onLogout();
                        return;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('添加产品失败：${_errorMessage(error)}'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    if (created == true) {
      await _loadProducts();
    }
  }

  Future<void> _deleteProduct(ProductItem product) async {
    if (!widget.canDeleteProduct) {
      _showPermissionDenied('删除产品');
      return;
    }

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除产品'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('确认删除产品“${product.name}”吗？'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '请输入当前账号密码',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                try {
                  await _productService.deleteProduct(
                    productId: product.id,
                    password: passwordController.text,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                } catch (error) {
                  if (_isUnauthorized(error)) {
                    widget.onLogout();
                    return;
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('删除产品失败：${_errorMessage(error)}')),
                    );
                  }
                }
              },
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );

    passwordController.dispose();

    if (confirmed == true) {
      await _loadProducts();
    }
  }

  List<PopupMenuEntry<_ProductTableAction>> _buildProductActionMenuItems(
    ProductItem product,
  ) {
    final items = <PopupMenuEntry<_ProductTableAction>>[];
    if (widget.canUpdateLifecycle) {
      switch (product.lifecycleStatus) {
        case 'active':
        case 'effective':
          items.add(
            const PopupMenuItem(
              value: _ProductTableAction.deactivate,
              child: Text('停用'),
            ),
          );
          break;
        case 'inactive':
          items.add(
            const PopupMenuItem(
              value: _ProductTableAction.reactivate,
              child: Text('启用'),
            ),
          );
          break;
        default:
          break;
      }
    }

    final utilityItems = <PopupMenuEntry<_ProductTableAction>>[];
    if (widget.canViewVersions) {
      utilityItems.add(
        const PopupMenuItem(
          value: _ProductTableAction.version,
          child: Text('版本管理'),
        ),
      );
    }
    if (widget.canViewParameters) {
      utilityItems.add(
        const PopupMenuItem(
          value: _ProductTableAction.viewParams,
          child: Text('查看参数'),
        ),
      );
    }
    if (widget.canEditParameters) {
      utilityItems.add(
        const PopupMenuItem(
          value: _ProductTableAction.editParams,
          child: Text('编辑参数'),
        ),
      );
    }
    if (widget.canDeleteProduct) {
      utilityItems.add(
        const PopupMenuItem(
          value: _ProductTableAction.delete,
          child: Text('删除产品'),
        ),
      );
    }
    if (items.isNotEmpty && utilityItems.isNotEmpty) {
      items.add(const PopupMenuDivider());
    }
    items.addAll(utilityItems);
    return items;
  }

  Future<void> _handleProductTableAction(
    _ProductTableAction action,
    ProductItem product,
  ) async {
    switch (action) {
      case _ProductTableAction.reactivate:
        await _changeLifecycle(product, 'active');
        return;
      case _ProductTableAction.deactivate:
        await _changeLifecycle(product, 'inactive');
        return;
      case _ProductTableAction.version:
        await _showVersionDialog(product);
        return;
      case _ProductTableAction.viewParams:
        widget.onViewParameters(product);
        return;
      case _ProductTableAction.editParams:
        widget.onEditParameters(product);
        return;
      case _ProductTableAction.delete:
        await _deleteProduct(product);
        return;
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
                '产品管理',
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
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryFilter,
                  decoration: const InputDecoration(
                    labelText: '分类筛选',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String>(value: '', child: Text('全部')),
                    ..._productCategoryOptions.map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() {
                            _selectedCategoryFilter = value ?? '';
                          });
                          _loadProducts();
                        },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _loadProducts,
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading || !widget.canCreateProduct
                    ? null
                    : _showCreateProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('添加产品'),
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
                    child: AdaptiveTableContainer(
                      child: UnifiedListTableHeaderStyle.wrap(
                        theme: theme,
                        child: DataTable(
                          columns: [
                            UnifiedListTableHeaderStyle.column(context, '产品名称'),
                            UnifiedListTableHeaderStyle.column(context, '产品分类'),
                            UnifiedListTableHeaderStyle.column(context, '状态'),
                            UnifiedListTableHeaderStyle.column(context, '当前版本'),
                            UnifiedListTableHeaderStyle.column(context, '生效版本'),
                            UnifiedListTableHeaderStyle.column(context, '创建时间'),
                            UnifiedListTableHeaderStyle.column(context, '更新时间'),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '操作',
                              textAlign: TextAlign.center,
                            ),
                          ],
                          rows: _products.map((product) {
                            final actions = _buildProductActionMenuItems(
                              product,
                            );
                            return DataRow(
                              cells: [
                                DataCell(Text(product.name)),
                                DataCell(Text(product.category)),
                                DataCell(
                                  Text(
                                    _lifecycleLabel(product.lifecycleStatus),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatDisplayVersion(
                                      product.currentVersion,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    product.effectiveVersion > 0
                                        ? _formatDisplayVersion(
                                            product.effectiveVersion,
                                          )
                                        : '-',
                                  ),
                                ),
                                DataCell(Text(_formatTime(product.createdAt))),
                                DataCell(Text(_formatTime(product.updatedAt))),
                                DataCell(
                                  actions.isEmpty
                                      ? const Text('-')
                                      : UnifiedListTableHeaderStyle.actionMenuButton<
                                          _ProductTableAction
                                        >(
                                          theme: theme,
                                          onSelected: (action) {
                                            _handleProductTableAction(
                                              action,
                                              product,
                                            );
                                          },
                                          itemBuilder: (context) => actions,
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
