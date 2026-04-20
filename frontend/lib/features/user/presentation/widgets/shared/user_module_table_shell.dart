import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/patterns/mes_table_section_header.dart';

class UserModuleTableShell extends StatelessWidget {
  const UserModuleTableShell({
    super.key,
    required this.title,
    required this.child,
    this.sectionKey,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Key? sectionKey;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing =
        Theme.of(context).extension<MesTokens>()?.spacing.md ?? 16.0;
    return KeyedSubtree(
      key: sectionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MesTableSectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
          ),
          SizedBox(height: spacing),
          Expanded(child: child),
        ],
      ),
    );
  }
}
