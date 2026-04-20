import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/widgets/software_settings_preview_card.dart';

class SoftwareSettingsAppearanceSection extends StatelessWidget {
  const SoftwareSettingsAppearanceSection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final SoftwareSettings settings;
  final SoftwareSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MesSectionCard(
          title: '外观',
          child: Column(
            children: [
              RadioGroup<AppThemePreference>(
                groupValue: settings.themePreference,
                onChanged: (value) {
                  if (value != null) {
                    unawaited(controller.updateThemePreference(value));
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<AppThemePreference>(
                      title: Text('跟随系统'),
                      value: AppThemePreference.system,
                    ),
                    RadioListTile<AppThemePreference>(
                      title: Text('浅色'),
                      value: AppThemePreference.light,
                    ),
                    RadioListTile<AppThemePreference>(
                      title: Text('深色'),
                      value: AppThemePreference.dark,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              RadioGroup<AppDensityPreference>(
                groupValue: settings.densityPreference,
                onChanged: (value) {
                  if (value != null) {
                    unawaited(controller.updateDensityPreference(value));
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<AppDensityPreference>(
                      title: Text('舒适'),
                      value: AppDensityPreference.comfortable,
                    ),
                    RadioListTile<AppDensityPreference>(
                      title: Text('紧凑'),
                      value: AppDensityPreference.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftwareSettingsPreviewCard(
          themePreference: settings.themePreference,
          densityPreference: settings.densityPreference,
        ),
      ],
    );
  }
}

class SoftwareSettingsLayoutSection extends StatelessWidget {
  const SoftwareSettingsLayoutSection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final SoftwareSettings settings;
  final SoftwareSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return MesSectionCard(
      title: '布局偏好',
      child: Column(
        children: [
          const _GroupTitle(title: '启动后默认进入'),
          RadioGroup<AppLaunchTargetPreference>(
            groupValue: settings.launchTargetPreference,
            onChanged: (value) {
              if (value != null) {
                unawaited(controller.updateLaunchTargetPreference(value));
              }
            },
            child: const Column(
              children: [
                RadioListTile<AppLaunchTargetPreference>(
                  title: Text('首页'),
                  value: AppLaunchTargetPreference.home,
                ),
                RadioListTile<AppLaunchTargetPreference>(
                  title: Text('上次停留模块'),
                  value: AppLaunchTargetPreference.lastVisitedModule,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const _GroupTitle(title: '侧边栏默认状态'),
          RadioGroup<AppSidebarPreference>(
            groupValue: settings.sidebarPreference,
            onChanged: (value) {
              if (value != null) {
                unawaited(controller.updateSidebarPreference(value));
              }
            },
            child: const Column(
              children: [
                RadioListTile<AppSidebarPreference>(
                  title: Text('展开'),
                  value: AppSidebarPreference.expanded,
                ),
                RadioListTile<AppSidebarPreference>(
                  title: Text('折叠'),
                  value: AppSidebarPreference.collapsed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
