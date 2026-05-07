import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class FunctionPermissionConfigPageHeader extends StatelessWidget {
  const FunctionPermissionConfigPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
    required this.moduleCodes,
    required this.selectedModuleCode,
    required this.moduleLabelBuilder,
    required this.onModuleChanged,
    required this.onSave,
    required this.canSave,
    required this.saving,
  });

  final VoidCallback onRefresh;
  final bool loading;
  final List<String> moduleCodes;
  final String? selectedModuleCode;
  final String Function(String moduleCode) moduleLabelBuilder;
  final ValueChanged<String?> onModuleChanged;
  final VoidCallback onSave;
  final bool canSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('function-permission-config-page-header'),
      child: MesRefreshPageHeader(
        onRefresh: loading ? null : onRefresh,
        leading: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const ValueKey('function-permission-module-selector'),
                initialValue: selectedModuleCode,
                decoration: const InputDecoration(
                  labelText: '模块',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: moduleCodes
                    .map(
                      (code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(moduleLabelBuilder(code)),
                      ),
                    )
                    .toList(),
                onChanged: saving ? null : onModuleChanged,
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              container: true,
              label: '功能权限配置保存按钮',
              button: true,
              child: FilledButton.icon(
                onPressed: canSave ? onSave : null,
                icon: const Icon(Icons.save),
                label: Text(saving ? '保存中...' : '保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
