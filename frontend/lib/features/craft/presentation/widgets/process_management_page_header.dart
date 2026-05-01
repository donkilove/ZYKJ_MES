import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

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
    return MesRefreshPageHeader(
      title: '工序管理',
      onRefresh: loading ? null : onRefresh,
      actionsBeforeRefresh: [
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
