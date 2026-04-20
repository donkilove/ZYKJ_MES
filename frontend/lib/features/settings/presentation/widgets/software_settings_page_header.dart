import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';

class SoftwareSettingsPageHeader extends StatelessWidget {
  const SoftwareSettingsPageHeader({
    super.key,
    required this.saveMessage,
    required this.saveFailed,
    required this.onRestoreDefaults,
  });

  final String? saveMessage;
  final bool saveFailed;
  final VoidCallback onRestoreDefaults;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '软件设置',
      subtitle: '控制本机软件的外观、布局和时间同步偏好。',
      actions: [
        if (saveMessage != null)
          saveFailed
              ? MesStatusChip.warning(label: saveMessage!)
              : MesStatusChip.success(label: saveMessage!),
        OutlinedButton.icon(
          onPressed: onRestoreDefaults,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('恢复默认'),
        ),
      ],
    );
  }
}
