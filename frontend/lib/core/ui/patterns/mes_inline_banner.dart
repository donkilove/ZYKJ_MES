import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

enum MesInlineBannerTone { info, warning, error, success }

class MesInlineBanner extends StatelessWidget {
  const MesInlineBanner._({
    super.key,
    required this.message,
    required this.tone,
  });

  const MesInlineBanner.info({Key? key, required String message})
    : this._(key: key, message: message, tone: MesInlineBannerTone.info);

  const MesInlineBanner.warning({Key? key, required String message})
    : this._(key: key, message: message, tone: MesInlineBannerTone.warning);

  const MesInlineBanner.error({Key? key, required String message})
    : this._(key: key, message: message, tone: MesInlineBannerTone.error);

  const MesInlineBanner.success({Key? key, required String message})
    : this._(key: key, message: message, tone: MesInlineBannerTone.success);

  final String message;
  final MesInlineBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    final color = switch (tone) {
      MesInlineBannerTone.info =>
        tokens?.colors.info ?? theme.colorScheme.primary,
      MesInlineBannerTone.warning =>
        tokens?.colors.warning ?? const Color(0xFFB97100),
      MesInlineBannerTone.error =>
        tokens?.colors.danger ?? theme.colorScheme.error,
      MesInlineBannerTone.success =>
        tokens?.colors.success ?? const Color(0xFF1B8A5A),
    };
    final icon = switch (tone) {
      MesInlineBannerTone.info => Icons.info_outline_rounded,
      MesInlineBannerTone.warning => Icons.warning_amber_rounded,
      MesInlineBannerTone.error => Icons.error_outline_rounded,
      MesInlineBannerTone.success => Icons.check_circle_outline_rounded,
    };
    return MesSurface(
      tone: MesSurfaceTone.subtle,
      padding: EdgeInsets.symmetric(
        horizontal: tokens?.spacing.md ?? 16,
        vertical: tokens?.spacing.sm ?? 12,
      ),
      border: BorderSide(color: color.withValues(alpha: 0.35)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: tokens?.spacing.sm ?? 12),
          Expanded(
            child: Text(
              message,
              style: (tokens?.typography.body ?? theme.textTheme.bodyMedium)
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
