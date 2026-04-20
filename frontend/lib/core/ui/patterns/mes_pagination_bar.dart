import 'package:flutter/material.dart';

class MesPaginationBar extends StatelessWidget {
  const MesPaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.loading,
    this.showTotal = true,
    this.onPrevious,
    this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final bool loading;
  final bool showTotal;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('第 $page / $totalPages 页'),
        if (showTotal) ...[const SizedBox(width: 12), Text('总数：$total')],
        const Spacer(),
        OutlinedButton.icon(
          onPressed: loading || page <= 1 ? null : onPrevious,
          icon: const Icon(Icons.chevron_left),
          label: const Text('上一页'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: loading || page >= totalPages ? null : onNext,
          icon: const Icon(Icons.chevron_right),
          label: const Text('下一页'),
        ),
      ],
    );
  }
}
