import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class LoginSessionPageHeader extends StatelessWidget {
  const LoginSessionPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
    required this.keywordController,
    required this.onSearch,
    required this.allCurrentPageSelected,
    required this.someCurrentPageSelected,
    required this.hasSelectableSessions,
    required this.onToggleSelectCurrentPage,
    required this.canForceOffline,
    required this.selectedCount,
    required this.onForceOfflineBatch,
  });

  final VoidCallback onRefresh;
  final bool loading;
  final TextEditingController keywordController;
  final VoidCallback onSearch;
  final bool allCurrentPageSelected;
  final bool someCurrentPageSelected;
  final bool hasSelectableSessions;
  final ValueChanged<bool?> onToggleSelectCurrentPage;
  final bool canForceOffline;
  final int selectedCount;
  final VoidCallback onForceOfflineBatch;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('login-session-page-header'),
      child: MesRefreshPageHeader(
        onRefresh: loading ? null : onRefresh,
        leading: KeyedSubtree(
          key: const ValueKey('login-session-filter-section'),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: keywordController,
                  decoration: const InputDecoration(
                    labelText: '关键词',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              FilledButton(
                onPressed: loading ? null : onSearch,
                child: const Text('查询'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: allCurrentPageSelected
                        ? true
                        : (someCurrentPageSelected ? null : false),
                    tristate: true,
                    onChanged: hasSelectableSessions
                        ? onToggleSelectCurrentPage
                        : null,
                  ),
                  const Text('全选当前页'),
                ],
              ),
              FilledButton(
                onPressed: canForceOffline && selectedCount > 0
                    ? onForceOfflineBatch
                    : null,
                child: Text('批量强制下线（$selectedCount）'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
