import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';

class SoftwareTimeSyncSection extends StatelessWidget {
  const SoftwareTimeSyncSection({
    super.key,
    required this.softwareSettingsController,
    required this.timeSyncController,
    required this.apiBaseUrl,
  });

  final SoftwareSettingsController softwareSettingsController;
  final TimeSyncController timeSyncController;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final settings = softwareSettingsController.settings;
    final state = timeSyncController.state;
    return MesSectionCard(
      title: '时间同步',
      subtitle: '服务器对时、系统改时与软件内校准',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSwitchCard(settings.timeSyncEnabled),
          const SizedBox(height: 12),
          _buildSummaryCard(state),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: settings.timeSyncEnabled
                    ? () => unawaited(
                        timeSyncController.checkAtStartup(
                          baseUrl: apiBaseUrl,
                          force: true,
                        ),
                      )
                    : null,
                child: const Text('立即检查并同步'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: settings.timeSyncEnabled
                    ? () => unawaited(
                        timeSyncController.calibrateSoftwareClock(
                          baseUrl: apiBaseUrl,
                        ),
                      )
                    : null,
                child: const Text('仅重新校准软件内时间'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchCard(bool enabled) {
    return SwitchListTile(
      title: const Text('启用时间同步'),
      subtitle: const Text('启动时自动检查并在偏差超阈值时尝试修正 Windows 时间'),
      value: enabled,
      onChanged: (value) {
        unawaited(softwareSettingsController.updateTimeSyncEnabled(value));
      },
    );
  }

  Widget _buildSummaryCard(TimeSyncState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('同步策略摘要'),
          const SizedBox(height: 8),
          const Text('权威时间源：后端服务器时间'),
          const Text('自动修正阈值：30 秒'),
          if (state.serverUtc != null)
            Text('服务器时间：${_formatDateTime(state.serverUtc!)}'),
          if (state.localUtc != null)
            Text('本机时间：${_formatDateTime(state.localUtc!)}'),
          Text('当前模式：${_modeLabel(state.mode)}'),
          if (state.drift != null)
            Text('当前偏差：${state.drift!.inSeconds.abs()} 秒'),
          Text('最近同步结果：${_resultLabel(state.lastResultCode)}'),
          if (state.lastCheckedAt != null)
            Text('最近同步时间：${_formatDateTime(state.lastCheckedAt!)}'),
          if (state.message != null) Text(state.message!),
        ],
      ),
    );
  }

  String _modeLabel(TimeSyncMode mode) {
    switch (mode) {
      case TimeSyncMode.disabled:
        return '未启用';
      case TimeSyncMode.systemTimeOk:
        return '系统时间同步';
      case TimeSyncMode.systemTimeCorrected:
        return '已自动修正';
      case TimeSyncMode.softwareTimeCalibrated:
        return '软件内校准';
      case TimeSyncMode.unavailable:
        return '不可用';
    }
  }

  String _resultLabel(TimeSyncResultCode code) {
    switch (code) {
      case TimeSyncResultCode.idle:
        return '尚未执行';
      case TimeSyncResultCode.success:
        return '系统时间已修正';
      case TimeSyncResultCode.skippedWithinThreshold:
        return '偏差未超过阈值';
      case TimeSyncResultCode.cancelledByUser:
        return '用户取消管理员授权';
      case TimeSyncResultCode.permissionDenied:
        return '系统拒绝改时';
      case TimeSyncResultCode.syncFailed:
        return '系统改时失败';
      case TimeSyncResultCode.serverTimeUnavailable:
        return '服务器时间不可用';
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }
}
