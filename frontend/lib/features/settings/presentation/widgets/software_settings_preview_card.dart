import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';

class SoftwareSettingsPreviewCard extends StatelessWidget {
  const SoftwareSettingsPreviewCard({
    super.key,
    required this.themePreference,
    required this.densityPreference,
  });

  final AppThemePreference themePreference;
  final AppDensityPreference densityPreference;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MesSectionCard(
      title: '预览',
      subtitle: '界面效果会在修改后自动应用。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前主题：${_themeLabel(themePreference)}'),
          const SizedBox(height: 4),
          Text('当前密度：${_densityLabel(densityPreference)}'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '界面效果会在修改后自动应用。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.system:
        return '跟随系统';
      case AppThemePreference.light:
        return '浅色';
      case AppThemePreference.dark:
        return '深色';
    }
  }

  String _densityLabel(AppDensityPreference value) {
    switch (value) {
      case AppDensityPreference.comfortable:
        return '舒适';
      case AppDensityPreference.compact:
        return '紧凑';
    }
  }
}
