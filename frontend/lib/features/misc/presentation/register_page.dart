import 'package:flutter/material.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';

class RegisterPageResult {
  const RegisterPageResult({required this.baseUrl, required this.account});

  final String baseUrl;
  final String account;
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.initialBaseUrl,
    this.authService,
  });

  final String initialBaseUrl;
  final AuthService? authService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const int _accountMaxLength = 10;
  final _formKey = GlobalKey<FormState>();
  late final AuthService _authService;

  late final TextEditingController _baseUrlController;
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _submitting = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.initialBaseUrl);
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  bool _containsChinese(String value) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(value);
  }

  String _extractErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message.trim();
    }
    return error.toString().trim();
  }

  String _mapRegisterError(Object error) {
    final raw = _extractErrorMessage(error);
    final normalized = raw.toLowerCase();
    if (normalized.contains('username already exists') ||
        raw.contains('账号已存在')) {
      return '账号已存在，请更换账号后重试。';
    }
    if (normalized.contains('pending approval') || raw.contains('待审批')) {
      return '该账号已有待审批注册申请，请等待审批结果。';
    }
    if (normalized.contains('rejected') || raw.contains('已驳回')) {
      return '该账号的注册申请已被驳回，请确认信息后重新提交。';
    }
    if (normalized.contains('account is required')) {
      return '请输入账号后再提交。';
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
    return '提交注册申请失败，请稍后重试。';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
    final account = _accountController.text.trim();

    setState(() {
      _submitting = true;
      _message = '';
    });

    try {
      await _authService.register(
        baseUrl: baseUrl,
        account: account,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(RegisterPageResult(baseUrl: baseUrl, account: account));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _mapRegisterError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('注册申请')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '创建账号申请',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('register-base-url-field'),
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
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('register-account-field'),
                        controller: _accountController,
                        decoration: const InputDecoration(
                          labelText: '账号',
                          helperText: '账号长度 2-10 个字符。',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final account = value?.trim() ?? '';
                          if (account.isEmpty) {
                            return '请输入账号';
                          }
                          if (account.length < 2) {
                            return '账号至少 2 个字符';
                          }
                          if (account.length > _accountMaxLength) {
                            return '账号最多 $_accountMaxLength 个字符';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('register-password-field'),
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          helperText: '密码规则：至少6位；不能包含连续4位相同字符。',
                          helperMaxLines: 2,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty) {
                            return '请输入密码';
                          }
                          if (password.length < 6) {
                            return '密码至少 6 个字符';
                          }
                          if (RegExp(r'(.)\1\1\1').hasMatch(password)) {
                            return '密码不能包含连续4位相同字符';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('register-confirm-password-field'),
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '确认密码',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请再次输入密码';
                          }
                          if (value != _passwordController.text) {
                            return '两次输入的密码不一致';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              key: const Key('register-submit-button'),
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('提交注册申请'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '注册后需要系统管理员审批通过，账号才可登录。',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (_message.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
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
      ),
    );
  }
}
