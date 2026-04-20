import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

class MesStatusChip extends StatelessWidget {
  const MesStatusChip._({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  factory MesStatusChip.success({Key? key, required String label}) {
    return MesStatusChip._(
      key: key,
      label: label,
      backgroundColor: const Color(0xFFE4F5EC),
      foregroundColor: const Color(0xFF1B8A5A),
    );
  }

  factory MesStatusChip.warning({Key? key, required String label}) {
    return MesStatusChip._(
      key: key,
      label: label,
      backgroundColor: const Color(0xFFFFF1D6),
      foregroundColor: const Color(0xFFB97100),
    );
  }

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MesTokens>()!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: tokens.radius.lg,
      ),
      child: Text(
        label,
        style: tokens.typography.caption.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
