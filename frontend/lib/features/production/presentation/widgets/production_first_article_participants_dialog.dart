import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

Future<Set<int>?> showProductionFirstArticleParticipantsDialog({
  required BuildContext context,
  required List<FirstArticleParticipantOptionItem> participantOptions,
  required Set<int> selectedIds,
}) {
  return showMesLockedFormDialog<Set<int>?>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionFirstArticleParticipantsDialog(
        participantOptions: participantOptions,
        selectedIds: selectedIds,
      );
    },
  );
}

class ProductionFirstArticleParticipantsDialog extends StatefulWidget {
  const ProductionFirstArticleParticipantsDialog({
    super.key,
    required this.participantOptions,
    required this.selectedIds,
  });

  final List<FirstArticleParticipantOptionItem> participantOptions;
  final Set<int> selectedIds;

  @override
  State<ProductionFirstArticleParticipantsDialog> createState() =>
      _ProductionFirstArticleParticipantsDialogState();
}

class _ProductionFirstArticleParticipantsDialogState
    extends State<ProductionFirstArticleParticipantsDialog> {
  late final Set<int> _draftIds = {...widget.selectedIds};

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: const Text('添加参与操作员'),
      width: 560,
      content: SizedBox(
        key: const ValueKey('production-first-article-participants-dialog'),
        width: 560,
        child: ListView(
          shrinkWrap: true,
          children: widget.participantOptions.map((item) {
            return CheckboxListTile(
              value: _draftIds.contains(item.id),
              title: Text(item.displayName),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _draftIds.add(item.id);
                  } else {
                    _draftIds.remove(item.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_draftIds),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
