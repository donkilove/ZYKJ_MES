import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';

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
    this.isDispositionMode = false,
    this.service,
  });

  final AppSession session;
  final int recordId;
  final VoidCallback onLogout;
  final bool canDispose;
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
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle())),
      body: SafeArea(
        child: _loading
            ? const MesLoadingState(label: '首件处置加载中...')
            : _detail == null
            ? Center(child: Text(_message.isNotEmpty ? _message : '加载失败'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '首件基础信息',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                _InfoRow('校验码', _detail!.verificationCode),
                                _InfoRow('订单号', _detail!.productionOrderCode),
                                _InfoRow(
                                  '产品',
                                  '${_detail!.productName} (${_detail!.productCode})',
                                ),
                                _InfoRow('工序', _detail!.processName),
                                _InfoRow('操作员', _detail!.operatorUsername),
                                _InfoRow(
                                  '模板名称',
                                  _displayText(_detail!.templateName),
                                ),
                                _InfoRow(
                                  '首件内容',
                                  _displayText(_detail!.checkContent),
                                ),
                                _InfoRow(
                                  '首件测试值',
                                  _displayText(_detail!.testValue),
                                ),
                                _InfoRow(
                                  '参与操作员',
                                  _participantText(_detail!.participants),
                                ),
                                _InfoRow(
                                  '检验结果',
                                  firstArticleResultLabel(_detail!.checkResult),
                                ),
                                _InfoRow(
                                  '缺陷描述',
                                  _detail!.defectDescription.isEmpty
                                      ? '-'
                                      : _detail!.defectDescription,
                                ),
                                _InfoRow(
                                  '检验时间',
                                  _formatDateTime(_detail!.checkAt),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '首件处置',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
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
                                if (_message.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _message,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('返回'),
                            ),
                            const Spacer(),
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
