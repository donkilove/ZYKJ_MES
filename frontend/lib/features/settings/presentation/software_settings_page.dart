import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';

class SoftwareSettingsPage extends StatelessWidget {
  const SoftwareSettingsPage({super.key, required this.controller});

  final SoftwareSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '软件设置',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text('控制本机软件的外观和布局偏好。', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            _SettingsSection(
              title: '外观',
              child: RadioGroup<AppThemePreference>(
                groupValue: settings.themePreference,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  unawaited(controller.updateThemePreference(value));
                },
                child: const Column(
                  children: [
                    RadioListTile<AppThemePreference>(
                      title: Text('跟随系统'),
                      value: AppThemePreference.system,
                    ),
                    RadioListTile<AppThemePreference>(
                      title: Text('浅色模式'),
                      value: AppThemePreference.light,
                    ),
                    RadioListTile<AppThemePreference>(
                      title: Text('深色模式'),
                      value: AppThemePreference.dark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsSection(
              title: '布局偏好',
              child: Column(
                children: [
                  RadioGroup<AppSidebarPreference>(
                    groupValue: settings.sidebarPreference,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      unawaited(controller.updateSidebarPreference(value));
                    },
                    child: const Column(
                      children: [
                        RadioListTile<AppSidebarPreference>(
                          title: Text('侧边栏默认展开'),
                          value: AppSidebarPreference.expanded,
                        ),
                        RadioListTile<AppSidebarPreference>(
                          title: Text('侧边栏默认折叠'),
                          value: AppSidebarPreference.collapsed,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  RadioGroup<AppLaunchTargetPreference>(
                    groupValue: settings.launchTargetPreference,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      unawaited(controller.updateLaunchTargetPreference(value));
                    },
                    child: const Column(
                      children: [
                        RadioListTile<AppLaunchTargetPreference>(
                          title: Text('启动后默认进入：首页'),
                          value: AppLaunchTargetPreference.home,
                        ),
                        RadioListTile<AppLaunchTargetPreference>(
                          title: Text('启动后默认进入：上次停留模块'),
                          value: AppLaunchTargetPreference.lastVisitedModule,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  RadioGroup<AppDensityPreference>(
                    groupValue: settings.densityPreference,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      unawaited(controller.updateDensityPreference(value));
                    },
                    child: const Column(
                      children: [
                        RadioListTile<AppDensityPreference>(
                          title: Text('界面密度：舒适'),
                          value: AppDensityPreference.comfortable,
                        ),
                        RadioListTile<AppDensityPreference>(
                          title: Text('界面密度：紧凑'),
                          value: AppDensityPreference.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
