import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canChangePassword,
    required this.canViewSession,
    this.routePayloadJson,
    this.userService,
    this.authService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canChangePassword;
  final bool canViewSession;
  final String? routePayloadJson;
  final UserService? userService;
  final AuthService? authService;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late final UserService _userService;
  late final AuthService _authService;
  final FocusNode _oldPasswordFocusNode = FocusNode();
  final GlobalKey _passwordSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  bool _changing = false;
  bool _loggingOut = false;
  String _message = '';
  ProfileResult? _profile;
  CurrentSessionResult? _session;
  Timer? _sessionRefreshTimer;
  Timer? _passwordHighlightTimer;
  bool _timeoutWarningShown = false;
  String? _lastHandledRoutePayloadJson;
  bool _pendingPasswordSectionLanding = false;
  bool _passwordSectionHighlighted = false;

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService(widget.session);
    _authService = widget.authService ?? AuthService();
    _loadData();
    _sessionRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshSession(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeRoutePayload(widget.routePayloadJson);
    });
  }

  @override
  void didUpdateWidget(covariant AccountSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routePayloadJson != oldWidget.routePayloadJson) {
      _consumeRoutePayload(widget.routePayloadJson);
    }
  }

  @override
  void dispose() {
    _sessionRefreshTimer?.cancel();
    _passwordHighlightTimer?.cancel();
    _oldPasswordFocusNode.dispose();
    _scrollController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _refreshSession() async {
    if (!widget.canViewSession || !mounted) return;
    try {
      final currentSession = await _userService.getMySession();
      if (!mounted) return;
      if (currentSession.status != 'active') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前登录会话已失效，请重新登录。')));
        widget.onLogout();
        return;
      }
      setState(() => _session = currentSession);
      _checkSessionTimeout(currentSession);
    } catch (error) {
      if (!mounted) return;
      if (_isSessionUnavailable(error)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录状态已失效，请重新登录。')));
        widget.onLogout();
      }
    }
  }

  void _checkSessionTimeout(CurrentSessionResult session) {
    if (session.remainingSeconds <= 300 && !_timeoutWarningShown) {
      _timeoutWarningShown = true;
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.deepOrange,
              size: 36,
            ),
            title: const Text('会话即将过期'),
            content: Text(
              '当前会话将在 ${_formatDuration(session.remainingSeconds)} 后过期，'
              '请及时保存工作内容。如需继续使用，请重新登录。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 秒';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0 && s > 0) return '$m 分 $s 秒';
    if (m > 0) return '$m 分钟';
    return '$s 秒';
  }

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  bool _isSessionUnavailable(Object error) =>
      error is ApiException &&
      (error.statusCode == 401 || error.statusCode == 404);

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  void _consumeRoutePayload(String? rawPayload) {
    if (!mounted ||
        rawPayload == null ||
        rawPayload.trim().isEmpty ||
        rawPayload == _lastHandledRoutePayloadJson) {
      return;
    }
    try {
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      final action = (payload['action'] as String? ?? '').trim();
      if (action != 'change_password') {
        return;
      }
      _lastHandledRoutePayloadJson = rawPayload;
      _pendingPasswordSectionLanding = true;
      _highlightPasswordSection();
      _tryLandOnPasswordSection();
    } catch (_) {}
  }

  void _highlightPasswordSection() {
    _passwordHighlightTimer?.cancel();
    if (mounted) {
      setState(() {
        _passwordSectionHighlighted = true;
      });
    }
    _passwordHighlightTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _passwordSectionHighlighted = false;
      });
    });
  }

  void _tryLandOnPasswordSection() {
    if (!_pendingPasswordSectionLanding || _loading || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final targetContext = _passwordSectionKey.currentContext;
      if (targetContext == null) {
        return;
      }
      _pendingPasswordSectionLanding = false;
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
      if (!mounted) {
        return;
      }
      FocusScope.of(context).requestFocus(_oldPasswordFocusNode);
    });
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
          if (currentSession.status != 'active') {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('当前登录会话已失效，请重新登录。')));
            widget.onLogout();
            return;
          }
        } catch (error) {
          if (_isSessionUnavailable(error)) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('登录状态已失效，请重新登录。')));
            widget.onLogout();
            return;
          }
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
      if (currentSession != null) {
        _checkSessionTimeout(currentSession);
      }
      _tryLandOnPasswordSection();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码修改成功，请重新登录。')));
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

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await _authService.logout(
        baseUrl: widget.session.baseUrl,
        accessToken: widget.session.accessToken,
      );
    } catch (_) {
      // 忽略退出登录错误，直接跳转
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
        widget.onLogout();
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
            Text(
              '角色：${profile.roleName?.trim().isNotEmpty == true ? profile.roleName! : '-'}',
            ),
            Text('工段：${profile.stageName ?? '/'}'),
            Text('账号状态：${profile.isActive ? '启用' : '停用'}'),
            Text('创建时间：${_formatDateTime(profile.createdAt)}'),
            Text('最近登录：${_formatDateTime(profile.lastLoginAt)}'),
            Text('最近登录 IP：${profile.lastLoginIp ?? '-'}'),
            Text('最近改密时间：${_formatDateTime(profile.passwordChangedAt)}'),
          ],
        ),
      ),
    );
  }

  Color _sessionStatusColor(int remainingSeconds) {
    if (remainingSeconds <= 300) return Colors.red;
    if (remainingSeconds <= 600) return Colors.deepOrange;
    return Colors.green;
  }

  String _sessionStatusLabel(int remainingSeconds) {
    if (remainingSeconds <= 0) return '已过期';
    if (remainingSeconds <= 300) return '即将过期';
    if (remainingSeconds <= 600) return '接近过期';
    return '在线';
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
            const Text('当前会话', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (currentSession == null)
              const Text('未查询到当前在线会话记录')
            else ...[
              _buildSessionStatusRow(currentSession),
              Text('登录时间：${_formatDateTime(currentSession.loginTime)}'),
              Text('最后活跃时间：${_formatDateTime(currentSession.lastActiveAt)}'),
              Text('过期时间：${_formatDateTime(currentSession.expiresAt)}'),
              _buildRemainingRow(currentSession),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: _loggingOut ? null : _logout,
                  child: Text(_loggingOut ? '退出中...' : '退出当前登录'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStatusRow(CurrentSessionResult session) {
    final color = _sessionStatusColor(session.remainingSeconds);
    final label = _sessionStatusLabel(session.remainingSeconds);
    return Row(
      children: [
        const Text('状态：'),
        if (session.remainingSeconds <= 600)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.warning_amber_rounded, color: color, size: 16),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildRemainingRow(CurrentSessionResult session) {
    final color = _sessionStatusColor(session.remainingSeconds);
    final isWarning = session.remainingSeconds <= 600;
    return Row(
      children: [
        Text('剩余时间：', style: isWarning ? TextStyle(color: color) : null),
        Text(
          _formatDuration(session.remainingSeconds),
          style: TextStyle(
            color: color,
            fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
            fontSize: isWarning ? 14 : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordCard() {
    final highlightColor = Theme.of(context).colorScheme.primary;
    return Card(
      key: _passwordSectionKey,
      color: _passwordSectionHighlighted
          ? highlightColor.withValues(alpha: 0.08)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _passwordSectionHighlighted
              ? highlightColor
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('修改密码', style: TextStyle(fontWeight: FontWeight.w600)),
              if (_passwordSectionHighlighted) ...[
                const SizedBox(height: 8),
                Text(
                  '已定位到修改密码区域',
                  key: const ValueKey(
                    'account-settings-change-password-anchor',
                  ),
                  style: TextStyle(
                    color: highlightColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _oldPasswordController,
                focusNode: _oldPasswordFocusNode,
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
                  helperText: '密码规则：至少6位；不能与原密码相同；不能包含连续4位相同字符；不能与系统中已有用户密码相同。',
                  helperMaxLines: 3,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return '新密码长度不能少于 6 位';
                  }
                  if (value == _oldPasswordController.text) {
                    return '新密码不能与原密码相同';
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
        controller: _scrollController,
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
