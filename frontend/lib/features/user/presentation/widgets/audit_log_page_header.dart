import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class AuditLogPageHeader extends StatelessWidget {
  const AuditLogPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
    required this.operatorController,
    required this.onPickDateRange,
    required this.onClearDateRange,
    required this.onSearch,
    required this.startTime,
    required this.endTime,
  });

  final VoidCallback onRefresh;
  final bool loading;
  final TextEditingController operatorController;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;
  final VoidCallback onSearch;
  final DateTime? startTime;
  final DateTime? endTime;

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('audit-log-page-header'),
      child: MesRefreshPageHeader(
        onRefresh: loading ? null : onRefresh,
        leading: KeyedSubtree(
          key: const ValueKey('audit-log-filter-section'),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: operatorController,
                  decoration: const InputDecoration(
                    labelText: '操作人账号',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onPickDateRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  startTime != null && endTime != null
                      ? '${_formatDate(startTime)} ~ ${_formatDate(endTime)}'
                      : '选择时间范围',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              if (startTime != null) ...[
                IconButton(
                  onPressed: onClearDateRange,
                  icon: const Icon(Icons.clear, size: 16),
                  tooltip: '清除时间范围',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton(
                onPressed: loading ? null : onSearch,
                child: const Text('查询'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
