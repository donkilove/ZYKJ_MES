import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/widgets/software_settings_preview_card.dart';

class SoftwareSettingsPage extends StatefulWidget {
  const SoftwareSettingsPage({super.key, required this.controller});

  final SoftwareSettingsController controller;

  @override
  State<SoftwareSettingsPage> createState() => _SoftwareSettingsPageState();
}

class _SoftwareSettingsPageState extends State<SoftwareSettingsPage> {
  _SettingsSectionType _selectedSection = _SettingsSectionType.appearance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final settings = widget.controller.settings;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _PageHeader(
                  saveMessage: widget.controller.saveMessage,
                  saveFailed: widget.controller.saveFailed,
                  onRestoreDefaults: () {
                    unawaited(widget.controller.restoreDefaults());
                  },
                ),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 220,
                        child: _SectionNavigation(
                          selectedSection: _selectedSection,
                          onSelect: _handleSectionSelected,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SectionContent(
                          section: _selectedSection,
                          settings: settings,
                          controller: widget.controller,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _SectionNavigation(
                        selectedSection: _selectedSection,
                        onSelect: _handleSectionSelected,
                      ),
                      const SizedBox(height: 12),
                      _SectionContent(
                        section: _selectedSection,
                        settings: settings,
                        controller: widget.controller,
                      ),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleSectionSelected(_SettingsSectionType section) {
    if (_selectedSection == section) {
      return;
    }
    setState(() {
      _selectedSection = section;
    });
  }
}

enum _SettingsSectionType { appearance, layout }

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.saveMessage,
    required this.saveFailed,
    required this.onRestoreDefaults,
  });

  final String? saveMessage;
  final bool saveFailed;
  final VoidCallback onRestoreDefaults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusText = switch ((saveMessage, saveFailed)) {
      (null, _) => '设置变更后会自动保存',
      (_, false) => '已自动保存',
      (_, true) => saveMessage ?? '保存失败，请稍后重试',
    };
    final statusColor = saveFailed
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final textColor = saveFailed
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;
    final statusIcon = saveFailed
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '软件设置',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '控制本机软件的外观和布局偏好。',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onRestoreDefaults,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('恢复默认'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, size: 18, color: textColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionNavigation extends StatelessWidget {
  const _SectionNavigation({
    required this.selectedSection,
    required this.onSelect,
  });

  final _SettingsSectionType selectedSection;
  final ValueChanged<_SettingsSectionType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _SectionNavTile(
            title: '外观',
            subtitle: '主题、密度与预览',
            selected: selectedSection == _SettingsSectionType.appearance,
            onTap: () => onSelect(_SettingsSectionType.appearance),
          ),
          const Divider(height: 1),
          _SectionNavTile(
            title: '布局偏好',
            subtitle: '启动入口与侧边栏状态',
            selected: selectedSection == _SettingsSectionType.layout,
            onTap: () => onSelect(_SettingsSectionType.layout),
          ),
        ],
      ),
    );
  }
}

class _SectionNavTile extends StatelessWidget {
  const _SectionNavTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({
    required this.section,
    required this.settings,
    required this.controller,
  });

  final _SettingsSectionType section;
  final SoftwareSettings settings;
  final SoftwareSettingsController controller;

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case _SettingsSectionType.appearance:
        return _AppearanceSection(settings: settings, controller: controller);
      case _SettingsSectionType.layout:
        return _LayoutSection(settings: settings, controller: controller);
    }
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.settings, required this.controller});

  final SoftwareSettings settings;
  final SoftwareSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsSection(
          title: '外观',
          child: Column(
            children: [
              RadioGroup<AppThemePreference>(
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
                  if (value == null) {
                    return;
                  }
                  unawaited(controller.updateDensityPreference(value));
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

class _LayoutSection extends StatelessWidget {
  const _LayoutSection({required this.settings, required this.controller});

  final SoftwareSettings settings;
  final SoftwareSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '布局偏好',
      child: Column(
        children: [
          _GroupTitle(title: '启动后默认进入'),
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
          _GroupTitle(title: '侧边栏默认状态'),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
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
