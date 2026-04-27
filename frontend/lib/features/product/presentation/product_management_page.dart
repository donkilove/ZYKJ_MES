import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart'
    show ProductManagementTableAction, ProductManagementTableSection;
import 'package:mes_client/features/product/presentation/widgets/product_detail_drawer.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_dialog.dart';
import 'package:mes_client/features/product/services/product_service.dart';

const List<String> _productCategoryOptions = ['贴片', 'DTU', '套件'];

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canCreateProduct,
    this.canExportProducts = false,
    required this.canDeleteProduct,
    required this.canUpdateLifecycle,
    required this.canViewVersions,
    required this.canCompareVersions,
    required this.canRollbackVersion,
    this.canManageVersions = false,
    this.canActivateVersions = false,
    required this.canViewImpactAnalysis,
    required this.canViewParameters,
    required this.canEditParameters,
    this.canExportParameters = false,
    required this.onViewParameters,
    required this.onEditParameters,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canCreateProduct;
  final bool canExportProducts;
  final bool canDeleteProduct;
  final bool canUpdateLifecycle;
  final bool canViewVersions;
  final bool canCompareVersions;
  final bool canRollbackVersion;
  final bool canManageVersions;
  final bool canActivateVersions;
  final bool canViewImpactAnalysis;
  final bool canViewParameters;
  final bool canEditParameters;
  final bool canExportParameters;
  final ValueChanged<ProductItem> onViewParameters;
  final ValueChanged<ProductItem> onEditParameters;
  final ProductService? service;

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  static const int _pageSize = 50;

  late final ProductService _productService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  String _selectedCategoryFilter = '';
  String _selectedStatusFilter = '';
  String _selectedEffectiveVersionFilter = '';
  int _total = 0;
  int _productPage = 1;
  List<ProductItem> _products = const [];

  int get _productTotalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _pageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _productService = widget.service ?? ProductService(widget.session);
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

  String _versionLifecycleLabel(String value) {
    switch (value) {
      case 'draft':
        return '草稿';
      case 'effective':
        return '已生效';
      case 'obsolete':
        return '已失效';
      case 'disabled':
        return '已停用';
      default:
        return value;
    }
  }

  String? _validateProductName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '产品名称不能为空';
    }
    if (trimmed.length > 128) {
      return '产品名称不能超过 128 个字符';
    }
    return null;
  }

  String? _validateProductRemark(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > 500) {
      return '备注不能超过 500 个字符';
    }
    return null;
  }

  String? _validateProductCategory(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '请选择产品分类';
    }
    if (!_productCategoryOptions.contains(trimmed)) {
      return '产品分类仅允许使用固定枚举';
    }
    return null;
  }

  Widget _buildReadonlyStatusField({
    required String label,
    required String value,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Text(value),
    );
  }

  String _parameterHistoryTypeLabel(String value) {
    switch (value) {
      case 'create':
        return '创建';
      case 'copy':
        return '复制';
      case 'activate':
        return '生效';
      case 'disable':
        return '停用';
      case 'delete':
        return '删除';
      case 'rollback':
        return '回滚';
      case 'update_product':
        return '编辑产品';
      case 'lifecycle':
        return '变更状态';
      case 'update_version_note':
        return '编辑版本备注';
      default:
        return '编辑';
    }
  }

  String _formatDisplayVersion(int version) {
    if (version <= 0) {
      return '-';
    }
    return 'V1.${version - 1}';
  }

  Future<bool> _confirmImpact(
    ProductImpactAnalysisResult impact, {
    required String title,
  }) async {
    if (!impact.requiresConfirmation) {
      return false;
    }
    final confirmed = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return MesDialog(
          title: Text(title),
          width: 520,
          content: Column(
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
    final result = await showMesLockedFormDialog<String>(
      context: context,
      builder: (context) {
        return MesDialog(
          title: const Text('停用产品'),
          width: 420,
          content: Form(
            key: formKey,
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
      final successText = targetStatus == 'inactive' ? '产品已停用' : '产品已启用';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successText)));
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

    int? fromVersion;
    int? toVersion;
    ProductVersionCompareResult? compareResult;
    var versions = ProductVersionListResult(total: 0, items: const []);
    var loadingVersions = true;
    var operationLoading = false;
    var compareLoading = false;
    var initialized = false;
    var dialogClosed = false;
    String? operationLabel;
    BuildContext? dialogContext;

    Future<bool> reloadVersions(StateSetter setLocalState) async {
      if (dialogClosed) {
        return false;
      }
      setLocalState(() {
        loadingVersions = true;
      });
      try {
        final result = await _productService.listProductVersions(
          productId: product.id,
        );
        if (!mounted || dialogClosed) {
          return false;
        }
        setLocalState(() {
          versions = result;
          loadingVersions = false;
          final versionItems = result.items;
          final previousFrom = fromVersion;
          final previousTo = toVersion;
          final hasFrom =
              previousFrom != null &&
              versionItems.any((item) => item.version == previousFrom);
          final hasTo =
              previousTo != null &&
              versionItems.any((item) => item.version == previousTo);
          final nextFrom = hasFrom
              ? previousFrom
              : (versionItems.isNotEmpty ? versionItems.first.version : null);
          final nextTo = hasTo
              ? previousTo
              : (versionItems.length >= 2 ? versionItems[1].version : nextFrom);
          if (nextFrom != previousFrom || nextTo != previousTo) {
            compareResult = null;
          }
          fromVersion = nextFrom;
          toVersion = nextTo;
          if (versionItems.isEmpty) {
            compareResult = null;
          }
        });
        return true;
      } catch (error) {
        if (!mounted || dialogClosed) {
          return false;
        }
        setLocalState(() {
          loadingVersions = false;
        });
        if (_isUnauthorized(error)) {
          widget.onLogout();
          return false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载版本失败：${_errorMessage(error)}')),
        );
        return false;
      }
    }

    Future<bool> confirmVersionAction({
      required String title,
      required String content,
      required String confirmText,
      Color? confirmColor,
    }) async {
      final confirmed = await showMesLockedFormDialog<bool>(
        context: context,
        builder: (context) {
          return MesActionDialog(
            title: Text(title),
            width: 420,
            content: Text(content),
            confirmLabel: confirmText,
            isDestructive: confirmColor != null,
            onConfirm: () => Navigator.of(context).pop(true),
          );
        },
      );
      return confirmed == true;
    }

    Future<void> runVersionOperation(
      StateSetter setLocalState, {
      required String loadingText,
      required String errorPrefix,
      required Future<void> Function() action,
    }) async {
      if (dialogClosed || operationLoading) {
        return;
      }
      setLocalState(() {
        operationLoading = true;
        operationLabel = loadingText;
      });
      try {
        await action();
      } catch (error) {
        if (!mounted || dialogClosed) {
          return;
        }
        if (_isUnauthorized(error)) {
          widget.onLogout();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errorPrefix：${_errorMessage(error)}')),
        );
      } finally {
        if (!dialogClosed && mounted && (dialogContext?.mounted ?? false)) {
          setLocalState(() {
            operationLoading = false;
            operationLabel = null;
          });
        }
      }
    }

    TextButton buildActionButton({
      required String label,
      required VoidCallback? onPressed,
      Color? foregroundColor,
    }) {
      return TextButton(
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
        child: Text(label),
      );
    }

    await showMesLockedFormDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            dialogContext = context;
            if (!initialized) {
              initialized = true;
              Future.microtask(() => reloadVersions(setLocalState));
            }
            final versionItems = versions.items;
            return ProductVersionDialog(
              product: product,
              versions: versionItems,
              loadingVersions: loadingVersions,
              operationLoading: operationLoading,
              compareLoading: compareLoading,
              compareResult: compareResult,
              fromVersion: fromVersion,
              toVersion: toVersion,
              operationLabel: operationLabel,
              canCompareVersions: widget.canCompareVersions,
              canManageVersions: widget.canManageVersions,
              canActivateVersions: widget.canActivateVersions,
              canEditParameters: widget.canEditParameters,
              canRollbackVersion: widget.canRollbackVersion,
              onClose: () => Navigator.of(context).pop(),
              onCreateVersion: () async {
                await runVersionOperation(
                  setLocalState,
                  loadingText: '正在新建版本...',
                  errorPrefix: '新建版本失败',
                  action: () async {
                    await _productService.createProductVersion(
                      productId: product.id,
                    );
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('新建版本成功')),
                    );
                    await reloadVersions(setLocalState);
                  },
                );
              },
              onFromVersionChanged: (value) {
                setLocalState(() {
                  fromVersion = value;
                });
              },
              onToVersionChanged: (value) {
                setLocalState(() {
                  toVersion = value;
                });
              },
              onCompare: () async {
                setLocalState(() {
                  compareLoading = true;
                });
                try {
                  final result = await _productService.compareProductVersions(
                    productId: product.id,
                    fromVersion: fromVersion!,
                    toVersion: toVersion!,
                  );
                  if (!mounted ||
                      dialogClosed ||
                      !(dialogContext?.mounted ?? false)) {
                    return;
                  }
                  setLocalState(() {
                    compareResult = result;
                  });
                } catch (error) {
                  if (!mounted || dialogClosed) {
                    return;
                  }
                  if (_isUnauthorized(error)) {
                    widget.onLogout();
                    return;
                  }
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('版本对比失败：${_errorMessage(error)}'),
                    ),
                  );
                } finally {
                  if (!dialogClosed &&
                      mounted &&
                      (dialogContext?.mounted ?? false)) {
                    setLocalState(() {
                      compareLoading = false;
                    });
                  }
                }
              },
              buildVersionActions: (item) {
                final isDraft = item.lifecycleStatus == 'draft';
                final isEffective = item.lifecycleStatus == 'effective';
                final widgets = <Widget>[];
                if (widget.canEditParameters && isDraft) {
                  widgets.add(
                    buildActionButton(
                      label: '维护参数',
                      onPressed: operationLoading || loadingVersions
                          ? null
                          : () {
                              dialogClosed = true;
                              Navigator.of(context).pop();
                              widget.onEditParameters(product);
                            },
                    ),
                  );
                }
                if (widget.canManageVersions && isDraft) {
                  widgets.add(
                    buildActionButton(
                      label: '编辑备注',
                      onPressed: operationLoading || loadingVersions
                          ? null
                          : () async {
                              final noteController = TextEditingController(
                                text: item.note ?? '',
                              );
                              final newNote =
                                  await showMesLockedFormDialog<String?>(
                                context: context,
                                builder: (ctx) => MesDialog(
                                  title: Text('编辑 ${item.displayVersion} 备注'),
                                  width: 360,
                                  content: TextField(
                                    controller: noteController,
                                    maxLength: 256,
                                    decoration: const InputDecoration(
                                      labelText: '版本备注',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(null),
                                      child: const Text('取消'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(ctx)
                                          .pop(noteController.text),
                                      child: const Text('保存'),
                                    ),
                                  ],
                                ),
                              );
                              noteController.dispose();
                              if (newNote == null) return;
                              await runVersionOperation(
                                setLocalState,
                                loadingText: '正在保存备注...',
                                errorPrefix: '保存备注失败',
                                action: () async {
                                  await _productService.updateProductVersionNote(
                                    productId: product.id,
                                    version: item.version,
                                    note: newNote,
                                  );
                                  await reloadVersions(setLocalState);
                                },
                              );
                            },
                    ),
                  );
                }
                if (widget.canManageVersions) {
                  widgets.add(
                    buildActionButton(
                      label: '复制',
                      onPressed: operationLoading || loadingVersions
                          ? null
                          : () async {
                              await runVersionOperation(
                                setLocalState,
                                loadingText: '正在复制 ${item.displayVersion}...',
                                errorPrefix: '复制版本失败',
                                action: () async {
                                  await _productService.copyProductVersion(
                                    productId: product.id,
                                    sourceVersion: item.version,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '复制版本成功（来源：${item.displayVersion}）',
                                      ),
                                    ),
                                  );
                                  await reloadVersions(setLocalState);
                                },
                              );
                            },
                    ),
                  );
                }
                if (widget.canActivateVersions && isDraft) {
                  widgets.add(
                    buildActionButton(
                      label: '激活',
                      onPressed: operationLoading || loadingVersions
                          ? null
                          : () async {
                              final confirmed = await confirmVersionAction(
                                title: '确认生效',
                                content:
                                    '确认将版本 ${item.displayVersion} 设为生效版本？\n生效后，当前生效版本将自动变为已失效。',
                                confirmText: '确认生效',
                              );
                              if (!confirmed) {
                                return;
                              }
                              await runVersionOperation(
                                setLocalState,
                                loadingText: '正在激活 ${item.displayVersion}...',
                                errorPrefix: '版本激活失败',
                                action: () async {
                                  try {
                                    await _productService.activateProductVersion(
                                      productId: product.id,
                                      version: item.version,
                                    );
                                  } catch (error) {
                                    if (_isUnauthorized(error) ||
                                        !_errorMessage(error).contains(
                                          'Impact confirmation required',
                                        )) {
                                      rethrow;
                                    }
                                    final impact =
                                        await _productService.getProductImpactAnalysis(
                                      productId: product.id,
                                      operation: 'lifecycle',
                                      targetStatus: 'active',
                                      targetVersion: item.version,
                                    );
                                    final impactConfirmed = await _confirmImpact(
                                      impact,
                                      title: '生效影响确认',
                                    );
                                    if (!impactConfirmed) {
                                      return;
                                    }
                                    await _productService.activateProductVersion(
                                      productId: product.id,
                                      version: item.version,
                                      confirmed: true,
                                    );
                                  }
                                  if (!mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '版本 ${item.displayVersion} 已生效',
                                      ),
                                    ),
                                  );
                                  await _loadProducts();
                                  await reloadVersions(setLocalState);
                                },
                              );
                            },
                    ),
                  );
                }
                if (widget.canManageVersions && isEffective) {
                  widgets.add(
                    buildActionButton(
                      label: '停用',
                      onPressed: operationLoading || loadingVersions
                          ? null
                          : () async {
                              final confirmed = await confirmVersionAction(
                                title: '确认停用',
                                content:
                                    '确认停用版本 ${item.displayVersion}？停用后不可直接恢复，如需再次使用请复制出新草稿。',
                                confirmText: '确认停用',
                                confirmColor: Colors.orange,
                              );
                              if (!confirmed) {
                                return;
                              }
                              await runVersionOperation(
                                setLocalState,
                                loadingText: '正在停用 ${item.displayVersion}...',
                                errorPrefix: '停用版本失败',
                                action: () async {
                                  await _productService.disableProductVersion(
                                    productId: product.id,
                                    version: item.version,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  final refreshedProduct =
                                      await _productService.getProduct(
                                    productId: product.id,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        refreshedProduct.lifecycleStatus ==
                                                'inactive'
                                            ? '版本 ${item.displayVersion} 已停用，产品因无生效版本已同步停用'
                                            : '版本 ${item.displayVersion} 已停用',
                                      ),
                                    ),
                                  );
                                  await _loadProducts();
                                  await reloadVersions(setLocalState);
                                },
                              );
                            },
                    ),
                  );
                }
                if (isDraft) {
                  widgets.add(
                    buildActionButton(
                      label: '删除',
                      foregroundColor: Theme.of(context).colorScheme.error,
                      onPressed: operationLoading || loadingVersions
                          ? null
                          : () async {
                              final confirmed = await confirmVersionAction(
                                title: '确认删除',
                                content: '确认删除草稿版本 ${item.displayVersion}？此操作不可撤销。',
                                confirmText: '确认删除',
                                confirmColor: Colors.red,
                              );
                              if (!confirmed) {
                                return;
                              }
                              await runVersionOperation(
                                setLocalState,
                                loadingText: '正在删除 ${item.displayVersion}...',
                                errorPrefix: '删除版本失败',
                                action: () async {
                                  await _productService.deleteProductVersion(
                                    productId: product.id,
                                    version: item.version,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '版本 ${item.displayVersion} 已删除',
                                      ),
                                    ),
                                  );
                                  await reloadVersions(setLocalState);
                                },
                              );
                            },
                    ),
                  );
                }
                if (widget.canRollbackVersion) {
                  widgets.add(
                    buildActionButton(
                      label: '回滚',
                      onPressed: operationLoading || loadingVersions
                          ? null
                          : () async {
                              await runVersionOperation(
                                setLocalState,
                                loadingText: '正在回滚到 ${item.displayVersion}...',
                                errorPrefix: '版本回滚失败',
                                action: () async {
                                  final nav = dialogContext != null
                                      ? Navigator.of(dialogContext!)
                                      : null;
                                  final messenger = ScaffoldMessenger.of(context);
                                  var confirmed = false;
                                  if (widget.canViewImpactAnalysis) {
                                    final impact =
                                        await _productService.getProductImpactAnalysis(
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
                                  if (!mounted) {
                                    return;
                                  }
                                  await reloadVersions(setLocalState);
                                  dialogClosed = true;
                                  if (dialogContext?.mounted ?? false) {
                                    nav?.pop();
                                  }
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '已回滚到 ${item.displayVersion}',
                                        ),
                                      ),
                                    );
                                    await _loadProducts();
                                  }
                                },
                              );
                            },
                    ),
                  );
                }
                return widgets;
              },
              lifecycleLabel: _lifecycleLabel,
              formatTime: _formatTime,
            );
          },
        );
      },
    );
    dialogClosed = true;
  }

  Future<void> _loadProducts({int? page}) async {
    final targetPage = page ?? _productPage;
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await _productService.listProducts(
        page: targetPage,
        pageSize: _pageSize,
        keyword: _keywordController.text.trim(),
        category: _selectedCategoryFilter,
        lifecycleStatus: _selectedStatusFilter,
        hasEffectiveVersion: _selectedEffectiveVersionFilter == 'yes'
            ? true
            : _selectedEffectiveVersionFilter == 'no'
            ? false
            : null,
      );
      if (!mounted) {
        return;
      }
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _pageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _products = result.items;
        _total = result.total;
        _productPage = resolvedPage;
      });
      if (resolvedPage != targetPage) {
        await _loadProducts(page: resolvedPage);
      }
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

  Future<void> _exportProducts() async {
    try {
      final bytes = await _productService.exportProducts(
        keyword: _keywordController.text.trim(),
        category: _selectedCategoryFilter,
        lifecycleStatus: _selectedStatusFilter,
        hasEffectiveVersion: _selectedEffectiveVersionFilter == 'yes'
            ? true
            : _selectedEffectiveVersionFilter == 'no'
            ? false
            : null,
      );
      final location = await getSaveLocation(
        suggestedName: 'products.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) return;
      await XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/csv',
        name: 'products.csv',
      ).saveTo(location.path);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出成功：${location.path}')));
      }
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：${_errorMessage(error)}')));
    }
  }

  Future<void> _showEditProductDialog(ProductItem product) async {
    if (!widget.canCreateProduct) {
      _showPermissionDenied('编辑产品');
      return;
    }

    final nameController = TextEditingController(text: product.name);
    final remarkController = TextEditingController(text: product.remark);
    final formKey = GlobalKey<FormState>();
    String? selectedCategory =
        _productCategoryOptions.contains(product.category)
        ? product.category
        : null;

    final updated = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return MesDialog(
              title: const Text('编辑产品'),
              width: 420,
              content: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildReadonlyStatusField(
                        label: '当前状态',
                        value: _lifecycleLabel(product.lifecycleStatus),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        maxLength: 128,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        decoration: const InputDecoration(
                          labelText: '产品名称',
                          hintText: '请输入 1-128 个字符，提交时自动去除首尾空格',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateProductName,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: '产品分类',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateProductCategory,
                        items: _productCategoryOptions
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setLocalState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarkController,
                        maxLines: 3,
                        maxLength: 500,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        decoration: const InputDecoration(
                          labelText: '备注',
                          hintText: '最多 500 个字符，提交时自动去除首尾空格',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateProductRemark,
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
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await _productService.updateProduct(
                        productId: product.id,
                        name: nameController.text.trim(),
                        category: selectedCategory!,
                        remark: remarkController.text.trim(),
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
                            content: Text('编辑产品失败：${_errorMessage(error)}'),
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

    if (updated == true) {
      await _loadProducts();
    }
  }

  Future<void> _showCreateProductDialog() async {
    if (!widget.canCreateProduct) {
      _showPermissionDenied('创建产品');
      return;
    }

    final nameController = TextEditingController();
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedCategory;

    final created = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return MesDialog(
              title: const Text('添加产品'),
              width: 420,
              content: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildReadonlyStatusField(label: '默认状态', value: '启用'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        maxLength: 128,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        decoration: const InputDecoration(
                          labelText: '产品名称',
                          hintText: '请输入 1-128 个字符，提交时自动去除首尾空格',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateProductName,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: '产品分类',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateProductCategory,
                        hint: const Text('请选择产品分类'),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarkController,
                        maxLines: 3,
                        maxLength: 500,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        decoration: const InputDecoration(
                          labelText: '备注',
                          hintText: '最多 500 个字符，提交时自动去除首尾空格',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateProductRemark,
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
                        category: selectedCategory!,
                        remark: remarkController.text.trim(),
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

    final confirmed = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return MesDialog(
          title: const Text('删除产品'),
          width: 420,
          content: Form(
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

  List<PopupMenuEntry<ProductManagementTableAction>> _buildProductActionMenuItems(
    ProductItem product,
  ) {
    final items = <PopupMenuEntry<ProductManagementTableAction>>[
      const PopupMenuItem(
        value: ProductManagementTableAction.viewDetail,
        child: Text('查看详情'),
      ),
    ];
    if (widget.canUpdateLifecycle) {
      switch (product.lifecycleStatus) {
        case 'active':
        case 'effective':
          items.add(
            const PopupMenuItem(
              value: ProductManagementTableAction.deactivate,
              child: Text('停用'),
            ),
          );
          break;
        case 'inactive':
          items.add(
            const PopupMenuItem(
              value: ProductManagementTableAction.reactivate,
              child: Text('启用'),
            ),
          );
          break;
        default:
          break;
      }
    }

    final utilityItems = <PopupMenuEntry<ProductManagementTableAction>>[];
    if (widget.canCreateProduct) {
      utilityItems.add(
        const PopupMenuItem(
          value: ProductManagementTableAction.edit,
          child: Text('编辑产品'),
        ),
      );
    }
    if (widget.canViewVersions) {
      utilityItems.add(
        const PopupMenuItem(
          value: ProductManagementTableAction.version,
          child: Text('版本管理'),
        ),
      );
    }
    if (widget.canViewParameters) {
      utilityItems.add(
        const PopupMenuItem(
          value: ProductManagementTableAction.viewParams,
          child: Text('查看参数'),
        ),
      );
    }
    if (widget.canEditParameters) {
      utilityItems.add(
        const PopupMenuItem(
          value: ProductManagementTableAction.editParams,
          child: Text('编辑参数'),
        ),
      );
    }
    if (widget.canDeleteProduct) {
      utilityItems.add(
        const PopupMenuItem(
          value: ProductManagementTableAction.delete,
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
    ProductManagementTableAction action,
    ProductItem product,
  ) async {
    switch (action) {
      case ProductManagementTableAction.viewDetail:
        await _showDetailDrawer(product);
        return;
      case ProductManagementTableAction.edit:
        await _showEditProductDialog(product);
        return;
      case ProductManagementTableAction.reactivate:
        await _changeLifecycle(product, 'active');
        return;
      case ProductManagementTableAction.deactivate:
        await _changeLifecycle(product, 'inactive');
        return;
      case ProductManagementTableAction.version:
        await _showVersionDialog(product);
        return;
      case ProductManagementTableAction.viewParams:
        widget.onViewParameters(product);
        return;
      case ProductManagementTableAction.editParams:
        widget.onEditParameters(product);
        return;
      case ProductManagementTableAction.delete:
        await _deleteProduct(product);
        return;
    }
  }

  Future<void> _showDetailDrawer(ProductItem product) async {
    ProductDetailResult detail;
    try {
      detail = await _productService.getProductDetail(productId: product.id);
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
      return;
    }

    if (!mounted) return;

    String paramSearch = '';

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭产品详情侧栏',
      barrierColor: Colors.black54,
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final drawerWidth = screenWidth < 1200 ? screenWidth * 0.92 : 720.0;

            return SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 12,
                  child: SizedBox(
                    width: drawerWidth,
                    child: ProductDetailDrawer(
                      detail: detail,
                      paramSearch: paramSearch,
                      onParamSearchChanged: (value) {
                        setDialogState(() => paramSearch = value);
                      },
                      onClose: () => Navigator.of(context).pop(),
                      formatTime: _formatTime,
                      lifecycleLabel: _lifecycleLabel,
                      versionLifecycleLabel: _versionLifecycleLabel,
                      formatDisplayVersion: _formatDisplayVersion,
                      changeTypeLabel: _parameterHistoryTypeLabel,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MesCrudPageScaffold(
      header: ProductManagementPageHeader(
        loading: _loading,
        onRefresh: _loadProducts,
      ),
      filters: ProductManagementFilterSection(
        keywordController: _keywordController,
        categoryOptions: _productCategoryOptions,
        selectedCategory: _selectedCategoryFilter,
        selectedStatus: _selectedStatusFilter,
        selectedEffectiveVersion: _selectedEffectiveVersionFilter,
        loading: _loading,
        canCreateProduct: widget.canCreateProduct,
        canExportProducts: widget.canExportProducts,
        onCategoryChanged: (value) {
          setState(() {
            _selectedCategoryFilter = value;
          });
          _loadProducts(page: 1);
        },
        onStatusChanged: (value) {
          setState(() {
            _selectedStatusFilter = value;
          });
          _loadProducts(page: 1);
        },
        onEffectiveVersionChanged: (value) {
          setState(() {
            _selectedEffectiveVersionFilter = value;
          });
          _loadProducts(page: 1);
        },
        onSearch: () => _loadProducts(page: 1),
        onCreate: _showCreateProductDialog,
        onExport: _exportProducts,
      ),
      banner: _message.isEmpty
          ? null
          : ProductManagementFeedbackBanner(message: _message),
      content: ProductManagementTableSection(
        products: _products,
        loading: _loading,
        emptyText: '暂无产品',
        formatTime: _formatTime,
        buildActionItems: _buildProductActionMenuItems,
        onSelected: _handleProductTableAction,
      ),
      pagination: MesPaginationBar(
        page: _productPage,
        totalPages: _productTotalPages,
        total: _total,
        showTotal: false,
        loading: _loading,
        onPrevious: () => _loadProducts(page: _productPage - 1),
        onNext: () => _loadProducts(page: _productPage + 1),
      ),
    );
  }
}
