import 'package:flutter/material.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/services/user_service.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';

class AnnouncementPublishDialog extends StatefulWidget {
  const AnnouncementPublishDialog({
    super.key,
    required this.userService,
    required this.service,
  });

  final UserService userService;
  final MessageService service;

  @override
  State<AnnouncementPublishDialog> createState() =>
      _AnnouncementPublishDialogState();
}

class _AnnouncementPublishDialogState extends State<AnnouncementPublishDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _loadingOptions = true;
  bool _submitting = false;
  String _error = '';
  String _priority = 'normal';
  String _rangeType = 'all';
  DateTime? _expiresAt;
  List<RoleItem> _roles = const [];
  List<UserItem> _users = const [];
  final Set<String> _selectedRoleCodes = <String>{};
  final Set<int> _selectedUserIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _error = '';
    });
    try {
      final results = await Future.wait([
        widget.userService.listAllRoles(),
        _loadAllActiveUsers(),
      ]);
      if (!mounted) {
        return;
      }
      final roleResult = results[0] as RoleListResult;
      final userResult = results[1] as UserListResult;
      setState(() {
        _roles = roleResult.items.where((item) => item.isEnabled).toList();
        _users = userResult.items
            .where((item) => item.isActive && !item.isDeleted)
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingOptions = false);
      }
    }
  }

  Future<UserListResult> _loadAllActiveUsers() async {
    const pageSize = 200;
    var page = 1;
    var total = 0;
    final items = <UserItem>[];
    while (true) {
      final result = await widget.userService.listUsers(
        page: page,
        pageSize: pageSize,
        isActive: true,
      );
      total = result.total;
      items.addAll(result.items);
      if (result.items.isEmpty) {
        break;
      }
      if (total > 0 && items.length >= total) {
        break;
      }
      page += 1;
    }
    return UserListResult(total: total, items: items);
  }

  Future<void> _pickExpiresAt() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _expiresAt ?? now,
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _expiresAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (pickedTime == null || !mounted) {
      return;
    }
    setState(() {
      _expiresAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatLocalDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = '请填写标题和正文');
      return;
    }
    if (_rangeType == 'roles' && _selectedRoleCodes.isEmpty) {
      setState(() => _error = '请选择至少一个角色');
      return;
    }
    if (_rangeType == 'users' && _selectedUserIds.isEmpty) {
      setState(() => _error = '请选择至少一个用户');
      return;
    }

    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final result = await widget.service.publishAnnouncement(
        AnnouncementPublishRequest(
          title: title,
          content: content,
          priority: _priority,
          rangeType: _rangeType,
          roleCodes: _selectedRoleCodes.toList()..sort(),
          userIds: _selectedUserIds.toList()..sort(),
          expiresAt: _expiresAt,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('公告已发布，覆盖 ${result.recipientCount} 人')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildSelectionArea() {
    if (_rangeType == 'all') {
      return Container(
        height: 320,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_2_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withAlpha(150)),
            const SizedBox(height: 16),
            Text('发送给全部启用用户', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('发布后将自动生成全员收件记录', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }
    if (_loadingOptions) {
      return const SizedBox(
        height: 320,
        child: Center(child: MesLoadingState(label: '可选范围加载中...')),
      );
    }
    if (_rangeType == 'roles') {
      return SizedBox(
        height: 320,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _roles
                .map(
                  (role) => FilterChip(
                    label: Text('${role.name} (${role.code})'),
                    selected: _selectedRoleCodes.contains(role.code),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRoleCodes.add(role.code);
                        } else {
                          _selectedRoleCodes.remove(role.code);
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
    return SizedBox(
      height: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '可选用户 ${_users.length} 人，已选择 ${_selectedUserIds.length} 人',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                itemCount: _users.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final label = user.fullName?.trim().isNotEmpty == true
                      ? '${user.fullName} (${user.username})'
                      : user.username;
                  return CheckboxListTile(
                    value: _selectedUserIds.contains(user.id),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(label),
                    subtitle: Text(user.roleName ?? user.roleCode ?? '未分配角色'),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _selectedUserIds.add(user.id);
                        } else {
                          _selectedUserIds.remove(user.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: const Text('发布公告'),
      width: 860,
      content: SizedBox(
        width: 860,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左半部分：基本信息
            Expanded(
            flex: 5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contentController,
                  minLines: 8,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: '正文',
                    border: OutlineInputBorder(),
                    filled: true,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: '优先级',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('普通')),
                    DropdownMenuItem(value: 'important', child: Text('重要')),
                    DropdownMenuItem(value: 'urgent', child: Text('紧急')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _priority = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_error.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer.withAlpha(50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.error),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // 右半部分：发送范围与时间设置
          Expanded(
            flex: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('发送范围', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('全员'), icon: Icon(Icons.public)),
                    ButtonSegment(value: 'roles', label: Text('指定角色'), icon: Icon(Icons.manage_accounts)),
                    ButtonSegment(value: 'users', label: Text('指定用户'), icon: Icon(Icons.person_add)),
                  ],
                  selected: {_rangeType},
                  onSelectionChanged: (set) {
                    setState(() => _rangeType = set.first);
                  },
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 16),
                _buildSelectionArea(),
                const SizedBox(height: 24),
                Text('发布设置', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.schedule_outlined),
                        title: const Text('生效时间'),
                        subtitle: Text(_formatLocalDateTime(DateTime.now())),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.event_busy_outlined),
                        title: const Text('失效时间'),
                        subtitle: Text(
                          _expiresAt == null
                              ? '永久生效 (不设置)'
                              : _formatLocalDateTime(_expiresAt!),
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _submitting ? null : _pickExpiresAt,
                              child: const Text('选择'),
                            ),
                            if (_expiresAt != null)
                              TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => setState(() => _expiresAt = null),
                                child: const Text('清空'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(_submitting ? '发布中...' : '确认发布'),
        ),
      ],
    );
  }
}
