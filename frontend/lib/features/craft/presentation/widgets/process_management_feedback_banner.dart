import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/primitives/mes_surface.dart';

class ProcessManagementFeedbackBanner extends StatelessWidget {
  const ProcessManagementFeedbackBanner({
    super.key,
    required this.message,
    required this.jumpNotice,
  });

  final String message;
  final String jumpNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = message.trim().isNotEmpty;
    final hasJump = jumpNotice.trim().isNotEmpty;
    final text = hasError ? message.trim() : jumpNotice.trim();

    return KeyedSubtree(
      key: const ValueKey('process-management-feedback-banner'),
      child: !hasError && !hasJump
          ? const SizedBox.shrink()
          : MesSurface(
              tone: hasError ? MesSurfaceTone.normal : MesSurfaceTone.subtle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hasError
                        ? Icons.error_outline_rounded
                        : Icons.assistant_direction_outlined,
                    color: hasError ? theme.colorScheme.error : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: hasError
                          ? theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            )
                          : theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
