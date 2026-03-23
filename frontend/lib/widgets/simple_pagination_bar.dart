import 'package:flutter/material.dart';

class SimplePaginationBar extends StatelessWidget {
  static const double _compactBreakpoint = 720;
  static const double _buttonMinWidth = 108;
  static const double _selectorMinWidth = 128;

  const SimplePaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.loading,
    this.onPrevious,
    this.onNext,
    this.pageSize,
    this.pageSizeOptions = const [],
    this.onPageChanged,
    this.onPageSizeChanged,
  });

  final int page;
  final int totalPages;
  final int total;
  final bool loading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int? pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;

  List<int> get _normalizedPageSizeOptions {
    final options = <int>{...pageSizeOptions};
    if (pageSize != null) {
      options.add(pageSize!);
    }
    final normalized = options.where((value) => value > 0).toList()..sort();
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageSizeOptions = _normalizedPageSizeOptions;
    final paginationInfo = Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('第 $page / $totalPages 页'),
        if (pageSize != null) Text('每页 $pageSize 条'),
        Text('总数：$total'),
        if (loading)
          Text(
            '加载中...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );

    final paginationActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (onPageChanged != null && totalPages > 1)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _selectorMinWidth),
            child: DropdownButton<int>(
              key: const Key('simple-pagination-page-selector'),
              value: page,
              isDense: true,
              items: List.generate(totalPages, (index) => index + 1).map((
                value,
              ) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('第 $value 页'),
                );
              }).toList(),
              onChanged: loading
                  ? null
                  : (value) {
                      if (value != null && value != page) {
                        onPageChanged?.call(value);
                      }
                    },
            ),
          ),
        if (pageSize != null &&
            onPageSizeChanged != null &&
            pageSizeOptions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _selectorMinWidth),
            child: DropdownButton<int>(
              key: const Key('simple-pagination-page-size-selector'),
              value: pageSize,
              isDense: true,
              items: pageSizeOptions.map((value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value 条/页'),
                );
              }).toList(),
              onChanged: loading
                  ? null
                  : (value) {
                      if (value != null && value != pageSize) {
                        onPageSizeChanged?.call(value);
                      }
                    },
            ),
          ),
        SizedBox(
          width: _buttonMinWidth,
          child: OutlinedButton.icon(
            onPressed: loading || page <= 1 ? null : onPrevious,
            icon: const Icon(Icons.chevron_left),
            label: const Text('上一页'),
          ),
        ),
        SizedBox(
          width: _buttonMinWidth,
          child: OutlinedButton.icon(
            onPressed: loading || page >= totalPages ? null : onNext,
            icon: const Icon(Icons.chevron_right),
            label: const Text('下一页'),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _compactBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              paginationInfo,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: paginationActions),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: paginationInfo),
            const SizedBox(width: 16),
            Flexible(child: paginationActions),
          ],
        );
      },
    );
  }
}
