import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_detail_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';

class FirstArticleDispositionPage extends StatefulWidget {
  const FirstArticleDispositionPage({
    super.key,
    required this.session,
    required this.recordId,
    required this.onLogout,
    this.canDispose = false,
    this.canCancel = false,
    this.canDelete = false,
    this.isDispositionMode = false,
    this.service,
  });

  final AppSession session;
  final int recordId;
  final VoidCallback onLogout;
  final bool canDispose;
  final bool canCancel;
  final bool canDelete;
  final bool isDispositionMode;
  final QualityService? service;

  @override
  State<FirstArticleDispositionPage> createState() =>
      _FirstArticleDispositionPageState();
}

class _FirstArticleDispositionPageState
    extends State<FirstArticleDispositionPage> {
  late final QualityService _service;

  bool _loading = true;
  bool _submitting = false;
  String _message = '';
  FirstArticleDetail? _detail;

  final _opinionController = TextEditingController();
  String _recheckResult = 'passed';
  String _finalJudgment = 'accept';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? QualityService(widget.session);
    _loadDetail();
  }

  @override
  void dispose() {
    _opinionController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final detail = widget.isDispositionMode
          ? await _service.getFirstArticleDispositionDetail(widget.recordId)
          : await _service.getFirstArticleDetail(widget.recordId);
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        if (detail.disposition != null) {
          _opinionController.text = detail.disposition!.dispositionOpinion;
          _recheckResult = detail.disposition!.recheckResult.isNotEmpty
              ? detail.disposition!.recheckResult
              : 'passed';
          _finalJudgment = detail.disposition!.finalJudgment.isNotEmpty
              ? detail.disposition!.finalJudgment
              : 'accept';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message =
            '加载详情失败：${error is ApiException ? error.message : error.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitDisposition() async {
    final opinion = _opinionController.text.trim();
    if (opinion.isEmpty) {
      setState(() => _message = '请填写处置意见');
      return;
    }
    setState(() {
      _submitting = true;
      _message = '';
    });
    try {
      await _service.submitDisposition(
        recordId: widget.recordId,
        dispositionOpinion: opinion,
        recheckResult: _recheckResult,
        finalJudgment: _finalJudgment,
        operator_: '',
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message =
            '提交失败：${error is ApiException ? error.message : error.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleCancelFirstArticle() async {
    await _submitPasswordAction(
      action: 'cancel',
      title: '取消首件',
      riskDescription:
          '该操作会将当前首件标记为已取消，并将对应操作员退回待生产状态。仅在首件通过后未产生真实报工时允许取消。',
      submitLabel: '确认取消',
      onSubmit: (password) =>
          _service.cancelFirstArticle(recordId: widget.recordId, password: password),
    );
  }

  Future<void> _handleDeleteFirstArticle() async {
    await _submitPasswordAction(
      action: 'delete',
      title: '删除首件',
      riskDescription:
          '该操作会删除当前首件及其关联业务记录，删除后不可恢复。若该条有效首件后已存在真实报工，系统会拒绝删除。',
      submitLabel: '确认删除',
      onSubmit: (password) =>
          _service.deleteFirstArticle(recordId: widget.recordId, password: password),
    );
  }

  Future<void> _submitPasswordAction({
    required String action,
    required String title,
    required String riskDescription,
    required String submitLabel,
    required Future<void> Function(String password) onSubmit,
  }) async {
    final password = await _showPasswordActionDialog(
      title: title,
      riskDescription: riskDescription,
      submitLabel: submitLabel,
      isDanger: action == 'delete',
    );
    if (!mounted || password == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _message = '';
    });
    try {
      await onSubmit(password);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message =
            '$title失败：${error is ApiException ? error.message : error.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<String?> _showPasswordActionDialog({
    required String title,
    required String riskDescription,
    required String submitLabel,
    required bool isDanger,
  }) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showMesLockedFormDialog<String?>(
      context: context,
      wrapMesDialog: false,
      builder: (dialogContext) {
        return MesDialog(
          title: Text(title),
          width: 520,
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riskDescription,
                  style: TextStyle(
                    color: isDanger
                        ? Theme.of(dialogContext).colorScheme.error
                        : Theme.of(dialogContext).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: ValueKey('first-article-$title-password-field'),
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '当前登录密码',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入当前登录密码';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('取消'),
            ),
            FilledButton(
              style: isDanger
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(dialogContext).colorScheme.error,
                      foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                    )
                  : null,
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(dialogContext).pop(passwordController.text);
              },
              child: Text(submitLabel),
            ),
          ],
        );
      },
    ).whenComplete(passwordController.dispose);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  String _pageTitle() {
    return '${widget.isDispositionMode ? '首件处置' : '首件详情'} #${widget.recordId}';
  }

  String _displayText(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return '-';
    }
    return normalized;
  }

  String _participantText(List<FirstArticleParticipantItem> participants) {
    final labels = participants
        .map((item) => item.displayName.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (labels.isEmpty) {
      return '-';
    }
    return labels.join('、');
  }

  @override
  Widget build(BuildContext context) {
    final canSubmitDisposition =
        widget.canDispose &&
        (_detail?.checkResult == 'failed' || _detail?.checkResult == 'fail');
    final detail = _detail;
    final canShowCancelButton =
        !widget.isDispositionMode &&
        widget.canCancel &&
        (detail?.canCancel ?? false);
    final canShowDeleteButton =
        !widget.isDispositionMode &&
        widget.canDelete &&
        (detail?.canDelete ?? false);
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const MesLoadingState(label: '首件处置加载中...')
            : detail == null
            ? MesErrorState(
                message: _message.isNotEmpty ? _message : '加载失败',
                onRetry: _loadDetail,
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KeyedSubtree(
                          key: const ValueKey(
                            'first-article-disposition-page-header',
                          ),
                          child: MesDetailPageHeader(title: _pageTitle()),
                        ),
                        const SizedBox(height: 16),
                        if (detail.recordStatus == 'cancelled') ...[
                          MesInlineBanner.warning(
                            message:
                                '该条首件已取消。取消人：${_displayText(detail.cancelledByUsername)}，取消时间：${_formatDateTime(detail.cancelledAt)}',
                          ),
                          const SizedBox(height: 16),
                        ],
                        MesSectionCard(
                          title: '首件基础信息',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow('校验码', detail.verificationCode),
                              _InfoRow('记录状态', firstArticleRecordStatusLabel(detail.recordStatus)),
                              _InfoRow('订单号', detail.productionOrderCode),
                              _InfoRow(
                                '产品',
                                '${detail.productName} (${detail.productCode})',
                              ),
                              _InfoRow('工序', detail.processName),
                              _InfoRow('操作员', detail.operatorUsername),
                              _InfoRow(
                                '模板名称',
                                _displayText(detail.templateName),
                              ),
                              _InfoRow(
                                '首件内容',
                                _displayText(detail.checkContent),
                              ),
                              _InfoRow(
                                '首件测试值',
                                _displayText(detail.testValue),
                              ),
                              _InfoRow(
                                '参与操作员',
                                _participantText(detail.participants),
                              ),
                              _InfoRow(
                                '检验结果',
                                firstArticleResultLabel(detail.checkResult),
                              ),
                              _InfoRow(
                                '缺陷描述',
                                detail.defectDescription.isEmpty
                                    ? '-'
                                    : detail.defectDescription,
                              ),
                              _InfoRow(
                                '检验时间',
                                _formatDateTime(detail.checkAt),
                              ),
                              if (detail.recordStatus == 'cancelled') ...[
                                _InfoRow(
                                  '取消人',
                                  _displayText(detail.cancelledByUsername),
                                ),
                                _InfoRow(
                                  '取消时间',
                                  _formatDateTime(detail.cancelledAt),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        MesSectionCard(
                          title: '首件处置',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_detail!.disposition != null) ...[
                                _InfoRow(
                                  '处置人',
                                  _detail!.disposition!.dispositionUsername,
                                ),
                                _InfoRow(
                                  '处置时间',
                                  _formatDateTime(
                                    _detail!.disposition!.dispositionAt,
                                  ),
                                ),
                                _InfoRow(
                                  '复检结果',
                                  _recheckResultLabel(
                                    _detail!.disposition!.recheckResult,
                                  ),
                                ),
                                _InfoRow(
                                  '最终判定',
                                  _finalJudgmentLabel(
                                    _detail!.disposition!.finalJudgment,
                                  ),
                                ),
                                _InfoRow(
                                  '处置意见',
                                  _detail!.disposition!.dispositionOpinion,
                                ),
                                const Divider(height: 24),
                              ] else
                                const Text('暂无处置记录'),
                              if (_detail!.dispositionHistory.isNotEmpty) ...[
                                Text(
                                  '处置历史',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                ..._detail!.dispositionHistory.map(
                                  (history) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('版本 ${history.version}'),
                                          const SizedBox(height: 4),
                                          Text(
                                            '处置人：${history.dispositionUsername}',
                                          ),
                                          Text(
                                            '处置时间：${_formatDateTime(history.dispositionAt)}',
                                          ),
                                          Text(
                                            '复检结果：${_recheckResultLabel(history.recheckResult)}',
                                          ),
                                          Text(
                                            '最终判定：${_finalJudgmentLabel(history.finalJudgment)}',
                                          ),
                                          Text(
                                            '处置意见：${history.dispositionOpinion}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (canSubmitDisposition) ...[
                                if (_detail!.dispositionHistory.isNotEmpty ||
                                    _detail!.disposition != null)
                                  const Divider(height: 24),
                                Text(
                                  widget.isDispositionMode ? '提交处置' : '修改处置',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _recheckResult,
                                  decoration: const InputDecoration(
                                    labelText: '复检结果',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'pass',
                                      child: Text('合格'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'passed',
                                      child: Text('合格'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'fail',
                                      child: Text('不合格'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'failed',
                                      child: Text('不合格'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'conditional',
                                      child: Text('条件放行'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                    () => _recheckResult = v ?? 'passed',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _finalJudgment,
                                  decoration: const InputDecoration(
                                    labelText: '最终判定',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'accept',
                                      child: Text('接受'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'reject',
                                      child: Text('拒绝'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'rework',
                                      child: Text('返工'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'scrap',
                                      child: Text('报废'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                    () => _finalJudgment = v ?? 'accept',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _opinionController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: '处置意见',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_message.isNotEmpty) ...[
                          MesInlineBanner.error(message: _message),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('返回'),
                            ),
                            const Spacer(),
                            if (canShowCancelButton)
                              OutlinedButton(
                                key: const ValueKey('first-article-cancel-button'),
                                onPressed: _submitting
                                    ? null
                                    : _handleCancelFirstArticle,
                                child: const Text('取消首件'),
                              ),
                            if (canShowCancelButton && canShowDeleteButton)
                              const SizedBox(width: 12),
                            if (canShowDeleteButton)
                              FilledButton(
                                key: const ValueKey('first-article-delete-button'),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.error,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onError,
                                ),
                                onPressed: _submitting
                                    ? null
                                    : _handleDeleteFirstArticle,
                                child: const Text('删除首件'),
                              ),
                            if ((canShowCancelButton || canShowDeleteButton) &&
                                canSubmitDisposition)
                              const SizedBox(width: 12),
                            if (canSubmitDisposition)
                              FilledButton(
                                onPressed: _submitting
                                    ? null
                                    : _submitDisposition,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        widget.isDispositionMode
                                            ? '提交处置'
                                            : '保存处置',
                                      ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  String _recheckResultLabel(String value) {
    switch (value) {
      case 'passed':
      case 'pass':
        return '合格';
      case 'failed':
      case 'fail':
        return '不合格';
      case 'conditional':
        return '条件放行';
      default:
        return value;
    }
  }

  String _finalJudgmentLabel(String value) {
    switch (value) {
      case 'accept':
        return '接受';
      case 'reject':
        return '拒绝';
      case 'rework':
        return '返工';
      case 'scrap':
        return '报废';
      default:
        return value;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label：',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
