import 'package:flutter/material.dart';

import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

class ProcessManagementViewSwitch extends StatelessWidget {
  const ProcessManagementViewSwitch({
    super.key,
    required this.activeView,
    required this.onChanged,
  });

  final ProcessManagementPrimaryView activeView;
  final ValueChanged<ProcessManagementPrimaryView> onChanged;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('process-management-view-switch'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonal(
            key: const ValueKey('process-view-switch-process'),
            onPressed: activeView == ProcessManagementPrimaryView.processList
                ? null
                : () => onChanged(ProcessManagementPrimaryView.processList),
            child: const Text('工序列表'),
          ),
          FilledButton.tonal(
            key: const ValueKey('process-view-switch-stage'),
            onPressed: activeView == ProcessManagementPrimaryView.stageList
                ? null
                : () => onChanged(ProcessManagementPrimaryView.stageList),
            child: const Text('工段列表'),
          ),
        ],
      ),
    );
  }
}
