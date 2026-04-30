import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_history_dialog.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_history_snapshot_dialog.dart';

Future<void> showProductParameterHistoryFlowDialog({
  required BuildContext context,
  required ProductParameterVersionListItem row,
  required Future<ProductParameterHistoryListResult> Function(int page)
  loadHistoryPage,
  required String Function(DateTime value) formatTime,
  required String Function(String value) historyTypeLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return _ProductParameterHistoryDialogHost(
        row: row,
        loadHistoryPage: loadHistoryPage,
        formatTime: formatTime,
        historyTypeLabel: historyTypeLabel,
      );
    },
  );
}

class _ProductParameterHistoryDialogHost extends StatefulWidget {
  const _ProductParameterHistoryDialogHost({
    required this.row,
    required this.loadHistoryPage,
    required this.formatTime,
    required this.historyTypeLabel,
  });

  final ProductParameterVersionListItem row;
  final Future<ProductParameterHistoryListResult> Function(int page)
  loadHistoryPage;
  final String Function(DateTime value) formatTime;
  final String Function(String value) historyTypeLabel;

  @override
  State<_ProductParameterHistoryDialogHost> createState() =>
      _ProductParameterHistoryDialogHostState();
}

class _ProductParameterHistoryDialogHostState
    extends State<_ProductParameterHistoryDialogHost> {
  static const int _pageSize = 30;

  ProductParameterHistoryListResult? _history;
  int _page = 1;
  bool _loading = true;

  int get _totalPages {
    final total = _history?.total ?? 0;
    if (total <= 0) {
      return 1;
    }
    return ((total - 1) ~/ _pageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    setState(() {
      _loading = true;
    });
    final result = await widget.loadHistoryPage(page);
    if (!mounted) {
      return;
    }
    setState(() {
      _history = result;
      _page = page;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    if (_loading || history == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ProductParameterHistoryDialog(
      row: widget.row,
      history: history,
      formatTime: widget.formatTime,
      historyTypeLabel: widget.historyTypeLabel,
      onClose: () => Navigator.of(context).pop(),
      onViewSnapshot: (item) {
        showDialog<void>(
          context: context,
          builder: (snapshotContext) {
            return ProductParameterHistorySnapshotDialog(
              item: item,
              onClose: () => Navigator.of(snapshotContext).pop(),
            );
          },
        );
      },
      page: _page,
      totalPages: _totalPages,
      onPreviousPage: _page > 1 ? () => _loadPage(_page - 1) : null,
      onNextPage: _page < _totalPages ? () => _loadPage(_page + 1) : null,
    );
  }
}

Future<bool> showProductParameterDiscardDialog({
  required BuildContext context,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return MesActionDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('当前编辑内容尚未保存，离开后将丢失本次修改。'),
        cancelLabel: '继续编辑',
        confirmLabel: '放弃修改',
        isDestructive: true,
        onConfirm: () => Navigator.of(context).pop(true),
      );
    },
  );
  return confirmed ?? false;
}

Future<bool> showProductParameterImpactDialog({
  required BuildContext context,
  required ProductImpactAnalysisResult impact,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return MesActionDialog(
        title: const Text('变更影响确认'),
        width: 520,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '存在 ${impact.totalOrders} 条未完工订单（待开工 ${impact.pendingOrders}，生产中 ${impact.inProgressOrders}）。',
            ),
            const SizedBox(height: 8),
            const Text('确认后将按强制模式继续保存。'),
          ],
        ),
        confirmLabel: '确认继续',
        onConfirm: () => Navigator.of(context).pop(true),
      );
    },
  );
  return confirmed ?? false;
}
