import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/crud_page_header.dart';

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
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.badge_outlined,
              title: '个人资料',
              subtitle: '展示当前账号的基础信息、组织归属与最近登录情况。',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  label: profile.isActive ? '账号启用中' : '账号已停用',
                  color: profile.isActive ? Colors.green : Colors.red,
                  icon: profile.isActive
                      ? Icons.verified_outlined
                      : Icons.block_outlined,
                ),
                _buildInfoChip(
                  label: profile.roleName?.trim().isNotEmpty == true
                      ? profile.roleName!
                      : '未分配角色',
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.security_outlined,
                ),
                _buildInfoChip(
                  label: profile.stageName?.trim().isNotEmpty == true
                      ? '工段 ${profile.stageName!}'
                      : '未绑定工段',
                  color: Theme.of(context).colorScheme.secondary,
                  icon: Icons.factory_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFieldGroup(
              children: [
                _buildInfoItem('用户名', profile.username),
                _buildInfoItem('显示名称', profile.fullName ?? '-'),
                _buildInfoItem(
                  '角色',
                  profile.roleName?.trim().isNotEmpty == true
                      ? profile.roleName!
                      : '-',
                ),
                _buildInfoItem('工段', profile.stageName ?? '/'),
              ],
            ),
            const SizedBox(height: 12),
            _buildFieldGroup(
              children: [
                _buildInfoItem('创建时间', _formatDateTime(profile.createdAt)),
                _buildInfoItem('最近登录', _formatDateTime(profile.lastLoginAt)),
                _buildInfoItem('最近登录 IP', profile.lastLoginIp ?? '-'),
                _buildInfoItem(
                  '最近改密时间',
                  _formatDateTime(profile.passwordChangedAt),
                ),
              ],
            ),
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

  Widget _buildOverviewCard() {
    final theme = Theme.of(context);
    final profile = _profile;
    final currentSession = _session;
    final statusColor = currentSession == null
        ? theme.colorScheme.outline
        : _sessionStatusColor(currentSession.remainingSeconds);
    final statusLabel = currentSession == null
        ? (widget.canViewSession ? '未同步' : '不可见')
        : _sessionStatusLabel(currentSession.remainingSeconds);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  child: Text(
                    (profile?.fullName?.isNotEmpty == true
                            ? profile!.fullName!
                            : profile?.username ?? '我')
                        .characters
                        .first,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.fullName?.trim().isNotEmpty == true
                            ? profile!.fullName!
                            : profile?.username ?? '个人中心',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '账号 ${profile?.username ?? '-'} · ${profile?.roleName?.trim().isNotEmpty == true ? profile!.roleName! : '未分配角色'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOverviewBadge(
                  label: '会话状态',
                  value: statusLabel,
                  color: statusColor,
                  icon:
                      currentSession != null &&
                          currentSession.remainingSeconds <= 600
                      ? Icons.warning_amber_rounded
                      : Icons.monitor_heart_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatCard(
                  label: '账号状态',
                  value: profile == null
                      ? '-'
                      : (profile.isActive ? '启用' : '停用'),
                  hint: '个人资料状态',
                  icon: Icons.verified_user_outlined,
                ),
                _buildStatCard(
                  label: '工段归属',
                  value: profile?.stageName?.trim().isNotEmpty == true
                      ? profile!.stageName!
                      : '未绑定',
                  hint: '当前组织位置',
                  icon: Icons.schema_outlined,
                ),
                _buildStatCard(
                  label: '最近登录',
                  value: _formatDateTime(profile?.lastLoginAt),
                  hint: '最近访问时间',
                  icon: Icons.history_toggle_off_outlined,
                ),
                _buildStatCard(
                  label: '剩余时长',
                  value: currentSession == null
                      ? (widget.canViewSession ? '未同步' : '不可见')
                      : _formatDuration(currentSession.remainingSeconds),
                  hint: widget.canViewSession ? '当前登录会话' : '当前无会话权限',
                  icon: Icons.timer_outlined,
                  accent: statusColor,
                ),
              ],
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.monitor_outlined,
              title: '当前会话',
              subtitle: '自动刷新当前登录状态，支持直接退出本次登录。',
            ),
            const SizedBox(height: 16),
            if (currentSession == null)
              _buildEmptyStateCard(
                icon: Icons.portable_wifi_off_outlined,
                title: '未查询到当前在线会话记录',
                subtitle: '系统暂未返回当前会话信息，可下拉页面后重试。',
              )
            else ...[
              Row(
                children: [
                  Expanded(child: _buildSessionStatusRow(currentSession)),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: const Icon(Icons.logout),
                    label: Text(_loggingOut ? '退出中...' : '退出当前登录'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFieldGroup(
                children: [
                  _buildInfoItem(
                    '登录时间',
                    _formatDateTime(currentSession.loginTime),
                  ),
                  _buildInfoItem(
                    '最后活跃时间',
                    _formatDateTime(currentSession.lastActiveAt),
                  ),
                  _buildInfoItem(
                    '过期时间',
                    _formatDateTime(currentSession.expiresAt),
                  ),
                  _buildRemainingInfo(currentSession),
                ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              session.remainingSeconds <= 600
                  ? Icons.warning_amber_rounded
                  : Icons.shield_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '状态',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingInfo(CurrentSessionResult session) {
    final color = _sessionStatusColor(session.remainingSeconds);
    final isWarning = session.remainingSeconds <= 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '剩余时间',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDuration(session.remainingSeconds),
          style: TextStyle(
            color: color,
            fontWeight: isWarning ? FontWeight.bold : FontWeight.w600,
            fontSize: isWarning ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordCard() {
    final highlightColor = Theme.of(context).colorScheme.primary;
    return Card(
      key: _passwordSectionKey,
      elevation: 0,
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
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                icon: Icons.lock_outline,
                title: '修改密码',
                subtitle: '更新当前账号密码，提交成功后将自动退出并要求重新登录。',
              ),
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _oldPasswordController,
                      focusNode: _oldPasswordFocusNode,
                      obscureText: true,
                      showCursor: false,
                      decoration: const InputDecoration(
                        labelText: '当前密码',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.lock_person_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '当前密码不能为空';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '新密码',
                        helperText: '密码规则：至少6位；不能包含连续4位相同字符；不能与原密码相同。',
                        helperMaxLines: 3,
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.enhanced_encryption_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return '新密码长度不能少于 6 位';
                        }
                        if (RegExp(r'(.)\1\1\1').hasMatch(value)) {
                          return '新密码不能包含连续4位相同字符';
                        }
                        if (value == _oldPasswordController.text) {
                          return '新密码不能与原密码相同';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '确认新密码',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.password_outlined),
                      ),
                      validator: (value) {
                        if (value != _newPasswordController.text) {
                          return '两次输入的新密码不一致';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      widget.canChangePassword
                          ? '修改成功后将结束当前会话。'
                          : '当前账号没有修改密码权限。',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: widget.canChangePassword && !_changing
                        ? _changePassword
                        : null,
                    icon: Icon(
                      _changing ? Icons.hourglass_top : Icons.save_outlined,
                    ),
                    label: Text(_changing ? '保存中...' : '修改密码'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewBadge({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    Color? accent,
  }) {
    final theme = Theme.of(context);
    final highlight = accent ?? theme.colorScheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: highlight),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(hint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldGroup({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Wrap(spacing: 16, runSpacing: 16, children: children),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1080;
          final sideSpacing = isWide ? 20.0 : 0.0;
          return Semantics(
            container: true,
            label: '个人中心主区域',
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CrudPageHeader(title: '个人中心', onRefresh: _loadData),
                  const SizedBox(height: 12),
                  _buildOverviewCard(),
                  const SizedBox(height: 16),
                  if (_message.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _buildProfileCard(),
                              if (widget.canViewSession) ...[
                                const SizedBox(height: 16),
                                _buildSessionCard(),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: sideSpacing),
                        Expanded(flex: 4, child: _buildPasswordCard()),
                      ],
                    )
                  else ...[
                    _buildProfileCard(),
                    if (widget.canViewSession) ...[
                      const SizedBox(height: 16),
                      _buildSessionCard(),
                    ],
                    const SizedBox(height: 16),
                    _buildPasswordCard(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
