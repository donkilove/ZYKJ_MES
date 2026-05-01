import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';

Future<({String token, int expiresIn})?> showTokenRenewalDialog({
  required BuildContext context,
  required String baseUrl,
  required String accessToken,
  required AuthService authService,
}) {
  return showDialog<({String token, int expiresIn})?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TokenRenewalDialog(
      baseUrl: baseUrl,
      accessToken: accessToken,
      authService: authService,
    ),
  );
}

class TokenRenewalDialog extends StatefulWidget {
  const TokenRenewalDialog({
    super.key,
    required this.baseUrl,
    required this.accessToken,
    required this.authService,
  });

  final String baseUrl;
  final String accessToken;
  final AuthService authService;

  @override
  State<TokenRenewalDialog> createState() => _TokenRenewalDialogState();
}

class _TokenRenewalDialogState extends State<TokenRenewalDialog> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String _error = '';
  int _remainingSeconds = 180;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        Navigator.of(context).pop(null);
      }
    });
  }

  Future<void> _submitRenewal() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await widget.authService.renewToken(
        baseUrl: widget.baseUrl,
        accessToken: widget.accessToken,
        password: _passwordController.text,
      );
      if (mounted) {
        _timer?.cancel();
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (!mounted) return;
      String message;
      if (error is ApiException && error.statusCode == 401) {
        message = '密码错误，请重新输入';
      } else if (error is ApiException) {
        message = error.message;
      } else {
        message = '续期失败，请稍后重试';
      }
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return AlertDialog(
      icon: Icon(
        Icons.timer_outlined,
        color: theme.colorScheme.error,
        size: 40,
      ),
      title: const Text('会话即将过期'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '您的登录会话即将过期，请输入密码续期。剩余时间：$timeStr',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入密码';
                return null;
              },
              onFieldSubmitted: (_) => _submitRenewal(),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  _timer?.cancel();
                  Navigator.of(context).pop(null);
                },
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submitRenewal,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('续期'),
        ),
      ],
    );
  }
}
