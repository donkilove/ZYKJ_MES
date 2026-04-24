import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';

class MessageCenterListSection extends StatelessWidget {
  const MessageCenterListSection({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.body,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
  });

  final bool loading;
  final String error;
  final bool isEmpty;
  final Widget body;
  final int page;
  final int totalPages;
  final int total;
  final VoidCallback onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final content = loading && isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error.isNotEmpty && isEmpty
        ? MesErrorState(message: error, onRetry: onRetry)
        : isEmpty
        ? const MesEmptyState(title: '暂无消息')
        : body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading && !isEmpty) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
        ],
        Expanded(child: ClipRect(child: content)),
        const SizedBox(height: 12),
        MesPaginationBar(
          page: page,
          totalPages: totalPages,
          total: total,
          loading: loading,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
  }
}
