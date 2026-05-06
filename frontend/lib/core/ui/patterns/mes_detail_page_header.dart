import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class MesDetailPageHeader extends StatelessWidget {
  const MesDetailPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: title,
      subtitle: subtitle,
      actionsBeforeTitle: [
        TextButton.icon(
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('返回'),
        ),
      ],
      actions: actions,
    );
  }
}
