import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/quality_models.dart';
import '../services/api_exception.dart';
import '../services/quality_service.dart';

class FirstArticleDetailDialog extends StatefulWidget {
  const FirstArticleDetailDialog({
    super.key,
    required this.session,
    required this.recordId,
    required this.onLogout,
    this.canDispose = false,
    this.onDisposed,
  });

  final AppSession session;
  final int recordId;
  final VoidCallback onLogout;
  final bool canDispose;
  final VoidCallback? onDisposed;

  @override
  State<FirstArticleDetailDialog> createState() =>
      _FirstArticleDetailDialogState();
}

class _FirstArticleDetailDialogState extends State<FirstArticleDetailDialog> {
  late final QualityService _service;

  bool _loading = true;
  bool _submitting = false;
  String _message = '';
  FirstArticleDetail? _detail;

  final _opinionController = TextEditingController();
  String _recheckResult = 'pass';
  String _finalJudgment = 'accept';

  @override
  void initState() {
    super.initState();
    _service = QualityService(widget.session);
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
      final detail = await _service.getFirstArticleDetail(widget.recordId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        if (detail.disposition != null) {
          _opinionController.text = detail.disposition!.dispositionOpinion;
          _recheckResult =
              detail.disposition!.recheckResult.isNotEmpty
                  ? detail.disposition!.recheckResult
                  : 'pass';
          _finalJudgment =
              detail.disposition!.finalJudgment.isNotEmpty
                  ? detail.disposition!.finalJudgment
                  : 'accept';
        }
      });
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载详情失败：${error is ApiException ? error.message : error.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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
      if (!mounted) return;
      widget.onDisposed?.call();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '提交失败：${error is ApiException ? error.message : error.toString()}';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('首件详情 #${widget.recordId}'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : _detail == null
            ? Text(_message.isNotEmpty ? _message : '加载失败')
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _InfoRow('校验码', _detail!.verificationCode),
                    _InfoRow('订单号', _detail!.productionOrderCode),
                    _InfoRow(
                      '产品',
                      '${_detail!.productName} (${_detail!.productCode})',
                    ),
                    _InfoRow('工序', _detail!.processName),
                    _InfoRow('操作员', _detail!.operatorUsername),
                    _InfoRow(
                      '检验结果',
                      firstArticleResultLabel(_detail!.checkResult),
                    ),
                    _InfoRow('缺陷描述', _detail!.defectDescription.isEmpty ? '-' : _detail!.defectDescription),
                    _InfoRow('检验时间', _formatDateTime(_detail!.checkAt)),
                    const Divider(height: 24),
                    Text(
                      '首件处置',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_detail!.disposition != null) ...[
                      _InfoRow('处置人', _detail!.disposition!.dispositionUsername),
                      _InfoRow('处置时间', _formatDateTime(_detail!.disposition!.dispositionAt)),
                      _InfoRow('复检结果', _recheckResultLabel(_detail!.disposition!.recheckResult)),
                      _InfoRow('最终判定', _finalJudgmentLabel(_detail!.disposition!.finalJudgment)),
                      _InfoRow('处置意见', _detail!.disposition!.dispositionOpinion),
                      const Divider(height: 16),
                      Text('修改处置', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 8),
                    ],
                    if (widget.canDispose) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _recheckResult,
                        decoration: const InputDecoration(
                          labelText: '复检结果',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pass', child: Text('合格')),
                          DropdownMenuItem(value: 'fail', child: Text('不合格')),
                          DropdownMenuItem(value: 'conditional', child: Text('条件放行')),
                        ],
                        onChanged: (v) => setState(() => _recheckResult = v ?? 'pass'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _finalJudgment,
                        decoration: const InputDecoration(
                          labelText: '最终判定',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'accept', child: Text('接受')),
                          DropdownMenuItem(value: 'reject', child: Text('拒绝')),
                          DropdownMenuItem(value: 'rework', child: Text('返工')),
                          DropdownMenuItem(value: 'scrap', child: Text('报废')),
                        ],
                        onChanged: (v) => setState(() => _finalJudgment = v ?? 'accept'),
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
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        if (widget.canDispose && !_loading && _detail != null)
          FilledButton(
            onPressed: _submitting ? null : _submitDisposition,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('提交处置'),
          ),
      ],
    );
  }

  String _recheckResultLabel(String v) {
    switch (v) {
      case 'pass':
        return '合格';
      case 'fail':
        return '不合格';
      case 'conditional':
        return '条件放行';
      default:
        return v;
    }
  }

  String _finalJudgmentLabel(String v) {
    switch (v) {
      case 'accept':
        return '接受';
      case 'reject':
        return '拒绝';
      case 'rework':
        return '返工';
      case 'scrap':
        return '报废';
      default:
        return v;
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
