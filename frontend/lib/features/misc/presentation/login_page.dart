import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:flutter/services.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/config/runtime_endpoints.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/presentation/widgets/announcement_card.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/misc/presentation/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    this.defaultBaseUrl = defaultApiBaseUrl,
    this.initialMessage,
    this.authService,
    this.publicAnnouncementLoader,
  });

  final ValueChanged<AppSession> onLoginSuccess;
  final String defaultBaseUrl;
  final String? initialMessage;
  final AuthService? authService;
  final Future<List<MessageItem>> Function(String baseUrl)?
  publicAnnouncementLoader;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const List<_NoticeSection> _noticeSections = [
    _NoticeSection(
      title: '生产运行提醒',
      icon: Icons.campaign_outlined,
      items: [
        '今日 18:30 至 19:00 执行工单汇总任务，期间报工统计可能延迟 3 至 5 分钟刷新。',
        '冲压一车间新增设备点检项已上线，请班组长在交接班前完成确认。',
      ],
    ),
    _NoticeSection(
      title: '质量与追溯要求',
      icon: Icons.verified_outlined,
      items: [
        '3 月批次成品入库前需补录首件检验照片，未上传附件的单据将无法提交。',
        '条码补打申请统一由工艺室审批，审批通过后请在两小时内完成复核。',
      ],
    ),
    _NoticeSection(
      title: '账号使用规范',
      icon: Icons.manage_accounts_outlined,
      items: [
        '本周起启用账号审批闭环，新增账号需由部门负责人和系统管理员双重确认。',
        '连续 90 天未登录的账号将自动停用，如需恢复请通过“去注册”重新提交申请。',
      ],
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final AuthService _authService;

  bool _loading = false;
  bool _loadingAccounts = false;
  String _message = '';
  List<String> _accounts = const [];

  List<MessageItem> _announcements = [];
  bool _loadingAnnouncements = false;
  String? _announcementError;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.defaultBaseUrl);
    _authService = widget.authService ?? AuthService();
    _message = widget.initialMessage ?? '';
    _loadAccounts();
    _refreshAnnouncements();
  }

  Future<void> _refreshAnnouncements() async {
    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      return;
    }

    setState(() {
      _loadingAnnouncements = true;
      _announcementError = null;
    });

    try {
      final loader = widget.publicAnnouncementLoader;
      final items = loader != null
          ? await loader(baseUrl)
          : await MessageService.public(
              baseUrl,
            ).getPublicAnnouncements(pageSize: 10);
      if (mounted) {
        setState(() {
          _announcements = items;
          _loadingAnnouncements = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _announcementError = e.toString();
          _loadingAnnouncements = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  String _accountText() => _accountController.text.trim();

  bool _containsChinese(String value) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(value);
  }

  String _extractErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message.trim();
    }
    return error.toString().trim();
  }

  String _mapLoginError(Object error) {
    final raw = _extractErrorMessage(error);
    final normalized = raw.toLowerCase();
    if (normalized.contains('account is pending approval') ||
        raw.contains('待审批')) {
      return '当前账号正在审批中，请等待审批通过后再登录。';
    }
    if (normalized.contains('account is rejected') ||
        normalized.contains('rejected') ||
        raw.contains('已驳回')) {
      return '该账号的注册申请已被驳回，请重新注册后再登录。';
    }
    if (normalized.contains('account is disabled') || raw.contains('停用')) {
      return '当前账号已停用，请联系管理员处理。';
    }
    if (normalized.contains('incorrect username or password') ||
        raw.contains('账号或密码错误')) {
      return '账号或密码错误，请重新输入。';
    }
    if (normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('network') ||
        normalized.contains('connection') ||
        normalized.contains('socket')) {
      return '网络连接异常，请检查后重试。';
    }
    if (_containsChinese(raw) && raw.isNotEmpty) {
      return raw;
    }
    return '登录失败，请稍后重试。';
  }

  String _mapAccountLoadError(Object error) {
    final raw = _extractErrorMessage(error);
    final normalized = raw.toLowerCase();
    if (normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('network') ||
        normalized.contains('connection') ||
        normalized.contains('socket')) {
      return '加载账号列表失败：网络连接异常，请检查后重试。';
    }
    if (_containsChinese(raw) && raw.isNotEmpty) {
      return '加载账号列表失败：$raw';
    }
    return '加载账号列表失败：请检查接口地址后重试。';
  }

  Future<void> _loadAccounts() async {
    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _loadingAccounts = true;
    });

    try {
      await _refreshAnnouncements();
      final accounts = await _authService.listAccounts(baseUrl: baseUrl);
      if (!mounted) {
        return;
      }
      setState(() {
        _accounts = accounts;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _mapAccountLoadError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAccounts = false;
        });
      }
    }
  }

  Future<void> _submitLogin() async {
    if (_loading) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
    final account = _accountText();
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await _authService.login(
        baseUrl: baseUrl,
        username: account,
        password: _passwordController.text,
      );
      final session = AppSession(
        baseUrl: baseUrl,
        accessToken: result.token,
        mustChangePassword: result.mustChangePassword,
      );
      widget.onLoginSuccess(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _mapLoginError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _wrapLoginSubmitShortcut(Widget child) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () {
          _submitLogin();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          _submitLogin();
        },
      },
      child: child,
    );
  }

  Future<void> _openRegisterPage() async {
    final result = await Navigator.of(context).push<RegisterPageResult>(
      MaterialPageRoute(
        builder: (_) => RegisterPage(
          initialBaseUrl: _normalizeBaseUrl(_baseUrlController.text),
          authService: widget.authService,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    _baseUrlController.text = result.baseUrl;
    _accountController.text = result.account;
    _passwordController.clear();
    setState(() {
      _message = '注册申请已提交，请等待系统管理员审批后再登录。';
    });
    await _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.surface, colorScheme.surfaceContainerLowest],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              final horizontalPadding = isWide ? 32.0 : 16.0;
              final verticalPadding = isWide ? 24.0 : 16.0;
              final availableHeight =
                  constraints.maxHeight - verticalPadding * 2;
              final cardHeight = availableHeight > 0 ? availableHeight : null;

              final announcementCard = _buildAnnouncementCard(
                theme,
                fillHeight: isWide,
              );
              final loginCard = _buildLoginCard(theme, fillHeight: isWide);

              final desktopContent = SizedBox(
                height: cardHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: announcementCard),
                    const SizedBox(width: 20),
                    Expanded(child: loginCard),
                  ],
                ),
              );

              final mobileContent = SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: availableHeight > 0 ? availableHeight : 0,
                  ),
                  child: Column(
                    children: [
                      announcementCard,
                      const SizedBox(height: 16),
                      loginCard,
                    ],
                  ),
                ),
              );

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1360),
                    child: isWide ? desktopContent : mobileContent,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(ThemeData theme, {required bool fillHeight}) {
    final colorScheme = theme.colorScheme;

    if (_loadingAnnouncements) {
      return Card(
        elevation: 6,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.92),
                colorScheme.surfaceContainerHigh,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: MesLoadingState(label: '公告加载中...'),
            ),
          ),
        ),
      );
    }

    Widget contentWidget;
    if (_announcements.isEmpty && _announcementError == null) {
      contentWidget = _buildStaticAnnouncementCard(
        theme,
        fillHeight: fillHeight,
      );
    } else if (_announcements.isNotEmpty) {
      contentWidget = _buildDynamicAnnouncementList(
        theme,
        fillHeight: fillHeight,
      );
    } else {
      contentWidget = _buildStaticAnnouncementCard(
        theme,
        fillHeight: fillHeight,
      );
    }

    return Card(
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.92),
              colorScheme.surfaceContainerHigh,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _buildAnnouncementContent(
            theme,
            contentWidget,
            fillHeight: fillHeight,
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementContent(
    ThemeData theme,
    Widget contentWidget, {
    required bool fillHeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _buildAnnouncementHeader(theme),
        const SizedBox(height: 20),
        Text(
          '欢迎使用 ZYKJ MES 制造执行系统',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '请先阅读当日运维通知与业务变更说明，确认账号状态正常后再进行登录。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        _buildAnnouncementTags(theme),
        const SizedBox(height: 24),
        if (fillHeight) Expanded(child: contentWidget) else contentWidget,
      ],
    );
  }

  Widget _buildAnnouncementHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '系统公告',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: _refreshAnnouncements,
              tooltip: '刷新公告',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnnouncementTags(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (_announcements.isNotEmpty)
          _NoticeTag(label: '共 ${_announcements.length} 条公告')
        else
          const _NoticeTag(label: '最后更新 2026-03-23 08:30'),
        const _NoticeTag(label: '发布部门 信息化推进组'),
        _NoticeTag(label: _announcementError != null ? '静态公告' : '状态 正常运行'),
      ],
    );
  }

  Widget _buildStaticAnnouncementCard(
    ThemeData theme, {
    required bool fillHeight,
  }) {
    final colorScheme = theme.colorScheme;
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: !fillHeight,
      itemCount: _noticeSections.length,
      separatorBuilder: (_, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final section = _noticeSections[index];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(section.icon, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...section.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Icon(
                          Icons.circle,
                          size: 8,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicAnnouncementList(
    ThemeData theme, {
    required bool fillHeight,
  }) {
    final cards = _announcements
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnnouncementCard(item: item),
          ),
        )
        .toList();

    if (fillHeight) {
      return ListView(physics: const BouncingScrollPhysics(), children: cards);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cards,
    );
  }

  Widget _buildLoginCard(ThemeData theme, {required bool fillHeight}) {
    final formContent = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: '接口地址',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入接口地址';
                    }
                    if (!value.startsWith('http://') &&
                        !value.startsWith('https://')) {
                      return '地址必须以 http:// 或 https:// 开头';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _loadAccounts(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '刷新账号列表',
                onPressed: _loadingAccounts ? null : _loadAccounts,
                icon: _loadingAccounts
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              final keyword = textEditingValue.text.trim().toLowerCase();
              if (keyword.isEmpty) {
                return _accounts;
              }
              return _accounts.where(
                (account) => account.toLowerCase().contains(keyword),
              );
            },
            onSelected: (value) {
              _accountController.text = value;
            },
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
                  if (textEditingController.text != _accountController.text) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted ||
                          textEditingController.text ==
                              _accountController.text) {
                        return;
                      }
                      textEditingController.value = TextEditingValue(
                        text: _accountController.text,
                        selection: TextSelection.collapsed(
                          offset: _accountController.text.length,
                        ),
                      );
                    });
                  }
                  return _wrapLoginSubmitShortcut(
                    TextFormField(
                      key: const Key('login-account-field'),
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: '账号',
                        border: const OutlineInputBorder(),
                        helperText: _accounts.isEmpty
                            ? '可直接输入账号'
                            : '可输入或从下拉列表选择',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入账号';
                        }
                        if (value.trim().length < 2) {
                          return '账号至少 2 个字符';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        _accountController.text = value;
                      },
                      onFieldSubmitted: (_) => onFieldSubmitted(),
                    ),
                  );
                },
          ),
          const SizedBox(height: 12),
          _wrapLoginSubmitShortcut(
            TextFormField(
              key: const Key('login-password-field'),
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                if (value.length < 6) {
                  return '密码至少 6 个字符';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submitLogin(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _wrapLoginSubmitShortcut(
                  FilledButton(
                    key: const Key('login-submit-button'),
                    onPressed: _loading ? null : _submitLogin,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('登录'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const Key('go-register-button'),
                  onPressed: _loading ? null : _openRegisterPage,
                  child: const Text('去注册'),
                ),
              ),
            ],
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              key: const Key('login-message-text'),
              _message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _message.startsWith('注册申请已提交')
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZYKJ MES 登录',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请输入接口地址、账号与密码。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              if (fillHeight) Expanded(child: formContent) else formContent,
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeSection {
  const _NoticeSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;
}

class _NoticeTag extends StatelessWidget {
  const _NoticeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
