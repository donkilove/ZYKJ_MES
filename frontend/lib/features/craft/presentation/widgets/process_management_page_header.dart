import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_view_switch.dart';

enum _ProcessManagementCreateAction { createStage, createProcess }

class ProcessManagementPageHeader extends StatelessWidget {
  const ProcessManagementPageHeader({
    super.key,
    required this.loading,
    required this.canWrite,
    required this.activeView,
    required this.searchController,
    required this.searchHintText,
    required this.stageFilter,
    required this.stageOptions,
    required this.stageFilterEnabled,
    required this.onKeywordChanged,
    required this.onStageFilterChanged,
    required this.onSearch,
    required this.onViewChanged,
    required this.onRefresh,
    required this.onCreateStage,
    required this.onCreateProcess,
  });

  final bool loading;
  final bool canWrite;
  final ProcessManagementPrimaryView activeView;
  final TextEditingController searchController;
  final String searchHintText;
  final int? stageFilter;
  final List<CraftStageItem> stageOptions;
  final bool stageFilterEnabled;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<int?> onStageFilterChanged;
  final VoidCallback onSearch;
  final ValueChanged<ProcessManagementPrimaryView> onViewChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCreateStage;
  final VoidCallback onCreateProcess;

  @override
  Widget build(BuildContext context) {
    return MesRefreshPageHeader(
      leading: Row(
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              key: const ValueKey('process-management-search-field'),
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 16),
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                hintText: searchHintText,
              ),
              onChanged: onKeywordChanged,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: DropdownButton<int?>(
              key: const ValueKey('process-management-stage-filter'),
              value: stageFilter,
              isDense: true,
              hint: const Text('全部工段'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('全部工段')),
                ...stageOptions.map(
                  (item) => DropdownMenuItem<int?>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                ),
              ],
              onChanged: stageFilterEnabled && !loading
                  ? onStageFilterChanged
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: loading ? null : onSearch,
            child: const Text('查询'),
          ),
        ],
      ),
      onRefresh: loading ? null : onRefresh,
      actionsBeforeRefresh: [
        ProcessManagementViewSwitch(
          activeView: activeView,
          onChanged: onViewChanged,
        ),
        PopupMenuButton<_ProcessManagementCreateAction>(
          key: const ValueKey('process-management-create-menu'),
          tooltip: '新建',
          enabled: canWrite && !loading,
          onSelected: (value) {
            switch (value) {
              case _ProcessManagementCreateAction.createStage:
                onCreateStage();
                return;
              case _ProcessManagementCreateAction.createProcess:
                onCreateProcess();
                return;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<_ProcessManagementCreateAction>(
              value: _ProcessManagementCreateAction.createStage,
              child: Text('新建工段'),
            ),
            PopupMenuItem<_ProcessManagementCreateAction>(
              value: _ProcessManagementCreateAction.createProcess,
              child: Text('新建工序'),
            ),
          ],
          icon: const Icon(Icons.more_horiz),
        ),
      ],
    );
  }
}
