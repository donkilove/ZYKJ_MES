import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canChangePassword,
    required this.canViewSession,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canChangePassword;
  final bool canViewSession;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late final UserService _userService;

  bool _loading = false;
  bool _changing = false;
  String _message = '';
  ProfileResult? _profile;
  CurrentSessionResult? _session;

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _userService = UserService(widget.session);
    _loadData();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final profile = await _userService.getMyProfile();
      CurrentSessionResult? currentSession;
      if (widget.canViewSession) {
        try {
          currentSession = await _userService.getMySession();
        } catch (_) {
          currentSession = null;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _session = currentSession;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载个人信息失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
  }

  Future<void> _changePassword() async {
    if (!widget.canChangePassword) {
      return;
    }
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _changing = true;
      _message = '';
    });
    try {
      await _userService.changeMyPassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码修改成功，请重新登录。')),
      );
      widget.onLogout();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '修改密码失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _changing = false;
        });
      }
    }
  }

  Widget _buildProfileCard() {
    final profile = _profile;
    if (profile == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用户名：${profile.username}'),
            Text('显示名称：${profile.fullName ?? '-'}'),
            Text('角色：${profile.roleNames.join('、')}'),
            Text('工段：${profile.stageName ?? '-'}'),
            Text('账号状态：${profile.isActive ? '启用' : '停用'}'),
            Text('创建时间：${_formatDateTime(profile.createdAt)}'),
            Text('最近登录：${_formatDateTime(profile.lastLoginAt)}'),
            Text('最近登录 IP：${profile.lastLoginIp ?? '-'}'),
            Text(
              '最近改密时间：${_formatDateTime(profile.passwordChangedAt)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard() {
    if (!widget.canViewSession) {
      return const SizedBox.shrink();
    }
    final currentSession = _session;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前会话',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (currentSession == null)
              const Text('未查询到当前在线会话记录')
            else ...[
              Text('会话令牌：${currentSession.sessionTokenId}'),
              Text('状态：${currentSession.status}'),
              Text('登录时间：${_formatDateTime(currentSession.loginTime)}'),
              Text(
                '最后活跃时间：${_formatDateTime(currentSession.lastActiveAt)}',
              ),
              Text('过期时间：${_formatDateTime(currentSession.expiresAt)}'),
              Text('剩余秒数：${currentSession.remainingSeconds}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '修改密码',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '当前密码',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '当前密码不能为空';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新密码',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return '新密码长度不能少于 6 位';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '确认新密码',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return '两次输入的新密码不一致';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: widget.canChangePassword && !_changing
                      ? _changePassword
                      : null,
                  child: Text(_changing ? '保存中...' : '修改密码'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_message, style: const TextStyle(color: Colors.red)),
            ),
          _buildProfileCard(),
          const SizedBox(height: 10),
          _buildSessionCard(),
          const SizedBox(height: 10),
          _buildPasswordCard(),
        ],
      ),
    );
  }
}
