import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

class MesMetricCard extends StatelessWidget {
  const MesMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    return MesSurface(
      tone: MesSurfaceTone.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tokens?.typography.caption ?? theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style:
                tokens?.typography.metric ??
                theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: tokens?.typography.caption ?? theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
