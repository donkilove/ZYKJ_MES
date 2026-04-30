import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
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

  Widget _buildStunningEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_read_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '这里风平浪静',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '暂无任何消息，您可以稍后再来查看',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = loading && isEmpty
        ? const MesLoadingState()
        : error.isNotEmpty && isEmpty
        ? MesErrorState(message: error, onRetry: onRetry)
        : isEmpty
        ? _buildStunningEmptyState(theme)
        : body;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactScroll = constraints.maxHeight < 140;
        final pagination = MesPaginationBar(
          page: page,
          totalPages: totalPages,
          total: total,
          loading: loading,
          onPrevious: onPrevious,
          onNext: onNext,
        );
        if (useCompactScroll) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loading && !isEmpty) ...[
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(height: 96, child: ClipRect(child: content)),
                  const SizedBox(height: 8),
                  pagination,
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading && !isEmpty) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 12),
            ],
            Expanded(child: ClipRect(child: content)),
            const SizedBox(height: 12),
            pagination,
          ],
        );
      },
    );
  }
}
