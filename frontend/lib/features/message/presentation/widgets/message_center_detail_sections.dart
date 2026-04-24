import 'package:flutter/material.dart';

class MessageCenterDetailField {
  const MessageCenterDetailField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class MessageCenterDetailSections extends StatelessWidget {
  const MessageCenterDetailSections({
    super.key,
    required this.fields,
  });

  final List<MessageCenterDetailField> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          _DetailFieldRow(field: fields[index]),
          if (index != fields.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DetailFieldRow extends StatelessWidget {
  const _DetailFieldRow({required this.field});

  final MessageCenterDetailField field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              field.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              field.value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
