import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/services/production_service.dart';

class FirstArticleScanReviewMobileApp extends StatelessWidget {
  const FirstArticleScanReviewMobileApp({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  final String baseUrl;
  final String token;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '首件复核',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: FirstArticleScanReviewMobilePage(baseUrl: baseUrl, token: token),
    );
  }
}

class FirstArticleScanReviewMobilePage extends StatefulWidget {
  const FirstArticleScanReviewMobilePage({
    super.key,
    required this.baseUrl,
    required this.token,
    this.authService,
    this.productionServiceFactory,
  });

  final String baseUrl;
  final String token;
  final AuthService? authService;
  final ProductionService Function(AppSession session)?
  productionServiceFactory;

  @override
  State<FirstArticleScanReviewMobilePage> createState() =>
      _FirstArticleScanReviewMobilePageState();
}

class _FirstArticleScanReviewMobilePageState
    extends State<FirstArticleScanReviewMobilePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  late final AuthService _authService;
  ProductionService? _productionService;
  FirstArticleReviewSessionDetail? _detail;
  String _reviewResult = 'passed';
  String _message = '';
  bool _loading = false;
  bool _loggedIn = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    if (widget.token.trim().isEmpty) {
      _message = '扫码链接缺少复核令牌';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _loginAndLoadDetail() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _message = '请输入账号和密码';
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final loginResult = await _authService.login(
        baseUrl: widget.baseUrl,
        username: username,
        password: password,
      );
      if (loginResult.mustChangePassword) {
        if (!mounted) {
          return;
        }
        setState(() {
          _message = '请先在主系统修改密码后再复核';
        });
        return;
      }
      final session = AppSession(
        baseUrl: widget.baseUrl,
        accessToken: loginResult.token,
      );
      final service =
          widget.productionServiceFactory?.call(session) ??
          ProductionService(session);
      final detail = await service.getFirstArticleReviewSessionDetail(
        token: widget.token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _productionService = service;
        _detail = detail;
        _loggedIn = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _submitReview() async {
    final service = _productionService;
    if (service == null || _submitted) {
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final remark = _remarkController.text.trim();
      await service.submitFirstArticleReviewResult(
        request: FirstArticleReviewSubmitInput(
          token: widget.token,
          reviewResult: _reviewResult,
          reviewRemark: remark.isEmpty ? null : remark,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitted = true;
        _message = '复核已提交';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildMessage(BuildContext context) {
    if (_message.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = _submitted
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(_message, style: TextStyle(color: color)),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('首件扫码复核', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '账号',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          onSubmitted: (_) => _loading ? null : _loginAndLoadDetail(),
          decoration: const InputDecoration(
            labelText: '密码',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _loginAndLoadDetail,
          child: Text(_loading ? '登录中...' : '登录'),
        ),
      ],
    );
  }

  Widget _buildDetail() {
    final detail = _detail;
    if (detail == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('首件扫码复核', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _InfoRow(label: '订单', value: detail.orderCode),
        _InfoRow(label: '产品', value: detail.productName),
        _InfoRow(label: '工序', value: detail.processName),
        _InfoRow(label: '操作员', value: detail.operatorUsername),
        _InfoRow(label: '检验内容', value: detail.checkContent),
        _InfoRow(label: '检验值', value: detail.testValue),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(value: 'passed', label: Text('合格')),
            ButtonSegment<String>(value: 'failed', label: Text('不合格')),
          ],
          selected: {_reviewResult},
          onSelectionChanged: _submitted || _loading
              ? null
              : (selection) {
                  setState(() {
                    _reviewResult = selection.first;
                  });
                },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remarkController,
          enabled: !_submitted && !_loading,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '备注（可选）',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading || _submitted ? null : _submitReview,
          child: Text(_loading ? '提交中...' : '提交复核'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMessage(context),
                  if (_loggedIn) _buildDetail() else _buildLoginForm(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value),
        ],
      ),
    );
  }
}
