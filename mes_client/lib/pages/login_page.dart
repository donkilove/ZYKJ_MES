import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    this.defaultBaseUrl = 'http://127.0.0.1:8000/api/v1',
  });

  final ValueChanged<AppSession> onLoginSuccess;
  final String defaultBaseUrl;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _loading = false;
  bool _loadingAccounts = false;
  String _message = '';
  List<String> _accounts = const [];

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.defaultBaseUrl);
    _loadAccounts();
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
        _message = '加载账号列表失败：$error';
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
      final token = await _authService.login(
        baseUrl: baseUrl,
        username: account,
        password: _passwordController.text,
      );
      widget.onLoginSuccess(AppSession(baseUrl: baseUrl, accessToken: token));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '登录失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openRegisterPage() async {
    final result = await Navigator.of(context).push<RegisterPageResult>(
      MaterialPageRoute(
        builder: (_) => RegisterPage(
          initialBaseUrl: _normalizeBaseUrl(_baseUrlController.text),
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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(24),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ZYKJ MES 登录',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                                  ),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        final keyword = textEditingValue.text
                            .trim()
                            .toLowerCase();
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
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            if (textEditingController.text !=
                                _accountController.text) {
                              textEditingController.value = TextEditingValue(
                                text: _accountController.text,
                                selection: TextSelection.collapsed(
                                  offset: _accountController.text.length,
                                ),
                              );
                            }
                            return TextFormField(
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
                            );
                          },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
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
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _loading ? null : _submitLogin,
                            child: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('登录'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _openRegisterPage,
                            child: const Text('去注册'),
                          ),
                        ),
                      ],
                    ),
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
