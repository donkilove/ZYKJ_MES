import 'package:flutter/material.dart';

class CrudPageHeader extends StatelessWidget {
  static const double _buttonSize = 40;

  const CrudPageHeader({super.key, required this.title, this.onRefresh});

  final String title;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: '刷新',
            child: SizedBox(
              width: _buttonSize,
              height: _buttonSize,
              child: IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
