import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

Future<FirstArticleTemplateItem?> showProductionFirstArticleTemplatePickerDialog({
  required BuildContext context,
  required List<FirstArticleTemplateItem> templates,
  int? selectedTemplateId,
}) {
  return showMesLockedFormDialog<FirstArticleTemplateItem?>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionFirstArticleTemplatePickerDialog(
        templates: templates,
        selectedTemplateId: selectedTemplateId,
      );
    },
  );
}

class ProductionFirstArticleTemplatePickerDialog extends StatelessWidget {
  const ProductionFirstArticleTemplatePickerDialog({
    super.key,
    required this.templates,
    this.selectedTemplateId,
  });

  final List<FirstArticleTemplateItem> templates;
  final int? selectedTemplateId;

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: const Text('选择首件模板'),
      width: 560,
      content: SizedBox(
        key: const ValueKey('production-first-article-template-dialog'),
        width: 560,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: templates.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = templates[index];
            final isSelected = item.id == selectedTemplateId;
            return ListTile(
              selected: isSelected,
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
              onTap: () => Navigator.of(context).pop(item),
              title: Text(item.templateName),
              subtitle: Text(
                '检验内容：${(item.checkContent ?? '').trim().isEmpty ? '-' : item.checkContent}\n'
                '测试值：${(item.testValue ?? '').trim().isEmpty ? '-' : item.testValue}',
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
