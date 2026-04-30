import 'package:flutter/material.dart';

Future<bool> showEquipmentRuleDeleteDialog({
  required BuildContext context,
  required String ruleName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定删除规则「$ruleName」？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
      ],
    ),
  );
  return confirmed == true;
}

Future<bool> showEquipmentRuntimeParameterDeleteDialog({
  required BuildContext context,
  required String paramName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定删除参数「$paramName」？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
      ],
    ),
  );
  return confirmed == true;
}
