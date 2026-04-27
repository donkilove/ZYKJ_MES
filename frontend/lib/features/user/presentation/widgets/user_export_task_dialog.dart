import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/services/user_service.dart';

class UserExportTaskDialog extends StatefulWidget {
  const UserExportTaskDialog({
    super.key,
    required this.userService,
    required this.onLogout,
    required this.saveExportFile,
    this.highlightTaskId,
  });

  final UserService userService;
  final VoidCallback onLogout;
  final Future<String?> Function({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    required String format,
  })
  saveExportFile;
  final int? highlightTaskId;

  @override
  State<UserExportTaskDialog> createState() => UserExportTaskDialogState();
}

class UserExportTaskDialogState extends State<UserExportTaskDialog> {
  static const Duration _pollInterval = Duration(seconds: 3);

  Timer? _pollTimer;
  bool _loading = true;
  String _error = '';
  String _notice = '';
  int? _downloadingTaskId;
  List<UserExportTaskItem> _tasks = const [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool _isTaskPending(UserExportTaskItem task) =>
      task.status == 'pending' || task.status == 'processing';

  String _taskStatusLabel(String status) {
    switch (status) {
      case 'processing':
        return '生成中';
      case 'succeeded':
        return '可下载';
      case 'failed':
        return '失败';
      case 'expired':
        return '已过期';
      case 'pending':
      default:
        return '排队中';
    }
  }

  String _deletedScopeLabel(String deletedScope) {
    switch (deletedScope) {
      case 'deleted':
        return '仅已删除';
      case 'all':
        return '全部用户';
      case 'active':
      default:
        return '常规用户';
    }
  }

  Color _taskStatusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'succeeded':
        return Colors.green;
      case 'failed':
      case 'expired':
        return scheme.error;
      case 'processing':
        return Colors.orange;
      case 'pending':
      default:
        return scheme.primary;
    }
  }

  String _formatTaskTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  void _schedulePollingIfNeeded() {
    _pollTimer?.cancel();
    if (_tasks.any(_isTaskPending)) {
      _pollTimer = Timer(_pollInterval, () => _loadTasks(silent: true));
    }
  }

  Future<void> _loadTasks({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final result = await widget.userService.listUserExportTasks();
      if (!mounted) {
        return;
      }
      setState(() {
        _tasks = result.items;
        _loading = false;
        _error = '';
      });
      _schedulePollingIfNeeded();
    } catch (error) {
      _pollTimer?.cancel();
      if (!mounted) {
        return;
      }
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _loading = false;
        _error = '加载导出任务失败：$error';
      });
    }
  }

  Future<void> _downloadTask(UserExportTaskItem task) async {
    setState(() => _downloadingTaskId = task.id);
    try {
      final download = await widget.userService.downloadUserExportTask(
        taskId: task.id,
      );
      if (!mounted) {
        return;
      }
      final savedPath = await widget.saveExportFile(
        filename: download.filename,
        bytes: download.bytes,
        mimeType: download.mimeType,
        format: task.format,
      );
      if (!mounted) {
        return;
      }
      if (savedPath == null) {
        setState(() => _notice = '已取消下载保存');
        return;
      }
      setState(() => _notice = '已下载到 $savedPath');
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        Navigator.of(context).pop();
        return;
      }
      setState(() => _notice = '下载失败：$error');
    } finally {
      if (mounted) {
        setState(() => _downloadingTaskId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: const Text('导出任务'),
      width: 920,
      content: SizedBox(
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '最近 20 条任务',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _loadTasks,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新任务',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_notice.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _notice,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_loading)
              const Expanded(child: MesLoadingState(label: '导出任务加载中...'))
            else if (_error.isNotEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _error,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              )
            else if (_tasks.isEmpty)
              const Expanded(child: Center(child: Text('暂无导出任务')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final highlighted = widget.highlightTaskId == task.id;
                    final statusColor = _taskStatusColor(context, task.status);
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: highlighted
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: highlighted ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: highlighted
                            ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.35,
                              )
                            : theme.colorScheme.surface,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.fileName?.trim().isNotEmpty == true
                                      ? task.fileName!
                                      : '任务 ${task.taskCode}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _taskStatusLabel(task.status),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              Text(
                                '格式：${task.format == 'excel' ? 'Excel' : 'CSV'}',
                              ),
                              Text(
                                '数据范围：${_deletedScopeLabel(task.deletedScope)}',
                              ),
                              Text('记录数：${task.recordCount}'),
                              Text('导出时间：${_formatTaskTime(task.requestedAt)}'),
                              Text('完成时间：${_formatTaskTime(task.finishedAt)}'),
                            ],
                          ),
                          if (task.keyword != null &&
                              task.keyword!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('关键词：${task.keyword}'),
                          ],
                          if (task.roleCode != null &&
                              task.roleCode!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('角色筛选：${task.roleCode}'),
                          ],
                          if (task.isActive != null) ...[
                            const SizedBox(height: 4),
                            Text('账号状态筛选：${task.isActive! ? '启用' : '停用'}'),
                          ],
                          if (task.failureReason != null &&
                              task.failureReason!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '失败原因：${task.failureReason}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (task.status == 'succeeded')
                                FilledButton.icon(
                                  onPressed: _downloadingTaskId == task.id
                                      ? null
                                      : () => _downloadTask(task),
                                  icon: const Icon(Icons.download),
                                  label: Text(
                                    _downloadingTaskId == task.id
                                        ? '下载中...'
                                        : '下载',
                                  ),
                                )
                              else
                                Text(
                                  task.status == 'expired'
                                      ? '文件已过期，请重新创建任务'
                                      : '等待任务进入终态后可下载',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
