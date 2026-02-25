import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/auth_service.dart';

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
  final _accountController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'Admin@123456');
  final _authService = AuthService();

  bool _loading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.defaultBaseUrl);
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
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  String _accountText() => _accountController.text.trim();

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
      widget.onLoginSuccess(
        AppSession(
          baseUrl: baseUrl,
          accessToken: token,
        ),
      );
    } catch (error) {
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

  Future<void> _submitRegister() async {
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
      await _authService.register(
        baseUrl: baseUrl,
        account: account,
        password: _passwordController.text,
      );
      setState(() {
        _message = '注册成功，请使用该账号登录';
      });
    } catch (error) {
      setState(() {
        _message = '注册失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: '接口地址',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入接口地址';
                        }
                        if (!value.startsWith('http://') && !value.startsWith('https://')) {
                          return '地址必须以 http:// 或 https:// 开头';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accountController,
                      decoration: const InputDecoration(
                        labelText: '账号（用户名与姓名统一）',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入账号';
                        }
                        if (value.trim().length < 3) {
                          return '账号至少 3 个字符';
                        }
                        return null;
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
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('登录'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _submitRegister,
                            child: const Text('注册'),
                          ),
                        ),
                      ],
                    ),
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _message.startsWith('注册成功')
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

