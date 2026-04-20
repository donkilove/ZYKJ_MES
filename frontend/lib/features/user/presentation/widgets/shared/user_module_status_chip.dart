import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';

enum UserModuleStatusTone {
  online,
  offline,
  active,
  inactive,
  deleted,
  pending,
  approved,
  rejected,
}

class UserModuleStatusChip extends StatelessWidget {
  const UserModuleStatusChip({
    super.key,
    required this.tone,
    required this.label,
  });

  final UserModuleStatusTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return switch (tone) {
      UserModuleStatusTone.online => MesStatusChip.success(label: label),
      UserModuleStatusTone.active => MesStatusChip.success(label: label),
      UserModuleStatusTone.approved => MesStatusChip.success(label: label),
      UserModuleStatusTone.offline => MesStatusChip.warning(label: label),
      UserModuleStatusTone.inactive => MesStatusChip.warning(label: label),
      UserModuleStatusTone.deleted => MesStatusChip.warning(label: label),
      UserModuleStatusTone.pending => MesStatusChip.warning(label: label),
      UserModuleStatusTone.rejected => MesStatusChip.warning(label: label),
    };
  }
}
