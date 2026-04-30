import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';

class MaintenanceExecutionCompleteDialogResult {
  const MaintenanceExecutionCompleteDialogResult({
    required this.resultSummary,
    required this.resultRemark,
    required this.attachmentLink,
  });

  final String resultSummary;
  final String? resultRemark;
  final String? attachmentLink;
}

Future<MaintenanceExecutionCompleteDialogResult?>
showMaintenanceExecutionCompleteDialog({
  required BuildContext context,
  required MaintenanceWorkOrderItem workOrder,
}) {
  return showMesLockedFormDialog<MaintenanceExecutionCompleteDialogResult?>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return MaintenanceExecutionCompleteDialog(workOrder: workOrder);
    },
  );
}

class MaintenanceExecutionCompleteDialog extends StatefulWidget {
  const MaintenanceExecutionCompleteDialog({
    super.key,
    required this.workOrder,
  });

  final MaintenanceWorkOrderItem workOrder;

  @override
  State<MaintenanceExecutionCompleteDialog> createState() =>
      _MaintenanceExecutionCompleteDialogState();
}

class _MaintenanceExecutionCompleteDialogState
    extends State<MaintenanceExecutionCompleteDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _attachmentController = TextEditingController();
  String _selectedSummary = '完成';

  @override
  void dispose() {
    _remarkController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      MaintenanceExecutionCompleteDialogResult(
        resultSummary: _selectedSummary,
        resultRemark: _remarkController.text.trim().isEmpty
            ? null
            : _remarkController.text.trim(),
        attachmentLink: _attachmentController.text.trim().isEmpty
            ? null
            : _attachmentController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needExceptionReport = _selectedSummary == '失败';
    return MesDialog(
      title: const Text('完成保养执行'),
      width: 700,
      content: SizedBox(
        key: const ValueKey('maintenance-execution-complete-dialog'),
        width: 700,
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '执行结果',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSummary,
                      decoration: const InputDecoration(
                        labelText: '结果摘要',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: '完成',
                          child: Text('完成'),
                        ),
                        DropdownMenuItem<String>(
                          value: '失败',
                          child: Text('失败'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedSummary = value;
                          if (_selectedSummary != '失败') {
                            _remarkController.clear();
                          }
                        });
                      },
                    ),
                    if (needExceptionReport) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarkController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '异常上报',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_selectedSummary == '失败' &&
                              (value == null || value.trim().isEmpty)) {
                            return '结果摘要为失败时必须填写异常上报';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '附件与说明',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _attachmentController,
                        decoration: const InputDecoration(
                          labelText: '附件地址（可选，支持下载链接或 UNC 路径）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('提交'),
        ),
      ],
    );
  }
}
