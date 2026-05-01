import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/services/user_service.dart';

Future<void> showUserImportDialog({
  required BuildContext context,
  required UserService userService,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => UserImportDialog(userService: userService),
  );
}

class UserImportDialog extends StatefulWidget {
  const UserImportDialog({super.key, required this.userService});

  final UserService userService;

  @override
  State<UserImportDialog> createState() => _UserImportDialogState();
}

class _UserImportDialogState extends State<UserImportDialog> {
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  bool _loading = false;
  String _error = '';
  UserImportResult? _result;

  Future<void> _pickFile() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'CSV/Excel',
          extensions: ['csv', 'xlsx', 'xls'],
        ),
      ],
    );
    if (files.isNotEmpty) {
      final file = files.first;
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedFileName = file.name;
        _selectedFileBytes = bytes;
        _error = '';
        _result = null;
      });
    }
  }

  Future<void> _submitImport() async {
    if (_selectedFileBytes == null || _loading) return;

    setState(() {
      _loading = true;
      _error = '';
      _result = null;
    });

    try {
      final result = await widget.userService.importUsers(
        fileBytes: _selectedFileBytes!,
        fileName: _selectedFileName ?? 'import.csv',
      );
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : '导入失败：$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('批量导入用户'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '支持 CSV 和 Excel 格式。必须包含 username 和 role_code 列。\n默认密码：123456，首次登录需修改密码。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('选择文件'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFileName ?? '未选择文件',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '导入完成',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('总行数：${_result!.totalRows}'),
                      Text(
                        '成功：${_result!.successCount}',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                      Text(
                        '失败：${_result!.failureCount}',
                        style: TextStyle(
                          color: _result!.failureCount > 0
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_result!.failureCount > 0) ...[
                  const SizedBox(height: 12),
                  Text('失败详情：', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  ..._result!.items
                      .where((item) => !item.success)
                      .take(20)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '第${item.rowNumber}行 [${item.username}]：${item.error}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                  if (_result!.failureCount > 20)
                    Text(
                      '...及其他 ${_result!.failureCount - 20} 条',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(_result != null ? '关闭' : '取消'),
        ),
        if (_result == null)
          FilledButton(
            onPressed:
                (_selectedFileBytes != null && !_loading) ? _submitImport : null,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('开始导入'),
          ),
      ],
    );
  }
}
