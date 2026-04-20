import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/widgets/software_settings_content_sections.dart';
import 'package:mes_client/features/settings/presentation/widgets/software_settings_page_header.dart';
import 'package:mes_client/features/settings/presentation/widgets/software_time_sync_section.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';

class SoftwareSettingsPage extends StatefulWidget {
  const SoftwareSettingsPage({
    super.key,
    required this.controller,
    required this.timeSyncController,
    required this.apiBaseUrl,
  });

  final SoftwareSettingsController controller;
  final TimeSyncController timeSyncController;
  final String apiBaseUrl;

  @override
  State<SoftwareSettingsPage> createState() => _SoftwareSettingsPageState();
}

class _SoftwareSettingsPageState extends State<SoftwareSettingsPage> {
  _SettingsSectionType _selectedSection = _SettingsSectionType.appearance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        widget.timeSyncController,
      ]),
      builder: (context, _) {
        final settings = widget.controller.settings;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SoftwareSettingsPageHeader(
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
                          timeSyncController: widget.timeSyncController,
                          apiBaseUrl: widget.apiBaseUrl,
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
                        timeSyncController: widget.timeSyncController,
                        apiBaseUrl: widget.apiBaseUrl,
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

enum _SettingsSectionType { appearance, layout, timeSync }

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
          const Divider(height: 1),
          _SectionNavTile(
            title: '时间同步',
            subtitle: '服务器对时与系统改时',
            selected: selectedSection == _SettingsSectionType.timeSync,
            onTap: () => onSelect(_SettingsSectionType.timeSync),
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
    required this.timeSyncController,
    required this.apiBaseUrl,
  });

  final _SettingsSectionType section;
  final SoftwareSettings settings;
  final SoftwareSettingsController controller;
  final TimeSyncController timeSyncController;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case _SettingsSectionType.appearance:
        return SoftwareSettingsAppearanceSection(
          settings: settings,
          controller: controller,
        );
      case _SettingsSectionType.layout:
        return SoftwareSettingsLayoutSection(
          settings: settings,
          controller: controller,
        );
      case _SettingsSectionType.timeSync:
        return SoftwareTimeSyncSection(
          softwareSettingsController: controller,
          timeSyncController: timeSyncController,
          apiBaseUrl: apiBaseUrl,
        );
    }
  }
}
