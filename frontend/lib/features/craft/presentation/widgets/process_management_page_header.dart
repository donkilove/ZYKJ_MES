import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProcessManagementPageHeader extends StatelessWidget {
  const ProcessManagementPageHeader({
    super.key,
    required this.loading,
    required this.canWrite,
    required this.onRefresh,
    required this.onCreateStage,
    required this.onCreateProcess,
  });

  final bool loading;
  final bool canWrite;
  final VoidCallback onRefresh;
  final VoidCallback onCreateStage;
  final VoidCallback onCreateProcess;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '工序管理',
      subtitle: '统一维护工段、小工序及 jump 定位工作台。',
      actions: [
        OutlinedButton.icon(
          key: const ValueKey('process-management-refresh-button'),
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
        FilledButton.icon(
          key: const ValueKey('process-management-create-stage-button'),
          onPressed: loading || !canWrite ? null : onCreateStage,
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('新建工段'),
        ),
        FilledButton.icon(
          key: const ValueKey('process-management-create-process-button'),
          onPressed: loading || !canWrite ? null : onCreateProcess,
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('新建工序'),
        ),
      ],
    );
  }
}
